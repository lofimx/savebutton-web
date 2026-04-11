# == Schema Information
#
# Table name: device_tokens
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  app_version          :string
#  device_name          :string           not null
#  device_type          :string           not null
#  expires_at           :datetime         not null
#  last_used_at         :datetime
#  refresh_token_digest :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :uuid             not null
#
# Indexes
#
#  index_device_tokens_on_refresh_token_digest  (refresh_token_digest) UNIQUE
#  index_device_tokens_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class DeviceTokenTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "valid device token" do
    dt = build(:device_token, user: @user)
    assert dt.valid?
  end

  test "requires device_name" do
    dt = build(:device_token, user: @user, device_name: nil)
    assert_not dt.valid?
    assert_includes dt.errors[:device_name], "can't be blank"
  end

  test "requires device_type" do
    dt = build(:device_token, user: @user, device_type: nil)
    assert_not dt.valid?
  end

  test "validates device_type inclusion" do
    dt = build(:device_token, user: @user, device_type: "invalid_type")
    assert_not dt.valid?
    assert_includes dt.errors[:device_type], "is not included in the list"
  end

  test "requires refresh_token_digest" do
    dt = build(:device_token, user: @user, refresh_token_digest: nil)
    assert_not dt.valid?
  end

  test "requires expires_at" do
    dt = build(:device_token, user: @user, expires_at: nil)
    assert_not dt.valid?
  end

  test "generate_refresh_token! sets digest and returns plaintext" do
    dt = @user.device_tokens.build(
      device_name: "Test",
      device_type: "mobile_android"
    )
    token = dt.generate_refresh_token!

    assert token.present?
    assert dt.refresh_token_digest.present?
    assert dt.expires_at.present?
    assert dt.expires_at > Time.current
  end

  test "refresh_token_matches? returns true for correct token" do
    dt = @user.device_tokens.build(
      device_name: "Test",
      device_type: "mobile_android"
    )
    token = dt.generate_refresh_token!
    dt.save!

    assert dt.refresh_token_matches?(token)
  end

  test "refresh_token_matches? returns false for wrong token" do
    dt = create(:device_token, user: @user)
    assert_not dt.refresh_token_matches?("wrong_token")
  end

  test "touch_usage! updates last_used_at and extends expires_at" do
    dt = create(:device_token, user: @user, expires_at: 30.days.from_now)
    old_expires = dt.expires_at

    dt.touch_usage!
    dt.reload

    assert dt.last_used_at.present?
    assert dt.expires_at > old_expires
  end

  test "expired? returns true when expires_at is in the past" do
    dt = build(:device_token, user: @user, expires_at: 1.day.ago)
    assert dt.expired?
  end

  test "expired? returns false when expires_at is in the future" do
    dt = build(:device_token, user: @user, expires_at: 1.day.from_now)
    assert_not dt.expired?
  end

  test "active scope returns non-expired tokens" do
    active = create(:device_token, user: @user, expires_at: 30.days.from_now)
    expired = create(:device_token, user: @user, expires_at: 1.day.ago)

    assert_includes DeviceToken.active, active
    assert_not_includes DeviceToken.active, expired
  end

  test "expired scope returns expired tokens" do
    active = create(:device_token, user: @user, expires_at: 30.days.from_now)
    expired = create(:device_token, user: @user, expires_at: 1.day.ago)

    assert_includes DeviceToken.expired, expired
    assert_not_includes DeviceToken.expired, active
  end

  test "destroyed when user is destroyed" do
    dt = create(:device_token, user: @user)
    @user.destroy
    assert_nil DeviceToken.find_by(id: dt.id)
  end
end
