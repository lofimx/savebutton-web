# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  email_address       :string           not null
#  incidental_password :boolean          default(FALSE), not null
#  password_digest     :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#
FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password" }
    incidental_password { false }

    trait :with_incidental_password do
      password { SecureRandom.hex(32) }
      incidental_password { true }
    end

    trait :with_avatar do
      after(:create) do |user|
        user.avatar.attach(
          io: StringIO.new("fake image data"),
          filename: "avatar.png",
          content_type: "image/png"
        )
      end
    end
  end
end
