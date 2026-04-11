# JwtService handles encoding and decoding of JWT access tokens.
# Uses HS256 with a server-side secret derived from Rails credentials.
class JwtService
  ACCESS_TOKEN_EXPIRY = 15.minutes

  class DecodeError < StandardError; end

  class << self
    # Encode a JWT access token for the given user.
    # Returns the token string.
    def encode(user)
      payload = {
        user_id: user.id,
        email: user.email_address,
        exp: ACCESS_TOKEN_EXPIRY.from_now.to_i,
        iat: Time.current.to_i,
        jti: SecureRandom.uuid
      }
      JWT.encode(payload, secret_key, "HS256")
    end

    # Decode a JWT access token.
    # Returns the payload hash with string keys.
    # Raises JwtService::DecodeError on any failure (expired, invalid, tampered).
    def decode(token)
      decoded = JWT.decode(token, secret_key, true, {
        algorithm: "HS256",
        verify_expiration: true
      })
      decoded.first
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      raise DecodeError, e.message
    end

    private

    def secret_key
      Rails.application.secret_key_base
    end
  end
end
