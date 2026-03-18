module Api
  module V1
    class ShareController < BaseController
      before_action :authorize_user_access

      # POST /api/v1/:user_email/share/anga/:filename
      # Returns a JSON document with the public share URL
      def create
        encoded_filename = ERB::Util.url_encode(CGI.unescape(params[:filename]))
        anga = current_user.angas.find_by!(filename: encoded_filename)

        share_url = share_anga_url(user_id: current_user.id, filename: anga.filename)

        Rails.logger.info "🔵 INFO: Share URL generated for anga '#{anga.filename}' by user '#{current_user.email_address}'"

        render json: { share_url: share_url }
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      private

      def authorize_user_access
        unless current_user.email_address == params[:user_email].downcase.strip
          head :forbidden
        end
      end
    end
  end
end
