module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Basic::ControllerMethods

      before_action :authenticate

      private

      def authenticate
        # Try Bearer token (JWT) first, fall back to HTTP Basic Auth
        authenticate_with_bearer_token || authenticate_with_basic_auth
      end

      def authenticate_with_bearer_token
        token = extract_bearer_token
        return false unless token

        begin
          payload = JwtService.decode(token)
          @current_user = User.find_by(id: payload["user_id"])
          @current_user.present?
        rescue JwtService::DecodeError => e
          Rails.logger.debug "Auth: JWT decode failed: #{e.message}"
          false
        end
      end

      def authenticate_with_basic_auth
        authenticate_or_request_with_http_basic do |email, password|
          user = User.find_by(email_address: email.downcase.strip)
          if user&.authenticate(password)
            @current_user = user
            true
          else
            false
          end
        end
      end

      def extract_bearer_token
        header = request.headers["Authorization"]
        return nil unless header&.start_with?("Bearer ")

        header.split(" ", 2).last
      end

      def current_user
        @current_user
      end
    end
  end
end
