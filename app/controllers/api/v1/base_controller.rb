module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Basic::ControllerMethods

      before_action :authenticate

      private

      def authenticate
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

      def current_user
        @current_user
      end
    end
  end
end
