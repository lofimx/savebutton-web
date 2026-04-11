module Api
  module V1
    class AuthPagesController < ApplicationController
      allow_unauthenticated_access only: %i[provider register]

      VALID_PROVIDERS = %w[google_oauth2 microsoft_graph apple].freeze

      # GET /api/v1/auth/authorize/:provider
      # Provider-specific login page. Shows a single login button so the user
      # can verify they are on savebutton.com before being redirected to the provider.
      def provider
        provider = params[:provider]
        unless VALID_PROVIDERS.include?(provider)
          return redirect_to new_session_path, alert: "Unknown provider: #{provider}"
        end

        # Always clear any existing browser session so the user sees the
        # provider login page, rather than silently reusing a stale session.
        terminate_session if authenticated?

        unless store_device_auth_params
          return redirect_to new_session_path, alert: "Missing required parameters: code_challenge, redirect_uri"
        end

        @provider = provider
        @provider_name = provider_display_name(provider)
        render layout: "application"
      end

      # GET /api/v1/auth/authorize/register
      # Stores PKCE params then redirects to the registration page.
      # After registration, the user is redirected back to the authorize callback
      # which issues an auth code for the mobile app.
      def register
        # Always show registration, even if already logged in.
        # The new account becomes the session used for the mobile app token.
        # Terminate before storing PKCE params so they aren't lost with the old session.
        terminate_session if authenticated?

        unless store_device_auth_params
          return redirect_to new_session_path, alert: "Missing required parameters: code_challenge, redirect_uri"
        end

        redirect_to new_registration_path
      end

      private

      def store_device_auth_params
        return false if params[:code_challenge].blank? || params[:redirect_uri].blank?

        session[:device_auth] = {
          code_challenge: params[:code_challenge],
          code_challenge_method: params[:code_challenge_method] || "S256",
          redirect_uri: params[:redirect_uri],
          state: params[:state],
          device_name: params[:device_name],
          device_type: params[:device_type],
          identity_provider: params[:provider]
        }

        session[:return_to_after_authenticating] = api_v1_auth_authorize_callback_url
        true
      end

      def provider_display_name(provider)
        case provider
        when "google_oauth2" then "Google"
        when "microsoft_graph" then "Microsoft"
        when "apple" then "Apple"
        else provider.titleize
        end
      end
    end
  end
end
