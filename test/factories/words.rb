# == Schema Information
#
# Table name: words
# Database name: primary
#
#  id            :uuid             not null, primary key
#  extract_error :text
#  extracted_at  :datetime
#  source_type   :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  anga_id       :uuid             not null
#
# Indexes
#
#  index_words_on_anga_id  (anga_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id)
#
FactoryBot.define do
  factory :words do
    anga
    source_type { "bookmark" }

    trait :bookmark do
      source_type { "bookmark" }
    end

    trait :pdf do
      source_type { "pdf" }
    end

    trait :extracted do
      extracted_at { Time.current }

      after(:create) do |words|
        content = words.source_type == "bookmark" ? "# Extracted Content\n\nSample extracted text." : "Extracted PDF text content."
        filename = words.source_type == "bookmark" ? "#{File.basename(words.anga.filename, '.*')}.md" : "#{File.basename(words.anga.filename, '.*')}.txt"
        content_type = words.source_type == "bookmark" ? "text/markdown" : "text/plain"

        words.file.attach(
          io: StringIO.new(content),
          filename: filename,
          content_type: content_type
        )
      end
    end

    trait :failed do
      extract_error { "Failed to extract plaintext" }
    end
  end
end
