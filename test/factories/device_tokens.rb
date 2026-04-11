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
FactoryBot.define do
  factory :device_token do
    user
    device_name { "Test Device" }
    device_type { "mobile_android" }
    app_version { "1.0.0" }
    refresh_token_digest { BCrypt::Password.create(SecureRandom.urlsafe_base64(48)) }
    expires_at { 90.days.from_now }
  end
end
