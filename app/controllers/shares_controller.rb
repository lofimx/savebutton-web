class SharesController < ApplicationController
  skip_before_action :require_authentication

  def show
    @user = User.find(params[:user_id])
    encoded_filename = ERB::Util.url_encode(CGI.unescape(params[:filename]))
    @anga = @user.angas.find_by!(filename: encoded_filename)

    if @anga.file.attached?
      send_data @anga.file.download,
                filename: @anga.filename,
                type: @anga.file.content_type,
                disposition: "inline"
    else
      head :not_found
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
