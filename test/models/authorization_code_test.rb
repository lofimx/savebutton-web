# == Schema Information
#
# Table name: authorization_codes
# Database name: primary
#
#  id                :uuid             not null, primary key
#  code              :string           not null
#  code_challenge    :string           not null
#  device_name       :string
#  device_type       :string
#  expires_at        :datetime         not null
#  identity_email    :string
#  identity_provider :string
#  redirect_uri      :string           not null
#  used              :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :uuid             not null
#
# Indexes
#
#  index_authorization_codes_on_code     (code) UNIQUE
#  index_authorization_codes_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class AuthorizationCodeTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "generate_for creates a valid authorization code" do
    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test_challenge",
      redirect_uri: "savebutton://auth/callback"
    )

    assert code.persisted?
    assert code.code.present?
    assert_equal @user, code.user
    assert_equal "test_challenge", code.code_challenge
    assert_equal "savebutton://auth/callback", code.redirect_uri
    assert code.expires_at > Time.current
    assert_not code.used?
  end

  test "verify_pkce returns true for matching verifier" do
    verifier = SecureRandom.urlsafe_base64(32)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: challenge,
      redirect_uri: "savebutton://auth/callback"
    )

    assert code.verify_pkce(verifier)
  end

  test "verify_pkce returns false for wrong verifier" do
    verifier = SecureRandom.urlsafe_base64(32)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: challenge,
      redirect_uri: "savebutton://auth/callback"
    )

    assert_not code.verify_pkce("wrong_verifier")
  end

  test "redeem! marks code as used" do
    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test",
      redirect_uri: "savebutton://auth/callback"
    )

    assert code.redeem!
    assert code.used?
  end

  test "redeem! fails for already used code" do
    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test",
      redirect_uri: "savebutton://auth/callback"
    )

    assert code.redeem!
    assert_not code.redeem!
  end

  test "redeem! fails for expired code" do
    code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test",
      redirect_uri: "savebutton://auth/callback"
    )
    code.update!(expires_at: 1.minute.ago)

    assert_not code.redeem!
  end

  test "expired scope" do
    fresh = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test",
      redirect_uri: "savebutton://auth/callback"
    )
    stale = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: "test2",
      redirect_uri: "savebutton://auth/callback"
    )
    stale.update!(expires_at: 1.minute.ago)

    assert_includes AuthorizationCode.expired, stale
    assert_not_includes AuthorizationCode.expired, fresh
  end
end
