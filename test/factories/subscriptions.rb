# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  bytes_used             :bigint           default(0), not null
#  current_period_end     :datetime
#  grace_period_ends_at   :datetime
#  slop_enabled           :boolean          default(FALSE), not null
#  stripe_status          :string
#  tier                   :integer          default("free"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#  user_id                :uuid             not null
#
# Indexes
#
#  index_subscriptions_on_stripe_customer_id      (stripe_customer_id) UNIQUE WHERE (stripe_customer_id IS NOT NULL)
#  index_subscriptions_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE WHERE (stripe_subscription_id IS NOT NULL)
#  index_subscriptions_on_tier                    (tier)
#  index_subscriptions_on_user_id                 (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :subscription do
    user
    tier { :free }

    trait :basic do
      tier { :basic }
      stripe_customer_id { "cus_test_#{SecureRandom.hex(6)}" }
      stripe_subscription_id { "sub_test_#{SecureRandom.hex(6)}" }
      stripe_status { "active" }
    end

    trait :advanced do
      tier { :advanced }
      stripe_customer_id { "cus_test_#{SecureRandom.hex(6)}" }
      stripe_subscription_id { "sub_test_#{SecureRandom.hex(6)}" }
      stripe_status { "active" }
    end

    trait :friend do
      tier { :friend }
    end

    trait :in_grace_period do
      grace_period_ends_at { Time.current + 5.days }
    end

    trait :grace_expired do
      grace_period_ends_at { Time.current - 1.day }
    end
  end
end
