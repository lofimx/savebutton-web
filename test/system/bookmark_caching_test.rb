require "application_system_test_case"

class BookmarkCachingTest < ApplicationSystemTestCase
  include FactoryBot::Syntax::Methods

  setup do
    @user = create(:user, password: "password123")

    # Create a bookmark anga for postgresql.org
    @anga = create(:anga, :bookmark, user: @user)
    @anga.file.purge
    @anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://www.postgresql.org/"),
      filename: @anga.filename,
      content_type: "text/plain"
    )

    # Create the bookmark record (uncached)
    @bookmark = Bookmark.create!(anga: @anga, url: "https://www.postgresql.org/")
  end

  def sign_in_via_form(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Log in"
  end

  test "caching spinner is replaced by iframe when bookmark is cached" do
    sign_in_via_form(@user)

    # Should be redirected to everything page after login
    assert_current_path app_everything_path

    # Debug: check if tiles are present
    assert_selector ".anga-grid", wait: 5

    # Find and click the bookmark tile (tile displays the URL for bookmarks)
    tile = find(".anga-tile", text: @bookmark.url, wait: 10)
    assert tile, "Bookmark tile should be visible"

    # Verify the tile shows the default bookmark icon (not cached yet)
    within(tile) do
      assert_selector "svg", visible: true
    end

    # Click the tile to open the preview modal
    tile.click

    # The modal should open
    assert_selector ".preview-modal.active", wait: 5

    # Initially, we should see the caching status (spinner) or it may have already completed
    # Since caching runs synchronously now, we wait for the iframe to appear
    assert_selector "iframe.preview-cached-page", wait: 30

    # Verify the iframe is showing the cached content
    # Use has_css? with a block to avoid stale element issues
    assert page.has_css?("iframe.preview-cached-page[src*='cache/index.html']", wait: 5),
           "Iframe should have src containing cache/index.html"

    # Verify the bookmark record is now cached
    @bookmark.reload
    assert @bookmark.cached?, "Bookmark should be cached after preview"
    assert @bookmark.html_file.attached?, "HTML file should be attached"
  end

  test "shows error message when caching fails" do
    # Create a bookmark with an invalid URL that will fail to cache
    invalid_anga = create(:anga, :bookmark, user: @user)
    invalid_anga.file.purge
    invalid_anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://this-domain-definitely-does-not-exist-12345.invalid/"),
      filename: invalid_anga.filename,
      content_type: "text/plain"
    )
    invalid_bookmark = Bookmark.create!(
      anga: invalid_anga,
      url: "https://this-domain-definitely-does-not-exist-12345.invalid/"
    )

    # Sign in
    sign_in_via_form(@user)

    # Should be redirected to everything page after login
    assert_current_path app_everything_path

    # Debug: check if tiles are present
    assert_selector ".anga-grid", wait: 5

    # Find and click the invalid bookmark tile (tile displays the URL for bookmarks)
    tile = find(".anga-tile", text: invalid_bookmark.url, wait: 10)
    tile.click

    # The modal should open
    assert_selector ".preview-modal.active", wait: 5

    # Should show an error message since the URL cannot be fetched
    assert_selector ".preview-cache-error", wait: 30

    # Verify error message is displayed
    within(".preview-cache-error") do
      assert_text "Failed to cache webpage"
    end

    # Verify the bookmark has an error recorded
    invalid_bookmark.reload
    assert invalid_bookmark.cache_failed?, "Bookmark should have cache error"
    assert invalid_bookmark.cache_error.present?, "Cache error message should be set"
  end
end
