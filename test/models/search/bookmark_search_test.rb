require "test_helper"

class Search::BookmarkSearchTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "searches bookmark URL" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://confer.to/")

    search = Search::BookmarkSearch.new(anga)
    result = search.search("confer")

    assert result.match?, "Expected 'confer' to match bookmark URL 'https://confer.to/'"
    assert result.score >= 0.75
  end

  test "searches bookmark URL domain components" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://shittycodingagent.ai/")

    search = Search::BookmarkSearch.new(anga)
    result = search.search("codingagent")

    assert result.match?, "Expected 'codingagent' to substring-match URL"
    assert result.score >= 0.75
  end

  test "returns no match when no words and URL does not match" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")

    search = Search::BookmarkSearch.new(anga)
    result = search.search("testing")

    assert_not result.match?
    assert_equal 0.0, result.score
  end

  test "returns no match when words extraction is pending and URL does not match" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")
    create(:words, :bookmark, anga: anga) # pending, no file attached

    search = Search::BookmarkSearch.new(anga)
    result = search.search("testing")

    assert_not result.match?
    assert_equal 0.0, result.score
  end

  test "searches extracted text content" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")
    words = create(:words, :bookmark, anga: anga, extracted_at: Time.current)
    words.file.attach(
      io: StringIO.new("# Welcome\n\nThis is a testing page with important content."),
      filename: "2024-01-01T120000-example.md",
      content_type: "text/markdown"
    )

    search = Search::BookmarkSearch.new(anga)
    result = search.search("testing")

    assert result.match?
    assert result.score >= 0.75
    assert_equal "testing", result.matched_text
  end

  test "searches multi-word phrases in extracted text" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")
    words = create(:words, :bookmark, anga: anga, extracted_at: Time.current)
    words.file.attach(
      io: StringIO.new("The quick brown fox jumps over the lazy dog."),
      filename: "2024-01-01T120000-example.md",
      content_type: "text/markdown"
    )

    search = Search::BookmarkSearch.new(anga)
    result = search.search("quick brown")

    assert result.match?
    assert result.score >= 0.75
  end

  test "uses fuzzy matching for extracted content" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")
    words = create(:words, :bookmark, anga: anga, extracted_at: Time.current)
    words.file.attach(
      io: StringIO.new("Documentation for developers"),
      filename: "2024-01-01T120000-example.md",
      content_type: "text/markdown"
    )

    search = Search::BookmarkSearch.new(anga)
    result = search.search("documentation")

    assert result.match?
    assert result.score >= 0.75
  end

  test "matches filename when not a common pattern" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-rubyguide.url")
    create(:bookmark, anga: anga, url: "https://example.com")

    search = Search::BookmarkSearch.new(anga)
    result = search.search("rubyguide")

    assert result.match?
    assert_equal anga.filename, result.matched_text
  end

  test "returns no match gracefully when words extraction failed" do
    anga = create(:anga, user: @user, filename: "2024-01-01T120000-example.url")
    create(:bookmark, anga: anga, url: "https://example.com")
    create(:words, :bookmark, :failed, anga: anga)

    search = Search::BookmarkSearch.new(anga)
    result = search.search("anything")

    assert_not result.match?
    assert_equal 0.0, result.score
  end
end
