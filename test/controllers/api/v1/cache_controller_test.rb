require "test_helper"

class Api::V1::CacheControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "index should URL-escape bookmark filenames with special characters" do
    # Create angas with bookmarks that have special characters
    anga1 = create(:anga, :bookmark, user: @user, filename: "2025-06-28T120000-example with spaces.url")
    create(:bookmark, :cached, anga: anga1, url: "https://example.com")

    anga2 = create(:anga, :bookmark, user: @user, filename: "2025-06-28T120001-special&chars.url")
    create(:bookmark, :cached, anga: anga2, url: "https://example.org")

    get api_v1_cache_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")

    # Filenames should be URL-escaped so clients can use them directly in URLs
    assert_includes lines, "2025-06-28T120000-example%20with%20spaces.url"
    assert_includes lines, "2025-06-28T120001-special%26chars.url"

    # Should NOT contain unescaped versions
    refute_includes lines, "2025-06-28T120000-example with spaces.url"
  end

  test "show should URL-escape cached file names with special characters" do
    anga = create(:anga, :bookmark, user: @user, filename: "2025-06-28T120000-test.url")
    bookmark = create(:bookmark, :cached, anga: anga, url: "https://example.com")

    # Attach an asset with special characters in its name
    bookmark.assets.attach(
      io: StringIO.new("body { color: red; }"),
      filename: "style sheet.css",
      content_type: "text/css"
    )

    get api_v1_cache_bookmark_url(user_email: @user.email_address, bookmark: anga.filename),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")

    # Asset filenames should be URL-escaped
    assert_includes lines, "style%20sheet.css"
    refute_includes lines, "style sheet.css"

    # Standard files without special chars should still work
    assert_includes lines, "index.html"
    assert_includes lines, "favicon.ico"
  end

  test "show should return 404 for non-existent bookmark" do
    get api_v1_cache_bookmark_url(user_email: @user.email_address, bookmark: "nonexistent.url"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "show should return 404 for non-cached bookmark" do
    anga = create(:anga, :bookmark, user: @user, filename: "2025-06-28T120000-uncached.url")
    create(:bookmark, anga: anga, url: "https://example.com") # not cached

    get api_v1_cache_bookmark_url(user_email: @user.email_address, bookmark: anga.filename),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
