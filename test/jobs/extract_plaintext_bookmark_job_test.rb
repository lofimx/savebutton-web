require "test_helper"

class ExtractPlaintextBookmarkJobTest < ActiveJob::TestCase
  test "extracts plaintext from cached bookmark HTML" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-example.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)
    bookmark.html_file.attach(
      io: StringIO.new("<html><body><h1>Article Title</h1><p>This is the main content of the article with important information.</p></body></html>"),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.words.present?
    assert anga.words.extracted?
    assert_equal "bookmark", anga.words.source_type
    assert anga.words.file.attached?
    assert_equal "2024-01-01T120000-example.md", anga.words.words_filename

    content = anga.words.file.download
    assert content.present?
  end

  test "does nothing for non-existent bookmark" do
    assert_nothing_raised do
      ExtractPlaintextBookmarkJob.perform_now(SecureRandom.uuid)
    end
  end

  test "does nothing for uncached bookmark" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-uncached.url")
    create(:bookmark, anga: anga, url: "https://example.com") # not cached

    ExtractPlaintextBookmarkJob.perform_now(anga.bookmark.id)

    anga.reload
    assert_nil anga.words
  end

  test "records error on extraction failure" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-broken.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)
    # Attach invalid content that will cause readability to produce empty content
    bookmark.html_file.attach(
      io: StringIO.new(""),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.words.present?
    assert_not anga.words.extracted?
    assert anga.words.extract_error.present?
  end

  test "extracts content from non-article pages where readability misses body text" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-costco-ride.url")
    bookmark = create(:bookmark, anga: anga, url: "https://bort.likes.it.com/moment/hPpWbvcHWe", cached_at: Time.current)

    # This HTML mimics a non-article page (activity tracker) where the meaningful
    # text content is short and surrounded by heavy structural HTML (inline SVGs,
    # large JSON data attributes, stats grids). ruby-readability's heuristics fail
    # on this kind of page, extracting only the h1 title while ignoring the
    # activity notes that contain the searchable word "costco".
    bookmark.html_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/non_article_page_timeline_likes_it_com.html")),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.words.present?, "Expected words record to be created"
    assert anga.words.extracted?, "Expected words to be marked as extracted"

    content = anga.words.file.download.force_encoding("UTF-8").downcase
    assert_includes content, "costco",
      "Expected extracted plaintext to contain 'costco' from Activity Notes section"
  end

  test "updates existing words record on re-extraction" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-retry.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com", cached_at: Time.current)

    # Create an existing failed words record
    anga.create_words!(source_type: "bookmark", extract_error: "Previous failure")

    bookmark.html_file.attach(
      io: StringIO.new("<html><body><p>Retried content that should now work properly.</p></body></html>"),
      filename: "index.html",
      content_type: "text/html"
    )

    ExtractPlaintextBookmarkJob.perform_now(bookmark.id)

    anga.reload
    assert anga.words.extracted?
    assert_nil anga.words.extract_error
  end
end
