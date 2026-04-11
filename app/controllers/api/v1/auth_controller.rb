module Api
  module V1
    class AuthController < ActionController::API
      include ActionController::Cookies
      include Authentication

      # The authorize endpoint is browser-facing (redirects to login page).
      # The token and revoke endpoints are API-facing (JSON responses).
      allow_unauthenticated_access only: %i[authorize authorize_callback token revoke]

      # GET /api/v1/auth/authorize
      # Initiates the PKCE authorization flow. The client opens this URL in a browser.
      # Stores PKCE params in session and redirects to the login page.
      def authorize
        terminate_session if authenticated?

        unless store_device_auth_params
          return redirect_to new_session_path, alert: "Missing required parameters: code_challenge, redirect_uri"
        end

        redirect_to new_session_path
      end


      # GET /api/v1/auth/authorize/callback
      # Called after successful login. Generates an authorization code and redirects
      # back to the client's redirect_uri.
      def authorize_callback
        device_auth = session.delete(:device_auth)
        unless device_auth
          return redirect_to root_path, alert: "No pending device authorization."
        end

        unless authenticated?
          return redirect_to new_session_path, alert: "Authentication required."
        end

        # Identity provider is stored in device_auth (from the authorize URL path).
        # Identity email comes from the OmniAuth callback session or, as a fallback,
        # from the user's most recent identity matching the provider.
        identity_provider = device_auth["identity_provider"] || session.delete(:identity_provider)
        identity_email = session.delete(:identity_email)

        # If identity_email wasn't in the session (session lost across redirects),
        # look it up from the user's linked identities
        if identity_provider.present? && identity_email.blank?
          identity = Current.user.identities.find_by(provider: identity_provider)
          if identity
            # The Identity model doesn't store the email directly, so we note
            # the provider but can't recover the email from here alone.
            Rails.logger.warn "Auth: identity_email missing from session for provider=#{identity_provider}, user=#{Current.user.id}"
          end
        end

        Rails.logger.info "Auth: authorize_callback — identity_provider=#{identity_provider.inspect}, identity_email=#{identity_email.inspect}"

        auth_code = AuthorizationCode.generate_for(
          user: Current.user,
          code_challenge: device_auth["code_challenge"],
          redirect_uri: device_auth["redirect_uri"],
          device_name: device_auth["device_name"],
          device_type: device_auth["device_type"],
          identity_provider: identity_provider,
          identity_email: identity_email
        )

        redirect_uri = build_callback_uri(
          device_auth["redirect_uri"],
          code: auth_code.code,
          state: device_auth["state"]
        )

        Rails.logger.info "Auth: issued authorization code #{auth_code.id} for user #{Current.user.id}, identity_provider=#{auth_code.identity_provider.inspect}, identity_email=#{auth_code.identity_email.inspect}"
        redirect_to redirect_uri, allow_other_host: true
      end

      # POST /api/v1/auth/token
      # Exchanges credentials for JWT tokens. Supports three grant types:
      #   - authorization_code: PKCE code exchange
      #   - password: direct email/password
      #   - refresh_token: refresh an access token
      def token
        case params[:grant_type]
        when "authorization_code"
          handle_authorization_code_grant
        when "password"
          handle_password_grant
        when "refresh_token"
          handle_refresh_token_grant
        else
          render json: { error: "unsupported_grant_type" }, status: :bad_request
        end
      end

      # POST /api/v1/auth/revoke
      # Revokes a refresh token (deletes the DeviceToken).
      def revoke
        refresh_token = params[:refresh_token]
        if refresh_token.blank?
          return render json: { error: "missing_refresh_token" }, status: :bad_request
        end

        # Find and destroy the device token. Per RFC 7009, revocation always returns 200
        # even if the token was already invalid.
        DeviceToken.active.find_each do |dt|
          if dt.refresh_token_matches?(refresh_token)
            Rails.logger.info "Auth: revoked device token #{dt.id} for user #{dt.user_id}"
            dt.destroy!
            break
          end
        end

        render json: {}, status: :ok
      end

      private

      def handle_authorization_code_grant
        code = params[:code]
        code_verifier = params[:code_verifier]

        if code.blank? || code_verifier.blank?
          return render json: { error: "invalid_request", error_description: "code and code_verifier are required" }, status: :bad_request
        end

        auth_code = AuthorizationCode.find_by(code: code)
        if auth_code.nil? || auth_code.redeemed? || auth_code.expired?
          return render json: { error: "invalid_grant", error_description: "authorization code is invalid or expired" }, status: :bad_request
        end

        unless auth_code.verify_pkce(code_verifier)
          return render json: { error: "invalid_grant", error_description: "PKCE verification failed" }, status: :bad_request
        end

        unless auth_code.redeem!
          return render json: { error: "invalid_grant", error_description: "authorization code already used" }, status: :bad_request
        end

        Rails.logger.info "Auth: exchanging auth code #{auth_code.id} — identity_provider=#{auth_code.identity_provider.inspect}, identity_email=#{auth_code.identity_email.inspect}"

        issue_tokens(
          auth_code.user,
          device_name: params[:device_name] || auth_code.device_name,
          device_type: params[:device_type] || auth_code.device_type,
          app_version: params[:app_version],
          identity_provider: auth_code.identity_provider,
          identity_email: auth_code.identity_email
        )
      end

      def handle_password_grant
        email = params[:email]
        password = params[:password]

        if email.blank? || password.blank?
          return render json: { error: "invalid_request", error_description: "email and password are required" }, status: :bad_request
        end

        user = User.authenticate_by(email_address: email, password: password)
        unless user
          return render json: { error: "invalid_grant", error_description: "invalid email or password" }, status: :unauthorized
        end

        issue_tokens(
          user,
          device_name: params[:device_name] || "Unknown Device",
          device_type: params[:device_type] || "mobile_android",
          app_version: params[:app_version]
        )
      end

      def handle_refresh_token_grant
        refresh_token = params[:refresh_token]
        if refresh_token.blank?
          return render json: { error: "invalid_request", error_description: "refresh_token is required" }, status: :bad_request
        end

        device_token = find_device_token_by_refresh(refresh_token)
        unless device_token
          return render json: { error: "invalid_grant", error_description: "refresh token is invalid or expired" }, status: :unauthorized
        end

        # Slide the expiry window forward
        device_token.touch_usage!

        access_token = JwtService.encode(device_token.user)

        Rails.logger.info "Auth: refreshed access token for device #{device_token.id}, user #{device_token.user_id}"

        render json: {
          access_token: access_token,
          token_type: "Bearer",
          expires_in: JwtService::ACCESS_TOKEN_EXPIRY.to_i
        }
      end

      def issue_tokens(user, device_name:, device_type:, app_version: nil,
                       identity_provider: nil, identity_email: nil)
        device_token = user.device_tokens.build(
          device_name: device_name,
          device_type: device_type,
          app_version: app_version
        )

        refresh_token = device_token.generate_refresh_token!
        device_token.save!

        access_token = JwtService.encode(user)

        Rails.logger.info "Auth: issued tokens for device #{device_token.id}, user #{user.id} (#{device_type}), identity_provider=#{identity_provider.inspect}, identity_email=#{identity_email.inspect}"

        response = {
          access_token: access_token,
          refresh_token: refresh_token,
          token_type: "Bearer",
          expires_in: JwtService::ACCESS_TOKEN_EXPIRY.to_i,
          user_email: user.email_address
        }

        # Include OAuth identity info when the user authenticated via a provider
        response[:identity_provider] = identity_provider if identity_provider.present?
        response[:identity_email] = identity_email if identity_email.present?

        render json: response, status: :created
      end

      def find_device_token_by_refresh(plaintext_token)
        DeviceToken.active.find_each do |dt|
          return dt if dt.refresh_token_matches?(plaintext_token)
        end
        nil
      end

      def build_callback_uri(base_uri, code:, state:)
        uri = URI.parse(base_uri)
        query_params = URI.decode_www_form(uri.query || "")
        query_params << [ "code", code ]
        query_params << [ "state", state ] if state.present?
        uri.query = URI.encode_www_form(query_params)
        uri.to_s
      end

      # Stores PKCE and device params in session. Returns false if required params are missing.
      def store_device_auth_params
        return false if params[:code_challenge].blank? || params[:redirect_uri].blank?

        session[:device_auth] = {
          code_challenge: params[:code_challenge],
          code_challenge_method: params[:code_challenge_method] || "S256",
          redirect_uri: params[:redirect_uri],
          state: params[:state],
          device_name: params[:device_name],
          device_type: params[:device_type]
        }

        session[:return_to_after_authenticating] = api_v1_auth_authorize_callback_url
        true
      end
    end
  end
end
