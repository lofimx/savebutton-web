# == Schema Information
#
# Table name: bookmarks
# Database name: primary
#
#  id          :uuid             not null, primary key
#  cache_error :text
#  cached_at   :datetime
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  anga_id     :uuid             not null
#
# Indexes
#
#  index_bookmarks_on_anga_id  (anga_id)
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id)
#
FactoryBot.define do
  factory :bookmark do
    anga
    url { "https://example.com" }
    cached_at { nil }

    trait :cached do
      cached_at { Time.current }
      after(:create) do |bookmark|
        bookmark.html_file.attach(
          io: StringIO.new("<html><body>Test</body></html>"),
          filename: "index.html",
          content_type: "text/html"
        )
        bookmark.favicon.attach(
          io: StringIO.new("fake-favicon-data"),
          filename: "favicon.ico",
          content_type: "image/x-icon"
        )
      end
    end
  end
end
