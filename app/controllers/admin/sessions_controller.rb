module Admin
  class SessionsController < BaseController
    before_action :set_session, only: [ :show, :destroy ]

    def index
      @sessions = Session.includes(:user).order(created_at: :desc).limit(200)
    end

    def show
    end

    def destroy
      user_email = @session.user.email_address
      @session.destroy!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} terminated session for #{user_email}"
      redirect_to admin_sessions_path, notice: "Session terminated."
    end

    private

    def set_session
      @session = Session.find(params[:id])
    end
  end
end
