module Api
  module V1
    class HandshakeController < BaseController
      def show
        render json: {
          user_email: current_user.email_address,
          anga_endpoint: api_v1_user_anga_index_url(user_email: current_user.email_address)
        }
      end
    end
  end
end
