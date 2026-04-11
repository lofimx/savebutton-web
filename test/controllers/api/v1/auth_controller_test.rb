require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false
    )
  end

  # --- Password Grant ---

  test "password grant returns tokens for valid credentials" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android",
      app_version: "1.0.0"
    }

    assert_response :created
    json = JSON.parse(response.body)
    assert json["access_token"].present?
    assert json["refresh_token"].present?
    assert_equal "Bearer", json["token_type"]
    assert json["expires_in"].positive?
    assert_equal @user.email_address, json["user_email"]
  end

  test "password grant creates a DeviceToken record" do
    assert_difference "DeviceToken.count", 1 do
      post api_v1_auth_token_url, params: {
        grant_type: "password",
        email: @user.email_address,
        password: "password",
        device_name: "Test Phone",
        device_type: "mobile_android",
        app_version: "1.0.0"
      }
    end

    dt = DeviceToken.last
    assert_equal @user, dt.user
    assert_equal "Test Phone", dt.device_name
    assert_equal "mobile_android", dt.device_type
    assert_equal "1.0.0", dt.app_version
  end

  test "password grant rejects invalid credentials" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "wrong_password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_grant", json["error"]
  end

  test "password grant rejects missing email" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }

    assert_response :bad_request
  end

  # --- Refresh Token Grant ---

  test "refresh token grant returns new access token" do
    # First, get tokens
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }
    refresh_token = JSON.parse(response.body)["refresh_token"]

    # Use refresh token
    post api_v1_auth_token_url, params: {
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["access_token"].present?
    assert_equal "Bearer", json["token_type"]
  end

  test "refresh token grant extends expiry (sliding window)" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }
    refresh_token = JSON.parse(response.body)["refresh_token"]

    dt = DeviceToken.last
    old_expires = dt.expires_at

    travel 1.day do
      post api_v1_auth_token_url, params: {
        grant_type: "refresh_token",
        refresh_token: refresh_token
      }

      assert_response :success
      dt.reload
      assert dt.expires_at > old_expires
      assert dt.last_used_at.present?
    end
  end

  test "refresh token grant rejects invalid token" do
    post api_v1_auth_token_url, params: {
      grant_type: "refresh_token",
      refresh_token: "invalid_token"
    }

    assert_response :unauthorized
  end

  test "refresh token grant rejects expired token" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }
    refresh_token = JSON.parse(response.body)["refresh_token"]

    # Expire the token
    DeviceToken.last.update!(expires_at: 1.day.ago)

    post api_v1_auth_token_url, params: {
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }

    assert_response :unauthorized
  end

  # --- Revoke ---

  test "revoke destroys the device token" do
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }
    refresh_token = JSON.parse(response.body)["refresh_token"]

    assert_difference "DeviceToken.count", -1 do
      post api_v1_auth_revoke_url, params: { refresh_token: refresh_token }
    end

    assert_response :success
  end

  test "revoke returns 200 for unknown token" do
    post api_v1_auth_revoke_url, params: { refresh_token: "nonexistent_token" }
    assert_response :success
  end

  # --- Authorization Code Grant ---

  test "authorization code grant exchanges code for tokens" do
    # Create an authorization code directly (simulating the browser flow)
    auth_code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: @code_challenge,
      redirect_uri: "savebutton://auth/callback",
      device_name: "Test Phone",
      device_type: "mobile_android"
    )

    post api_v1_auth_token_url, params: {
      grant_type: "authorization_code",
      code: auth_code.code,
      code_verifier: @code_verifier,
      device_name: "Test Phone",
      device_type: "mobile_android",
      app_version: "1.0.0"
    }

    assert_response :created
    json = JSON.parse(response.body)
    assert json["access_token"].present?
    assert json["refresh_token"].present?
    assert_equal @user.email_address, json["user_email"]
  end

  test "authorization code grant rejects wrong code_verifier" do
    auth_code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: @code_challenge,
      redirect_uri: "savebutton://auth/callback"
    )

    post api_v1_auth_token_url, params: {
      grant_type: "authorization_code",
      code: auth_code.code,
      code_verifier: "wrong_verifier",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "invalid_grant", json["error"]
  end

  test "authorization code grant rejects used code" do
    auth_code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: @code_challenge,
      redirect_uri: "savebutton://auth/callback"
    )
    auth_code.redeem!

    post api_v1_auth_token_url, params: {
      grant_type: "authorization_code",
      code: auth_code.code,
      code_verifier: @code_verifier,
      device_name: "Test Phone",
      device_type: "mobile_android"
    }

    assert_response :bad_request
  end

  test "authorization code grant rejects expired code" do
    auth_code = AuthorizationCode.generate_for(
      user: @user,
      code_challenge: @code_challenge,
      redirect_uri: "savebutton://auth/callback"
    )
    auth_code.update!(expires_at: 1.minute.ago)

    post api_v1_auth_token_url, params: {
      grant_type: "authorization_code",
      code: auth_code.code,
      code_verifier: @code_verifier,
      device_name: "Test Phone",
      device_type: "mobile_android"
    }

    assert_response :bad_request
  end

  # --- Unsupported Grant Type ---

  test "rejects unsupported grant type" do
    post api_v1_auth_token_url, params: { grant_type: "client_credentials" }
    assert_response :bad_request
  end

  # --- Mixed Auth (Bearer token on existing endpoints) ---

  test "bearer token authenticates on existing API endpoints" do
    # Get an access token
    post api_v1_auth_token_url, params: {
      grant_type: "password",
      email: @user.email_address,
      password: "password",
      device_name: "Test Phone",
      device_type: "mobile_android"
    }
    access_token = JSON.parse(response.body)["access_token"]

    # Use it on the handshake endpoint
    get api_v1_handshake_url, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @user.email_address, json["user_email"]
  end

  test "basic auth still works on existing API endpoints" do
    get api_v1_handshake_url, headers: basic_auth_header(@user.email_address, "password")
    assert_response :success
  end

  test "expired bearer token falls back to basic auth challenge" do
    token = JwtService.encode(@user)

    travel 20.minutes do
      get api_v1_handshake_url, headers: { "Authorization" => "Bearer #{token}" }
      assert_response :unauthorized
    end
  end

  private

  def basic_auth_header(email, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(email, password) }
  end
end
