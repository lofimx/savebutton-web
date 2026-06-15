require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = create(:user, :staff)
    sign_in_as(@staff)
    @target = create(:user)
  end

  test "toggle_friend grants friend tier to a free user" do
    patch toggle_friend_admin_user_path(@target)
    assert_redirected_to admin_user_path(@target)
    assert_equal "friend", @target.subscription.reload.tier
  end

  test "toggle_friend removes friend tier (back to free)" do
    @target.subscription.update!(tier: :friend)
    patch toggle_friend_admin_user_path(@target)
    assert_equal "free", @target.subscription.reload.tier
  end

  test "toggle_friend rejects when user has Stripe subscription" do
    @target.subscription.update!(tier: :basic, stripe_customer_id: "cus_123", stripe_subscription_id: "sub_123", stripe_status: "active")
    patch toggle_friend_admin_user_path(@target)
    assert_redirected_to admin_user_path(@target)
    assert_equal "basic", @target.subscription.reload.tier
  end

  test "restrict sets restricted_at" do
    patch restrict_admin_user_path(@target)
    assert @target.reload.restricted?
  end

  test "unrestrict clears restricted_at" do
    @target.update!(restricted_at: Time.current)
    patch unrestrict_admin_user_path(@target)
    refute @target.reload.restricted?
  end

  test "recalculate_usage runs without error" do
    @target.subscription.update!(tier: :basic, bytes_used: 99999)
    patch recalculate_usage_admin_user_path(@target)
    assert_equal 0, @target.subscription.reload.bytes_used
  end

  test "destroy hard-deletes the user" do
    target_id = @target.id
    delete admin_user_path(@target)
    assert_nil User.find_by(id: target_id)
  end

  test "sync_to_stripe is rejected when no stripe customer" do
    patch sync_to_stripe_admin_user_path(@target)
    assert_redirected_to admin_user_path(@target)
  end
end
