module Admin
  class DeviceTokensController < BaseController
    before_action :set_device_token, only: [ :show, :destroy ]

    def index
      @device_tokens = DeviceToken.includes(:user).order(created_at: :desc).limit(200)
    end

    def show
    end

    def destroy
      user_email = @device_token.user.email_address
      device_name = @device_token.device_name
      @device_token.destroy!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} revoked device token '#{device_name}' for #{user_email}"
      redirect_to admin_device_tokens_path, notice: "Device token revoked."
    end

    private

    def set_device_token
      @device_token = DeviceToken.find(params[:id])
    end
  end
end
