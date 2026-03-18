require "test_helper"
require "minitest/mock"

class CacheBookmarkJobTest < ActiveJob::TestCase
  test "enqueues ExtractPlaintextBookmarkJob after successful caching" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-example.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com")

    # Simulate successful caching by stubbing WebpageCacheService
    mock_service = Minitest::Mock.new
    mock_service.expect(:cache, nil)

    WebpageCacheService.stub(:new, mock_service) do
      # Simulate that caching succeeded
      bookmark.update!(cached_at: Time.current)
      bookmark.html_file.attach(
        io: StringIO.new("<html><body>Cached</body></html>"),
        filename: "index.html",
        content_type: "text/html"
      )

      assert_enqueued_with(job: ExtractPlaintextBookmarkJob, args: [ bookmark.id ]) do
        CacheBookmarkJob.perform_now(bookmark.id)
      end
    end

    mock_service.verify
  end

  test "does not enqueue extraction job when caching fails" do
    user = create(:user)
    anga = create(:anga, :bookmark, user: user, filename: "2024-01-01T120000-fail.url")
    bookmark = create(:bookmark, anga: anga, url: "https://example.com")

    # Simulate failed caching
    mock_service = Minitest::Mock.new
    mock_service.expect(:cache, nil)

    WebpageCacheService.stub(:new, mock_service) do
      assert_no_enqueued_jobs(only: ExtractPlaintextBookmarkJob) do
        CacheBookmarkJob.perform_now(bookmark.id)
      end
    end

    mock_service.verify
  end

  test "does nothing for non-existent bookmark" do
    assert_nothing_raised do
      CacheBookmarkJob.perform_now(SecureRandom.uuid)
    end
  end
end
