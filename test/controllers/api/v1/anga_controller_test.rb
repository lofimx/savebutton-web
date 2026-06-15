require "test_helper"

class Api::V1::AngaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    # Pre-existing tests in this file pre-date the per-tier quota rules and use
    # arbitrary .md/binary filenames. Upgrade the default user to basic so those
    # tests continue to validate filename encoding and round-trip behaviour.
    # The dedicated quota tests (further down) override the tier explicitly.
    @user.subscription.update!(tier: :basic)
  end

  test "should return 401 without authentication" do
    get api_v1_user_anga_index_url(user_email: @user.email_address)
    assert_response :unauthorized
  end

  test "should return 403 when accessing another user's anga" do
    other_user = create(:user)
    get api_v1_user_anga_index_url(user_email: other_user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
  end

  test "index should return empty list when no files" do
    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "", response.body.strip
  end

  test "index should return list of filenames" do
    create(:anga, user: @user, filename: "2025-06-28T120000-blurb.md")
    create(:anga, :bookmark, user: @user, filename: "2025-06-29T130000-bookmark.url")

    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")
    assert_includes lines, "2025-06-28T120000-blurb.md"
    assert_includes lines, "2025-06-29T130000-bookmark.url"
  end

  test "index includes legacy -note.md filenames" do
    create(:anga, user: @user, filename: "2024-01-01T120000-note.md")

    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    lines = response.body.strip.split("\n")
    assert_includes lines, "2024-01-01T120000-note.md"
  end

  test "index should URL-escape filenames with special characters" do
    # Create angas with special characters that need URL escaping
    create(:anga, user: @user, filename: "2025-06-28T120000-note with spaces.md")
    create(:anga, user: @user, filename: "2025-06-28T120001-special&chars.md")
    create(:anga, user: @user, filename: "2025-06-28T120002-unicode-日本語.md")

    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")

    # Filenames should be URL-escaped so clients can use them directly in URLs
    assert_includes lines, "2025-06-28T120000-note%20with%20spaces.md"
    assert_includes lines, "2025-06-28T120001-special%26chars.md"
    assert_includes lines, "2025-06-28T120002-unicode-%E6%97%A5%E6%9C%AC%E8%AA%9E.md"

    # Should NOT contain unescaped versions
    refute_includes lines, "2025-06-28T120000-note with spaces.md"
  end

  test "show should return 404 for non-existent file" do
    get api_v1_user_anga_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-missing.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "show should return file content" do
    content = "# My Blurb\n\nThis is a test blurb."
    anga = @user.angas.new(filename: "2025-06-28T120000-test.md")
    anga.file.attach(io: StringIO.new(content), filename: "2025-06-28T120000-test.md", content_type: "text/markdown")
    anga.save!

    get api_v1_user_anga_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-test.md"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal content, response.body
  end

  test "create should reject mismatched filename with 417" do
    post "/api/v1/#{@user.email_address}/anga/2025-06-28T120000-url-name.md",
         params: { file: fixture_file_upload("test_file.md", "text/markdown") },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :expectation_failed
  end

  test "create should reject duplicate filename with 409" do
    create(:anga, user: @user, filename: "2025-06-28T120000-existing.md")

    file = Tempfile.new([ "2025-06-28T120000-existing", ".md" ])
    file.write("# New content")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T120000-existing.md")

    post "/api/v1/#{@user.email_address}/anga/2025-06-28T120000-existing.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :conflict

    file.close
    file.unlink
  end

  test "create should successfully upload a new file" do
    file = Tempfile.new([ "2025-06-28T140000-new", ".md" ])
    file.write("# New Blurb")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T140000-new.md")

    assert_difference -> { @user.angas.count }, 1 do
      post "/api/v1/#{@user.email_address}/anga/2025-06-28T140000-new.md",
           params: { file: uploaded },
           headers: basic_auth_header(@user.email_address, "password")
    end
    assert_response :created

    file.close
    file.unlink
  end

  # --- Filename encoding tests ---

  test "create should store URL-encoded filename in database" do
    file = Tempfile.new([ "2025-06-28T140000-note with spaces", ".md" ])
    file.write("# Note with spaces")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T140000-note with spaces.md")

    post "/api/v1/#{@user.email_address}/anga/2025-06-28T140000-note%20with%20spaces.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created

    # Filename should be stored URL-encoded in the database
    anga = @user.angas.find_by(filename: "2025-06-28T140000-note%20with%20spaces.md")
    assert_not_nil anga
    assert_equal "2025-06-28T140000-note%20with%20spaces.md", anga.filename

    file.close
    file.unlink
  end

  test "index should never return filenames containing spaces" do
    # Insert a filename with spaces directly into the DB (bypassing model callbacks)
    # to simulate legacy data that was saved before encoding was enforced
    anga_id = SecureRandom.uuid
    Anga.insert({
      id: anga_id,
      user_id: @user.id,
      filename: "2025-06-28T120000-legacy spaces.md",
      created_at: Time.current,
      updated_at: Time.current
    })

    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    lines = response.body.strip.split("\n")

    # The safety net should encode it on output
    assert_includes lines, "2025-06-28T120000-legacy%20spaces.md"
    refute_includes lines, "2025-06-28T120000-legacy spaces.md"
  end

  test "show should find file created with spaces via encoded URL" do
    content = "# Note with spaces in name"
    anga = @user.angas.new(filename: "2025-06-28T120000-note with spaces.md")
    anga.file.attach(io: StringIO.new(content), filename: "2025-06-28T120000-note with spaces.md", content_type: "text/markdown")
    anga.save!

    # Access via the encoded URL
    get "/api/v1/#{@user.email_address}/anga/2025-06-28T120000-note%20with%20spaces.md",
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal content, response.body
  end

  test "create then list then fetch round-trip works for filenames with special characters" do
    file = Tempfile.new([ "2025-06-28T140000-special&name", ".md" ])
    file.write("# Special")
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2025-06-28T140000-special&name.md")

    # Create
    post "/api/v1/#{@user.email_address}/anga/2025-06-28T140000-special%26name.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created

    # List
    get api_v1_user_anga_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    lines = response.body.strip.split("\n")
    listed_filename = lines.find { |f| f.include?("special") }
    assert_equal "2025-06-28T140000-special%26name.md", listed_filename

    # Fetch using the listed filename directly
    get "/api/v1/#{@user.email_address}/anga/#{listed_filename}",
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "# Special", response.body

    file.close
    file.unlink
  end

  # Quota enforcement
  test "free user can post .url within 1 MB cap" do
    @user.subscription.update!(tier: :free)
    file = Tempfile.new([ "bookmark", ".url" ])
    file.write("[InternetShortcut]\nURL=https://example.com\n")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/plain", false, original_filename: "2026-05-07T120000-bookmark.url")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-bookmark.url",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created
    file.close; file.unlink
  end

  test "free user posting .url over 1 MB returns 413" do
    @user.subscription.update!(tier: :free)
    file = Tempfile.new([ "big", ".url" ])
    file.write("a" * (Subscription::MAX_STRUCTURAL_BYTES + 1))
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/plain", false, original_filename: "2026-05-07T120000-big.url")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-big.url",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :content_too_large
    file.close; file.unlink
  end

  test "free user posting binary returns 413" do
    @user.subscription.update!(tier: :free)
    file = Tempfile.new([ "img", ".png" ])
    file.write("fake png")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "image/png", false, original_filename: "2026-05-07T120000-img.png")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-img.png",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :content_too_large
    file.close; file.unlink
  end

  test "free user posting other .md returns 413" do
    @user.subscription.update!(tier: :free)
    file = Tempfile.new([ "essay", ".md" ])
    file.write("# essay\n\nhello")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2026-05-07T120000-essay.md")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-essay.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :content_too_large
    file.close; file.unlink
  end

  test "free user posting -blurb.md within 1 MB succeeds" do
    @user.subscription.update!(tier: :free)
    file = Tempfile.new([ "blurb", ".md" ])
    file.write("# blurb")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2026-05-07T120000-blurb.md")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-blurb.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created
    file.close; file.unlink
  end

  test "basic user posting binary that fits succeeds" do
    @user.subscription.update!(tier: :basic)
    file = Tempfile.new([ "img", ".png" ])
    file.write("a" * 1024)
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "image/png", false, original_filename: "2026-05-07T120000-img.png")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-img.png",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created
    file.close; file.unlink
  end

  test "basic user already over quota with expired grace returns 402" do
    # Already past the line and grace has expired (or was never started).
    @user.subscription.update!(tier: :basic, bytes_used: 2.gigabytes + 1.megabyte)
    file = Tempfile.new([ "img", ".png" ])
    file.write("more bytes")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "image/png", false, original_filename: "2026-05-07T120000-img.png")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-img.png",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :payment_required
    file.close; file.unlink
  end

  test "basic user pushing over quota for first time enters grace and succeeds" do
    @user.subscription.update!(tier: :basic, bytes_used: 2.gigabytes - 100)
    file = Tempfile.new([ "img", ".png" ])
    file.write("a" * 1024)
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "image/png", false, original_filename: "2026-05-07T120000-img.png")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-img.png",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created
    @user.subscription.reload
    assert @user.subscription.in_grace_period?
    file.close; file.unlink
  end

  test "friend user can post arbitrarily large binary" do
    @user.subscription.update!(tier: :friend)
    file = Tempfile.new([ "doc", ".pdf" ])
    file.write("a" * (10 * 1024 * 1024)) # 10 MB
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "application/pdf", false, original_filename: "2026-05-07T120000-big.pdf")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-big.pdf",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created
    file.close; file.unlink
  end

  test "friend user posting .url over 1 MB still returns 413" do
    @user.subscription.update!(tier: :friend)
    file = Tempfile.new([ "big", ".url" ])
    file.write("a" * (Subscription::MAX_STRUCTURAL_BYTES + 1))
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/plain", false, original_filename: "2026-05-07T120000-big.url")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-big.url",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :content_too_large
    file.close; file.unlink
  end

  test "restricted user cannot post anything" do
    @user.update!(restricted_at: Time.current)
    file = Tempfile.new([ "blurb", ".md" ])
    file.write("# blurb")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "2026-05-07T120000-blurb.md")

    post "/api/v1/#{@user.email_address}/anga/2026-05-07T120000-blurb.md",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
    file.close; file.unlink
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
