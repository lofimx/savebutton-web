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
require "test_helper"

class WordsTest < ActiveSupport::TestCase
  test "requires source_type" do
    words = Words.new(anga: create(:anga))
    assert_not words.valid?
    assert_includes words.errors[:source_type], "can't be blank"
  end

  test "source_type must be bookmark or pdf" do
    words = Words.new(anga: create(:anga), source_type: "invalid")
    assert_not words.valid?
    assert_includes words.errors[:source_type], "is not included in the list"
  end

  test "accepts bookmark source_type" do
    words = create(:words, :bookmark)
    assert words.valid?
    assert_equal "bookmark", words.source_type
  end

  test "accepts pdf source_type" do
    words = create(:words, :pdf)
    assert words.valid?
    assert_equal "pdf", words.source_type
  end

  test "generates uuid on create" do
    words = create(:words)
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, words.id)
  end

  test "extracted? returns false when not extracted" do
    words = create(:words)
    assert_not words.extracted?
  end

  test "extracted? returns true when extracted" do
    words = create(:words, :extracted)
    assert words.extracted?
  end

  test "extract_failed? returns true when error present" do
    words = create(:words, :failed)
    assert words.extract_failed?
  end

  test "extract_failed? returns false when no error" do
    words = create(:words)
    assert_not words.extract_failed?
  end

  test "extract_pending? returns true when neither extracted nor failed" do
    words = create(:words)
    assert words.extract_pending?
  end

  test "extract_pending? returns false when extracted" do
    words = create(:words, :extracted)
    assert_not words.extract_pending?
  end

  test "extract_pending? returns false when failed" do
    words = create(:words, :failed)
    assert_not words.extract_pending?
  end

  test "words_filename returns .md for bookmarks" do
    anga = create(:anga, :bookmark, filename: "2024-01-01T120000-example.url")
    words = create(:words, :bookmark, anga: anga)
    assert_equal "2024-01-01T120000-example.md", words.words_filename
  end

  test "words_filename returns .txt for pdfs" do
    anga = create(:anga, :pdf, filename: "2024-01-01T120000-document.pdf")
    words = create(:words, :pdf, anga: anga)
    assert_equal "2024-01-01T120000-document.txt", words.words_filename
  end

  test "belongs to anga" do
    anga = create(:anga)
    words = create(:words, anga: anga)
    assert_equal anga, words.anga
  end

  test "destroying anga destroys words" do
    anga = create(:anga)
    create(:words, anga: anga)
    assert_difference("Words.count", -1) do
      anga.destroy
    end
  end
end
