require "test_helper"

class Api::V1::MetaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "should return 401 without authentication" do
    get api_v1_user_meta_index_url(user_email: @user.email_address)
    assert_response :unauthorized
  end

  test "should return 403 when accessing another user's meta" do
    other_user = create(:user)
    get api_v1_user_meta_index_url(user_email: other_user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
  end

  test "index should return empty list when no meta files" do
    get api_v1_user_meta_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "", response.body.strip
  end

  test "index should return list of meta filenames" do
    create(:meta, user: @user, filename: "2025-06-28T120000-meta1.toml", anga_filename: "2025-06-28T120000-bookmark.url")
    create(:meta, user: @user, filename: "2025-06-29T130000-meta2.toml", anga_filename: "2025-06-29T130000-note.md")

    get api_v1_user_meta_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")
    assert_includes lines, "2025-06-28T120000-meta1.toml"
    assert_includes lines, "2025-06-29T130000-meta2.toml"
  end

  test "index should URL-escape filenames with special characters" do
    create(:meta, user: @user, filename: "2025-06-28T120000-meta with spaces.toml", anga_filename: "2025-06-28T120000-test.url")

    get api_v1_user_meta_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal "text/plain", response.media_type

    lines = response.body.strip.split("\n")
    assert_includes lines, "2025-06-28T120000-meta%20with%20spaces.toml"
    refute_includes lines, "2025-06-28T120000-meta with spaces.toml"
  end

  test "show should return 404 for non-existent file" do
    get api_v1_user_meta_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-missing.toml"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "show should return file content" do
    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T120000-test.url"

      [meta]
      tags = ["podcast", "tech"]
      note = '''A test note.'''
    TOML
    meta_record = @user.metas.new(
      filename: "2025-06-28T120000-test-meta.toml",
      anga_filename: "2025-06-28T120000-test.url"
    )
    meta_record.file.attach(io: StringIO.new(toml_content), filename: "2025-06-28T120000-test-meta.toml", content_type: "application/toml")
    meta_record.save!

    get api_v1_user_meta_file_url(user_email: @user.email_address, filename: "2025-06-28T120000-test-meta.toml"),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
    assert_equal toml_content, response.body
  end

  test "create should reject mismatched filename with 417" do
    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T120000-bookmark.url"

      [meta]
      tags = ["test"]
    TOML

    file = Tempfile.new([ "2025-06-28T120000-wrong", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T120000-wrong.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T120000-url-name.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :expectation_failed

    file.close
    file.unlink
  end

  test "create should reject duplicate filename with 409" do
    create(:meta, user: @user, filename: "2025-06-28T120000-existing.toml", anga_filename: "2025-06-28T120000-test.url")

    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T120000-test.url"

      [meta]
      tags = ["new"]
    TOML

    file = Tempfile.new([ "2025-06-28T120000-existing", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T120000-existing.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T120000-existing.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :conflict

    file.close
    file.unlink
  end

  test "create should reject invalid TOML without anga section" do
    toml_content = <<~TOML
      [meta]
      tags = ["test"]
    TOML

    file = Tempfile.new([ "2025-06-28T140000-invalid", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T140000-invalid.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T140000-invalid.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :unprocessable_entity

    file.close
    file.unlink
  end

  test "create should successfully upload a new meta file" do
    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T140000-my-bookmark.url"

      [meta]
      tags = ["podcast", "democracy"]
      note = '''This is a test note.'''
    TOML

    file = Tempfile.new([ "2025-06-28T140000-new-meta", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T140000-new-meta.toml")

    assert_difference -> { @user.metas.count }, 1 do
      post "/api/v1/#{@user.email_address}/meta/2025-06-28T140000-new-meta.toml",
           params: { file: uploaded },
           headers: basic_auth_header(@user.email_address, "password")
    end
    assert_response :created

    meta_record = @user.metas.find_by(filename: "2025-06-28T140000-new-meta.toml")
    assert_equal "2025-06-28T140000-my-bookmark.url", meta_record.anga_filename

    file.close
    file.unlink
  end

  test "create should link meta to existing anga" do
    # Create an anga first
    anga = create(:anga, user: @user, filename: "2025-06-28T140000-existing-bookmark.url")

    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T140000-existing-bookmark.url"

      [meta]
      tags = ["linked", "test"]
    TOML

    file = Tempfile.new([ "2025-06-28T140001-linked-meta", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T140001-linked-meta.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T140001-linked-meta.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created

    meta = @user.metas.find_by(filename: "2025-06-28T140001-linked-meta.toml")
    assert_equal anga, meta.anga
    assert_not meta.orphan

    file.close
    file.unlink
  end

  test "create should mark meta as orphan when anga does not exist" do
    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T140000-nonexistent-bookmark.url"

      [meta]
      tags = ["orphan", "test"]
    TOML

    file = Tempfile.new([ "2025-06-28T140001-orphan-meta", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T140001-orphan-meta.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T140001-orphan-meta.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created

    meta = @user.metas.find_by(filename: "2025-06-28T140001-orphan-meta.toml")
    assert_nil meta.anga
    assert meta.orphan

    file.close
    file.unlink
  end

  # --- Filename encoding tests ---

  test "create should store URL-encoded filename in database" do
    toml_content = <<~TOML
      [anga]
      filename = "2025-06-28T140000-my-bookmark.url"

      [meta]
      tags = ["test"]
    TOML

    file = Tempfile.new([ "2025-06-28T140000-meta with spaces", ".toml" ])
    file.write(toml_content)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "application/toml", false, original_filename: "2025-06-28T140000-meta with spaces.toml")

    post "/api/v1/#{@user.email_address}/meta/2025-06-28T140000-meta%20with%20spaces.toml",
         params: { file: uploaded },
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :created

    meta = @user.metas.find_by(filename: "2025-06-28T140000-meta%20with%20spaces.toml")
    assert_not_nil meta
    assert_equal "2025-06-28T140000-meta%20with%20spaces.toml", meta.filename

    file.close
    file.unlink
  end

  test "index should never return filenames containing spaces" do
    # Insert a filename with spaces directly into the DB (bypassing model callbacks)
    meta_id = SecureRandom.uuid
    Meta.insert({
      id: meta_id,
      user_id: @user.id,
      filename: "2025-06-28T120000-legacy spaces.toml",
      anga_filename: "2025-06-28T120000-test.url",
      orphan: true,
      created_at: Time.current,
      updated_at: Time.current
    })

    get api_v1_user_meta_index_url(user_email: @user.email_address),
        headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    lines = response.body.strip.split("\n")

    assert_includes lines, "2025-06-28T120000-legacy%20spaces.toml"
    refute_includes lines, "2025-06-28T120000-legacy spaces.toml"
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
