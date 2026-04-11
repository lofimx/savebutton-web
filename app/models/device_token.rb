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
class DeviceToken < ApplicationRecord
  has_paper_trail

  belongs_to :user

  DEVICE_TYPES = %w[
    mobile_android
    mobile_ios
    browser_extension
    desktop_linux
    desktop_macos
    desktop_windows
  ].freeze

  REFRESH_TOKEN_EXPIRY = 90.days

  validates :device_name, presence: true
  validates :device_type, presence: true, inclusion: { in: DEVICE_TYPES }
  validates :refresh_token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Generate a new refresh token and set its digest on this record.
  # Returns the plaintext refresh token (caller must deliver it to the client).
  def generate_refresh_token!
    token = SecureRandom.urlsafe_base64(48)
    self.refresh_token_digest = BCrypt::Password.create(token)
    self.expires_at = REFRESH_TOKEN_EXPIRY.from_now
    token
  end

  # Verify a plaintext refresh token against the stored digest.
  def refresh_token_matches?(plaintext_token)
    BCrypt::Password.new(refresh_token_digest).is_password?(plaintext_token)
  end

  # Slide the expiry window forward on use.
  def touch_usage!
    update!(
      last_used_at: Time.current,
      expires_at: REFRESH_TOKEN_EXPIRY.from_now
    )
  end

  def expired?
    expires_at <= Time.current
  end
end
