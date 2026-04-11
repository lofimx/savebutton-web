require "test_helper"

class JwtServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "encode returns a JWT string" do
    token = JwtService.encode(@user)
    assert token.is_a?(String)
    assert_equal 3, token.split(".").length
  end

  test "decode returns payload with user_id and email" do
    token = JwtService.encode(@user)
    payload = JwtService.decode(token)

    assert_equal @user.id, payload["user_id"]
    assert_equal @user.email_address, payload["email"]
  end

  test "decode includes expiration" do
    token = JwtService.encode(@user)
    payload = JwtService.decode(token)

    assert payload["exp"].present?
    assert payload["exp"] > Time.current.to_i
  end

  test "decode includes issued_at and jti" do
    token = JwtService.encode(@user)
    payload = JwtService.decode(token)

    assert payload["iat"].present?
    assert payload["jti"].present?
  end

  test "decode raises DecodeError for invalid token" do
    assert_raises JwtService::DecodeError do
      JwtService.decode("invalid.token.here")
    end
  end

  test "decode raises DecodeError for tampered token" do
    token = JwtService.encode(@user)
    # Tamper with the signature
    parts = token.split(".")
    parts[2] = parts[2].reverse
    tampered = parts.join(".")

    assert_raises JwtService::DecodeError do
      JwtService.decode(tampered)
    end
  end

  test "decode raises DecodeError for expired token" do
    token = JwtService.encode(@user)

    # Travel past the expiry
    travel 20.minutes do
      assert_raises JwtService::DecodeError do
        JwtService.decode(token)
      end
    end
  end
end
