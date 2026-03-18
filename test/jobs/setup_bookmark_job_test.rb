require "test_helper"

class SetupBookmarkJobTest < ActiveJob::TestCase
  test "creates bookmark and enqueues CacheBookmarkJob for .url files" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-01-30T120000-job-test.url")
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://job-test.com"),
      filename: "2025-01-30T120000-job-test.url",
      content_type: "text/plain"
    )
    anga.id = SecureRandom.uuid
    Anga.insert({
      id: anga.id,
      user_id: user.id,
      filename: anga.filename,
      created_at: Time.current,
      updated_at: Time.current
    })
    anga = Anga.find(anga.id)
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://job-test.com"),
      filename: "2025-01-30T120000-job-test.url",
      content_type: "text/plain"
    )

    assert_nil anga.bookmark

    assert_enqueued_with(job: CacheBookmarkJob) do
      SetupBookmarkJob.perform_now(anga.id)
    end

    anga.reload
    assert_not_nil anga.bookmark
    assert_equal "https://job-test.com", anga.bookmark.url
  end

  test "does not create duplicate bookmark if one already exists" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-01-30T120001-dup-test.url")
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://example.com"),
      filename: "2025-01-30T120001-dup-test.url",
      content_type: "text/plain"
    )
    anga.id = SecureRandom.uuid
    Anga.insert({
      id: anga.id,
      user_id: user.id,
      filename: anga.filename,
      created_at: Time.current,
      updated_at: Time.current
    })
    anga = Anga.find(anga.id)
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://example.com"),
      filename: "2025-01-30T120001-dup-test.url",
      content_type: "text/plain"
    )
    anga.create_bookmark!(url: "https://existing.com")
    original_bookmark_id = anga.bookmark.id

    # Job should not create another bookmark
    SetupBookmarkJob.perform_now(anga.id)
    anga.reload

    assert_equal original_bookmark_id, anga.bookmark.id
    assert_equal "https://existing.com", anga.bookmark.url
  end

  test "does nothing for non-.url files" do
    anga = create(:anga, :note)

    assert_no_enqueued_jobs only: CacheBookmarkJob do
      SetupBookmarkJob.perform_now(anga.id)
    end

    anga.reload
    assert_nil anga.bookmark
  end

  test "does nothing for non-existent anga" do
    assert_no_enqueued_jobs only: CacheBookmarkJob do
      SetupBookmarkJob.perform_now(SecureRandom.uuid)
    end
  end
end
