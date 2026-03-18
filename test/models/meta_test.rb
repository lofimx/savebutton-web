# == Schema Information
#
# Table name: metas
# Database name: primary
#
#  id            :uuid             not null, primary key
#  anga_filename :string           not null
#  filename      :string           not null
#  orphan        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  anga_id       :uuid
#  user_id       :uuid             not null
#
# Indexes
#
#  index_metas_on_anga_id               (anga_id)
#  index_metas_on_user_id               (user_id)
#  index_metas_on_user_id_and_filename  (user_id,filename) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (anga_id => angas.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class MetaTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "meta is linked to anga when anga exists" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-my-bookmark.url")

    meta = @user.metas.new(
      filename: "2025-06-28T120001-meta.toml",
      anga_filename: "2025-06-28T120000-my-bookmark.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-my-bookmark.url\"\n"),
      filename: meta.filename,
      content_type: "application/toml"
    )
    meta.save!

    assert_equal anga, meta.anga
    assert_not meta.orphan
  end

  test "meta is marked as orphan when anga does not exist" do
    meta = @user.metas.new(
      filename: "2025-06-28T120001-meta.toml",
      anga_filename: "2025-06-28T120000-nonexistent.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-nonexistent.url\"\n"),
      filename: meta.filename,
      content_type: "application/toml"
    )
    meta.save!

    assert_nil meta.anga
    assert meta.orphan
  end

  test "anga.metas returns associated metas" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-test.url")

    meta1 = @user.metas.create!(
      filename: "2025-06-28T120001-meta1.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120001-meta1.toml")
    )
    meta2 = @user.metas.create!(
      filename: "2025-06-28T120002-meta2.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120002-meta2.toml")
    )

    assert_equal 2, anga.metas.count
    assert_includes anga.metas, meta1
    assert_includes anga.metas, meta2
  end

  test "orphaned scope returns only orphan metas" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-test.url")

    linked_meta = @user.metas.create!(
      filename: "2025-06-28T120001-linked.toml",
      anga_filename: "2025-06-28T120000-test.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n", "2025-06-28T120001-linked.toml")
    )
    orphan_meta = @user.metas.create!(
      filename: "2025-06-28T120002-orphan.toml",
      anga_filename: "2025-06-28T120000-nonexistent.url",
      file: fixture_file_blob("[anga]\nfilename = \"2025-06-28T120000-nonexistent.url\"\n", "2025-06-28T120002-orphan.toml")
    )

    assert_equal [ orphan_meta ], @user.metas.orphaned.to_a
    assert_equal [ linked_meta ], @user.metas.linked.to_a
  end

  # --- Filename encoding ---

  test "meta filename with spaces is URL-encoded on save" do
    meta = @user.metas.new(
      filename: "2025-06-28T120000-meta with spaces.toml",
      anga_filename: "2025-06-28T120000-test.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n"),
      filename: "2025-06-28T120000-meta with spaces.toml",
      content_type: "application/toml"
    )
    meta.save!

    assert_equal "2025-06-28T120000-meta%20with%20spaces.toml", meta.filename
  end

  test "meta filename already encoded is not double-encoded" do
    meta = @user.metas.new(
      filename: "2025-06-28T120000-meta%20with%20spaces.toml",
      anga_filename: "2025-06-28T120000-test.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n"),
      filename: "2025-06-28T120000-meta%20with%20spaces.toml",
      content_type: "application/toml"
    )
    meta.save!

    assert_equal "2025-06-28T120000-meta%20with%20spaces.toml", meta.filename
  end

  test "safe meta filename is unchanged after encoding" do
    meta = @user.metas.new(
      filename: "2025-06-28T120000-simple-meta.toml",
      anga_filename: "2025-06-28T120000-test.url"
    )
    meta.file.attach(
      io: StringIO.new("[anga]\nfilename = \"2025-06-28T120000-test.url\"\n"),
      filename: "2025-06-28T120000-simple-meta.toml",
      content_type: "application/toml"
    )
    meta.save!

    assert_equal "2025-06-28T120000-simple-meta.toml", meta.filename
  end

  private

  def fixture_file_blob(content, filename)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: "application/toml"
    )
  end
end
