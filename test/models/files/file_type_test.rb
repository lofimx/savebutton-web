require "test_helper"

class Files::FileTypeTest < ActiveSupport::TestCase
  test "blurb? returns true for .md files" do
    assert Files::FileType.new("2026-04-21T120000-blurb.md").blurb?
  end

  test "blurb? returns true for legacy -note.md files (pre-rename)" do
    # Existing user data created before "note" was renamed to "blurb" still
    # uses the -note.md slug. The .md extension is the canonical signal — the
    # slug is decorative. Legacy filenames must continue to be classified as
    # blurbs.
    assert Files::FileType.new("2026-04-20T120000-note.md").blurb?
  end

  test "blurb? returns true for arbitrary -slug.md filenames" do
    assert Files::FileType.new("2026-04-21T120000-anything-here.md").blurb?
  end

  test "blurb? returns false for .url files" do
    assert_not Files::FileType.new("2026-04-21T120000-bookmark.url").blurb?
  end

  test "preview_type returns 'blurb' for .md files" do
    assert_equal "blurb", Files::FileType.new("2026-04-21T120000-blurb.md").preview_type
  end

  test "preview_type returns 'blurb' for legacy -note.md files" do
    assert_equal "blurb", Files::FileType.new("2026-04-20T120000-note.md").preview_type
  end

  test "common_pattern_query? recognises 'blurb'" do
    assert Files::FileType.common_pattern_query?("blurb")
  end

  test "common_pattern_query? recognises legacy 'note' as a common pattern" do
    assert Files::FileType.common_pattern_query?("note")
  end
end
