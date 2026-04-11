# Transient authorization codes for the PKCE flow.
# These are short-lived, single-use codes issued after a user authenticates
# via the browser, exchanged by the client for JWT tokens.
# == Schema Information
#
# Table name: authorization_codes
# Database name: primary
#
#  id             :uuid             not null, primary key
#  code           :string           not null
#  code_challenge :string           not null
#  device_name    :string
#  device_type    :string
#  expires_at     :datetime         not null
#  redirect_uri   :string           not null
#  used           :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :uuid             not null
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
class AuthorizationCode < ApplicationRecord
  EXPIRY = 5.minutes

  belongs_to :user

  validates :code, presence: true, uniqueness: true
  validates :code_challenge, presence: true
  validates :redirect_uri, presence: true
  validates :expires_at, presence: true

  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def self.generate_for(user:, code_challenge:, redirect_uri:, device_name: nil, device_type: nil)
    create!(
      user: user,
      code: SecureRandom.urlsafe_base64(32),
      code_challenge: code_challenge,
      redirect_uri: redirect_uri,
      device_name: device_name,
      device_type: device_type,
      expires_at: EXPIRY.from_now
    )
  end

  def expired?
    expires_at <= Time.current
  end

  def redeemed?
    used?
  end

  # Verify the PKCE code_verifier against the stored code_challenge (S256 method).
  def verify_pkce(code_verifier)
    expected = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier),
      padding: false
    )
    ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge)
  end

  # Mark this code as used. Returns false if already used or expired.
  def redeem!
    return false if used? || expired?

    update!(used: true)
    true
  end
end
