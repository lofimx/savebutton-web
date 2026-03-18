require "test_helper"

class Api::V1::HandshakeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "should return 401 without authentication" do
    get api_v1_handshake_url
    assert_response :unauthorized
  end

  test "should return 401 with invalid credentials" do
    get api_v1_handshake_url, headers: basic_auth_header("wrong@example.com", "wrongpass")
    assert_response :unauthorized
  end

  test "should return user endpoint info with valid credentials" do
    get api_v1_handshake_url, headers: basic_auth_header(@user.email_address, "password")
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @user.email_address, json["user_email"]
    assert_includes json["anga_endpoint"], @user.email_address
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
