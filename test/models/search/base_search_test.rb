require "test_helper"

# Tests for BaseSearch functionality, tested via GenericFileSearch
class Search::BaseSearchTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "matches word in middle of hyphenated filename" do
    anga = create(:anga, user: @user, filename: "2026-01-28T205243-three-button-mooze.png")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("button")

    assert result.match?, "Expected 'button' to match filename 'three-button-mooze'"
    assert_equal 1.0, result.score
    assert_equal anga.filename, result.matched_text
  end

  test "matches first word in hyphenated filename" do
    anga = create(:anga, user: @user, filename: "2026-01-28T205243-three-button-mooze.png")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("three")

    assert result.match?
    assert_equal 1.0, result.score
  end

  test "matches last word in hyphenated filename" do
    anga = create(:anga, user: @user, filename: "2026-01-28T205243-three-button-mooze.png")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("mooze")

    assert result.match?
    assert_equal 1.0, result.score
  end

  test "fuzzy matches words in hyphenated filename" do
    anga = create(:anga, user: @user, filename: "2026-01-28T205243-documentation-guide.png")

    search = Search::GenericFileSearch.new(anga)
    # "documntation" is close to "documentation"
    result = search.search("documentation")

    assert result.match?
    assert result.score >= 0.75
  end

  test "does not match unrelated words" do
    anga = create(:anga, user: @user, filename: "2026-01-28T205243-three-button-mooze.png")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("elephant")

    assert_not result.match?
  end

  test "substring match finds query within longer word in filename" do
    anga = create(:anga, user: @user, filename: "2026-01-31T072501-newmymind_type.svg")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("mind")

    assert result.match?, "Expected 'mind' to substring-match 'newmymind'"
    assert result.score >= 0.75
  end

  test "substring match finds query within content word" do
    anga = create(:anga, :note, user: @user, filename: "2026-01-01T120000-test.md")
    anga.file.attach(
      io: StringIO.new("This document discusses superheroes and their powers."),
      filename: anga.filename,
      content_type: "text/markdown"
    )

    search = Search::NoteSearch.new(anga)
    result = search.search("hero")

    assert result.match?, "Expected 'hero' to substring-match 'superheroes'"
    assert result.score >= 0.75
  end

  test "substring match requires minimum 2 character query" do
    anga = create(:anga, user: @user, filename: "2026-01-31T072501-xylophone.png")

    search = Search::GenericFileSearch.new(anga)
    result = search.search("x")

    assert_not result.match?, "Single character queries should not substring-match"
  end

  test "substring match scores higher for better coverage ratio" do
    anga_short = create(:anga, user: @user, filename: "2026-01-01T120000-mind.png")
    anga_long = create(:anga, user: @user, filename: "2026-01-01T120001-newmymind.png")

    search_short = Search::GenericFileSearch.new(anga_short)
    search_long = Search::GenericFileSearch.new(anga_long)

    result_short = search_short.search("mind")
    result_long = search_long.search("mind")

    assert result_short.match?
    assert result_long.match?
    assert result_short.score > result_long.score,
      "Exact match should score higher than substring match"
  end
end
