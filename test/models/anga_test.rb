# == Schema Information
#
# Table name: angas
# Database name: primary
#
#  id         :uuid             not null, primary key
#  filename   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_angas_on_user_id               (user_id)
#  index_angas_on_user_id_and_filename  (user_id,filename) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class AngaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "bookmark_url returns nil for non-bookmark files" do
    anga = build(:anga, :note)
    anga.save!
    assert_nil anga.bookmark_url
  end

  test "bookmark_url extracts URL from .url file content when no bookmark record exists" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-01-30T120000-extract-test.url")
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://extracted-url.com"),
      filename: "2025-01-30T120000-extract-test.url",
      content_type: "text/plain"
    )
    # Use insert to bypass callbacks and test URL extraction without Bookmark
    anga.id = SecureRandom.uuid
    Anga.insert({
      id: anga.id,
      user_id: user.id,
      filename: anga.filename,
      created_at: Time.current,
      updated_at: Time.current
    })
    anga = Anga.find(anga.id)
    # Reattach file since insert bypasses ActiveStorage
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://extracted-url.com"),
      filename: "2025-01-30T120000-extract-test.url",
      content_type: "text/plain"
    )

    assert_nil anga.bookmark
    assert_equal "https://extracted-url.com", anga.bookmark_url
  end

  test "bookmark_url returns stored URL from bookmark record when present" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-01-30T120001-stored-test.url")
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://file-url.com"),
      filename: "2025-01-30T120001-stored-test.url",
      content_type: "text/plain"
    )
    # Bypass callback to create bookmark manually with different URL
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
      io: StringIO.new("[InternetShortcut]\nURL=https://file-url.com"),
      filename: "2025-01-30T120001-stored-test.url",
      content_type: "text/plain"
    )
    anga.create_bookmark!(url: "https://stored-url.com")

    # Should return stored URL, not extracted URL
    assert_equal "https://stored-url.com", anga.bookmark_url
  end

  test "bookmark_file? returns true for .url files" do
    anga = build(:anga, :bookmark)
    assert anga.bookmark_file?
  end

  test "bookmark_file? returns false for non-.url files" do
    anga = build(:anga, :note)
    assert_not anga.bookmark_file?
  end

  test "setup_bookmark enqueues SetupBookmarkJob" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-01-30T120002-setup-test.url")
    anga.file.attach(
      io: StringIO.new("[InternetShortcut]\nURL=https://setup-test.com"),
      filename: "2025-01-30T120002-setup-test.url",
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

    assert_enqueued_with(job: SetupBookmarkJob, args: [ anga.id ]) do
      anga.send(:setup_bookmark)
    end
  end

  test "does not create bookmark for non-.url files" do
    anga = build(:anga, :note)
    anga.save!
    assert_nil anga.bookmark
  end

  # --- Filename encoding ---

  test "filename with spaces is URL-encoded on save" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-06-28T120000-note with spaces.md")
    anga.file.attach(
      io: StringIO.new("# Note"),
      filename: "2025-06-28T120000-note with spaces.md",
      content_type: "text/markdown"
    )
    anga.save!

    assert_equal "2025-06-28T120000-note%20with%20spaces.md", anga.filename
  end

  test "filename with unicode is URL-encoded on save" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-06-28T120000-unicode-日本語.md")
    anga.file.attach(
      io: StringIO.new("# Note"),
      filename: "2025-06-28T120000-unicode-日本語.md",
      content_type: "text/markdown"
    )
    anga.save!

    assert_equal "2025-06-28T120000-unicode-%E6%97%A5%E6%9C%AC%E8%AA%9E.md", anga.filename
  end

  test "already-encoded filename is not double-encoded" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-06-28T120000-note%20with%20spaces.md")
    anga.file.attach(
      io: StringIO.new("# Note"),
      filename: "2025-06-28T120000-note%20with%20spaces.md",
      content_type: "text/markdown"
    )
    anga.save!

    assert_equal "2025-06-28T120000-note%20with%20spaces.md", anga.filename
  end

  test "filename with commas is URL-encoded on save" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-06-28T120000-one,two,three.md")
    anga.file.attach(
      io: StringIO.new("# Note"),
      filename: "2025-06-28T120000-one,two,three.md",
      content_type: "text/markdown"
    )
    anga.save!

    assert_equal "2025-06-28T120000-one%2Ctwo%2Cthree.md", anga.filename
  end

  test "safe filename is unchanged after encoding" do
    user = create(:user)
    anga = user.angas.new(filename: "2025-06-28T120000-simple-note.md")
    anga.file.attach(
      io: StringIO.new("# Note"),
      filename: "2025-06-28T120000-simple-note.md",
      content_type: "text/markdown"
    )
    anga.save!

    assert_equal "2025-06-28T120000-simple-note.md", anga.filename
  end

  test "filename_url_safe? returns true for safe filenames" do
    assert Anga.filename_url_safe?("2025-06-28T120000-simple-note.md")
    assert Anga.filename_url_safe?("2025-06-28T120000-note%20with%20spaces.md")
  end

  test "filename_url_safe? returns false for unsafe filenames" do
    assert_not Anga.filename_url_safe?("2025-06-28T120000-note with spaces.md")
    assert_not Anga.filename_url_safe?("2025-06-28T120000-日本語.md")
  end
end
