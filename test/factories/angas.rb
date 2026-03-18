# == Schema Information
#
# Table name: angas
# Database name: primary
#
#  id         :uuid             not null, primary key
#  filename   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_angas_on_user_id               (user_id)
#  index_angas_on_user_id_and_filename  (user_id,filename) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :anga do
    user
    sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-note-#{n}.md" }

    after(:build) do |anga|
      unless anga.file.attached?
        anga.file.attach(
          io: StringIO.new("# Sample Note\n\nThis is a sample note."),
          filename: anga.filename,
          content_type: "text/markdown"
        )
      end
    end

    trait :note do
      sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-note-#{n}.md" }

      after(:build) do |anga|
        anga.file.attach(
          io: StringIO.new("# Sample Note\n\nThis is a sample note."),
          filename: anga.filename,
          content_type: "text/markdown"
        )
      end
    end

    trait :bookmark do
      sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-bookmark-#{n}.url" }

      after(:build) do |anga|
        anga.file.attach(
          io: StringIO.new("[InternetShortcut]\nURL=https://example.com"),
          filename: anga.filename,
          content_type: "text/plain"
        )
      end
    end

    trait :image do
      sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-image-#{n}.png" }

      after(:build) do |anga|
        anga.file.attach(
          io: StringIO.new("fake png data"),
          filename: anga.filename,
          content_type: "image/png"
        )
      end
    end

    trait :pdf do
      sequence(:filename) { |n| "#{Time.now.utc.strftime('%Y-%m-%dT%H%M%S')}-document-#{n}.pdf" }

      after(:build) do |anga|
        anga.file.attach(
          io: StringIO.new("fake pdf data"),
          filename: anga.filename,
          content_type: "application/pdf"
        )
      end
    end
  end
end
