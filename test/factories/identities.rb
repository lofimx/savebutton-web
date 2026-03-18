# == Schema Information
#
# Table name: identities
# Database name: primary
#
#  id         :uuid             not null, primary key
#  provider   :string           not null
#  uid        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_identities_on_provider_and_uid  (provider,uid) UNIQUE
#  index_identities_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :identity do
    user
    provider { "google_oauth2" }
    sequence(:uid) { |n| "oauth-uid-#{n}" }

    trait :google do
      provider { "google_oauth2" }
    end

    trait :apple do
      provider { "apple" }
    end

    trait :microsoft do
      provider { "microsoft_graph" }
    end
  end
end
