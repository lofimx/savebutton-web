require "test_helper"

class Files::FaviconTest < ActiveSupport::TestCase
  # --- Fixture helpers ---

  def fixture_path(filename)
    Rails.root.join("test", "fixtures", "files", filename)
  end

  def read_fixture(filename)
    File.binread(fixture_path(filename))
  end

  # --- Valid image tests ---

  test "valid? returns true for a valid ICO file" do
    content = read_fixture("favicon_valid.ico")
    favicon = Files::Favicon.new(content, "image/vnd.microsoft.icon")

    assert favicon.valid?
  end

  test "valid? returns true for a valid ICO with image/x-icon content type" do
    content = read_fixture("favicon_valid.ico")
    favicon = Files::Favicon.new(content, "image/x-icon")

    assert favicon.valid?
  end

  test "valid? returns true for a valid PNG file" do
    content = read_fixture("favicon_valid.png")
    favicon = Files::Favicon.new(content, "image/png")

    assert favicon.valid?
  end

  test "preserves content and content_type for a valid ICO" do
    content = read_fixture("favicon_valid.ico")
    favicon = Files::Favicon.new(content, "image/vnd.microsoft.icon")

    assert_equal content, favicon.content
    assert_equal "image/vnd.microsoft.icon", favicon.content_type
  end

  test "preserves content and content_type for a valid PNG" do
    content = read_fixture("favicon_valid.png")
    favicon = Files::Favicon.new(content, "image/png")

    assert_equal content, favicon.content
    assert_equal "image/png", favicon.content_type
  end

  # --- Broken ICO: iconify.design (mismatched directory dimensions) ---

  test "broken iconify ICO is sanitized to PNG" do
    content = read_fixture("favicon_broken_ico_iconify.ico")
    favicon = Files::Favicon.new(content, "image/vnd.microsoft.icon")

    assert favicon.valid?
    assert_equal "image/png", favicon.content_type
    assert_not_equal content, favicon.content
  end

  test "broken iconify ICO produces valid PNG content" do
    content = read_fixture("favicon_broken_ico_iconify.ico")
    favicon = Files::Favicon.new(content, "image/vnd.microsoft.icon")

    # Verify the output is a valid PNG by checking magic bytes
    png_magic = [ 137, 80, 78, 71 ].pack("C*")
    assert favicon.content.start_with?(png_magic), "Sanitized content should be a PNG file"
  end

  test "broken iconify ICO detected by magic bytes even with wrong content type" do
    content = read_fixture("favicon_broken_ico_iconify.ico")
    favicon = Files::Favicon.new(content, "application/octet-stream")

    # ICO magic bytes should still trigger ICO handling and sanitization
    assert favicon.valid?
    assert_equal "image/png", favicon.content_type
  end

  # --- Broken favicon: shittycodingagent.ai (HTML served as favicon) ---

  test "HTML content is invalid as a favicon" do
    content = read_fixture("favicon_html_shittycodingagent.html")
    favicon = Files::Favicon.new(content, "text/html")

    assert_not favicon.valid?
  end

  test "HTML content is not sanitized or converted" do
    content = read_fixture("favicon_html_shittycodingagent.html")
    favicon = Files::Favicon.new(content, "text/html")

    assert_equal content, favicon.content
    assert_equal "text/html", favicon.content_type
  end

  # --- Edge cases ---

  test "empty content is invalid" do
    favicon = Files::Favicon.new("", "image/png")

    assert_not favicon.valid?
  end

  test "random bytes are invalid" do
    favicon = Files::Favicon.new(SecureRandom.random_bytes(100), "image/png")

    assert_not favicon.valid?
  end

  test "truncated ICO header is invalid" do
    # ICO header is 6 bytes minimum; provide only 4
    content = [ 0, 0, 1, 0 ].pack("C*")
    favicon = Files::Favicon.new(content, "image/x-icon")

    assert_not favicon.valid?
  end

  test "ICO with zero images is invalid" do
    # Valid ICO header but 0 images
    content = [ 0, 0, 1, 0, 0, 0 ].pack("C*")
    favicon = Files::Favicon.new(content, "image/x-icon")

    assert_not favicon.valid?
  end

  test "ICO with truncated directory is invalid" do
    # Header claims 1 image but not enough bytes for the directory entry
    content = [ 0, 0, 1, 0, 1, 0, 0, 0 ].pack("C*")
    favicon = Files::Favicon.new(content, "image/x-icon")

    assert_not favicon.valid?
  end
end
