# == Schema Information
#
# Table name: sessions
# Database name: primary
#
#  id         :uuid             not null, primary key
#  ip_address :string
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_sessions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :session do
    user
    user_agent { "Mozilla/5.0 (compatible; TestBot/1.0)" }
    ip_address { "127.0.0.1" }
  end
end
