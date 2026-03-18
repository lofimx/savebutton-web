require "test_helper"

class Api::V1::ShareControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "should return 401 without authentication" do
    post "/api/v1/#{@user.email_address}/share/anga/2025-06-28T120000-note.md"
    assert_response :unauthorized
  end

  test "should return 403 when accessing another user's namespace" do
    other_user = create(:user)
    anga = create(:anga, user: other_user, filename: "2025-06-28T120000-note.md")

    post "/api/v1/#{other_user.email_address}/share/anga/#{anga.filename}",
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :forbidden
  end

  test "should return 404 for non-existent anga" do
    post "/api/v1/#{@user.email_address}/share/anga/2025-06-28T120000-missing.md",
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :not_found
  end

  test "should return share URL for existing anga" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-note.md")

    post "/api/v1/#{@user.email_address}/share/anga/#{anga.filename}",
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("share_url"), "Response should include share_url"
    assert_includes json["share_url"], "/share/#{@user.id}/anga/#{anga.filename}"
  end

  test "should return correct share URL for filename with special characters" do
    anga = create(:anga, user: @user, filename: "2025-06-28T120000-note with spaces.md")

    post "/api/v1/#{@user.email_address}/share/anga/2025-06-28T120000-note%20with%20spaces.md",
         headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("share_url")
    assert_includes json["share_url"], "/share/#{@user.id}/anga/"
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
