require "test_helper"
require "ostruct"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @secret = "whsec_test_secret_for_signing"
    Rails.application.credentials.merge!(stripe: {
      secret_key: "sk_test_xxx",
      webhook_signing_secret: @secret,
      basic_price_id: "price_basic_test",
      advanced_price_id: "price_advanced_test"
    })
  end

  test "rejects bad signature" do
    payload = checkout_completed_payload(@user, "price_basic_test")
    post stripe_webhook_path, params: payload, headers: {
      "Stripe-Signature" => "t=#{Time.current.to_i},v1=garbage",
      "CONTENT_TYPE" => "application/json"
    }
    assert_response :bad_request
  end

  test "checkout.session.completed upgrades subscription tier" do
    payload = checkout_completed_payload(@user, "price_basic_test")
    Stripe::Subscription.stub(:retrieve, fake_stripe_subscription) do
      post_signed_event(payload)
    end

    @user.subscription.reload
    assert_equal "cus_test_xyz", @user.subscription.stripe_customer_id
    assert_equal "basic", @user.subscription.tier
    assert_equal "active", @user.subscription.stripe_status
  end

  test "duplicate event id is processed only once" do
    payload = checkout_completed_payload(@user, "price_basic_test")
    Stripe::Subscription.stub(:retrieve, fake_stripe_subscription) do
      2.times { post_signed_event(payload) }
    end

    assert_equal 1, ProcessedStripeEvent.where(event_id: "evt_test_dedupe").count
  end

  test "invoice.payment_failed enters grace period" do
    @user.subscription.update!(tier: :basic, stripe_customer_id: "cus_test_xyz", stripe_subscription_id: "sub_test_abc", stripe_status: "active")

    payload = invoice_payment_failed_payload(@user.subscription.stripe_customer_id)
    post_signed_event(payload)

    @user.subscription.reload
    assert_equal "past_due", @user.subscription.stripe_status
    assert @user.subscription.in_grace_period?
  end

  test "customer.subscription.deleted moves to free with grace if data exists" do
    @user.subscription.update!(tier: :basic, bytes_used: 1.gigabyte, stripe_customer_id: "cus_test_xyz", stripe_subscription_id: "sub_test_abc", stripe_status: "active")

    payload = subscription_deleted_payload(@user.subscription.stripe_customer_id)
    post_signed_event(payload)

    @user.subscription.reload
    assert_equal "free", @user.subscription.tier
    assert @user.subscription.in_grace_period?
  end

  private

  def post_signed_event(payload)
    body = payload.to_json
    timestamp = Time.current.to_i
    signed = "#{timestamp}.#{body}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", @secret, signed)

    post stripe_webhook_path, params: body, headers: {
      "Stripe-Signature" => "t=#{timestamp},v1=#{signature}",
      "CONTENT_TYPE" => "application/json"
    }
  end

  def fake_stripe_subscription
    OpenStruct.new(
      id: "sub_test_abc",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: "price_basic_test")) ])
    )
  end

  def checkout_completed_payload(user, price_id)
    {
      id: "evt_test_dedupe",
      object: "event",
      type: "checkout.session.completed",
      data: {
        object: {
          id: "cs_test_123",
          object: "checkout.session",
          customer: "cus_test_xyz",
          subscription: "sub_test_abc",
          client_reference_id: user.id
        }
      }
    }
  end

  def invoice_payment_failed_payload(customer_id)
    {
      id: "evt_test_invoice_failed_#{SecureRandom.hex(4)}",
      object: "event",
      type: "invoice.payment_failed",
      data: {
        object: {
          id: "in_test_123",
          object: "invoice",
          customer: customer_id
        }
      }
    }
  end

  def subscription_deleted_payload(customer_id)
    {
      id: "evt_test_sub_deleted_#{SecureRandom.hex(4)}",
      object: "event",
      type: "customer.subscription.deleted",
      data: {
        object: {
          id: "sub_test_abc",
          object: "subscription",
          customer: customer_id,
          status: "canceled",
          current_period_end: 1.day.from_now.to_i
        }
      }
    }
  end
end
