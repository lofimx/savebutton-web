class StripeCheckoutSessionCreator
  TIERS = %w[basic advanced].freeze

  def initialize(user, tier, success_url:, cancel_url:)
    @user = user
    @tier = tier.to_s
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def call
    raise ArgumentError, "Unknown tier #{@tier}" unless TIERS.include?(@tier)
    price_id = price_id_for(@tier)
    raise Error, "Stripe price_id missing for tier=#{@tier}" if price_id.blank?

    subscription = @user.subscription
    customer_id = ensure_stripe_customer(subscription)

    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer_id,
      client_reference_id: @user.id,
      line_items: [ { price: price_id, quantity: 1 } ],
      success_url: @success_url,
      cancel_url: @cancel_url
    )
    Rails.logger.info "🔵 INFO: Stripe checkout session #{session.id} created for user #{@user.id} (tier=#{@tier})"
    session
  end

  class Error < StandardError; end

  private

  def price_id_for(tier)
    creds = Rails.application.credentials.stripe || {}
    case tier
    when "basic" then creds[:basic_price_id]
    when "advanced" then creds[:advanced_price_id]
    end
  end

  def ensure_stripe_customer(subscription)
    return subscription.stripe_customer_id if subscription.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: @user.email_address,
      metadata: { user_id: @user.id }
    )
    subscription.update!(stripe_customer_id: customer.id)
    customer.id
  end
end
