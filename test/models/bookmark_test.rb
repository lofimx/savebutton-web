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
require "test_helper"

class BookmarkTest < ActiveSupport::TestCase
  test "requires url" do
    bookmark = Bookmark.new(anga: create(:anga))
    assert_not bookmark.valid?
    assert_includes bookmark.errors[:url], "can't be blank"
  end

  test "cached? returns false when not cached" do
    bookmark = create(:bookmark)
    assert_not bookmark.cached?
  end

  test "cached? returns true when cached" do
    bookmark = create(:bookmark, :cached)
    assert bookmark.cached?
  end

  test "cache_directory_name returns anga filename" do
    anga = create(:anga)
    bookmark = create(:bookmark, anga: anga)
    assert_equal anga.filename, bookmark.cache_directory_name
  end

  test "cached_file_list includes index.html when cached" do
    bookmark = create(:bookmark, :cached)
    assert_includes bookmark.cached_file_list, "index.html"
  end

  test "cached_file_list includes favicon.ico when cached" do
    bookmark = create(:bookmark, :cached)
    assert_includes bookmark.cached_file_list, "favicon.ico"
  end

  test "cached_file_list is empty when not cached" do
    bookmark = create(:bookmark)
    assert_empty bookmark.cached_file_list
  end

  test "generates uuid on create" do
    bookmark = create(:bookmark)
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, bookmark.id)
  end
end
