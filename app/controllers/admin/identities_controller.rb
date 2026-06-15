module Admin
  class IdentitiesController < BaseController
    before_action :set_identity, only: [ :show, :destroy ]

    def index
      @identities = Identity.includes(:user).order(created_at: :desc).limit(200)
    end

    def show
    end

    def destroy
      user_email = @identity.user.email_address
      provider = @identity.provider
      @identity.destroy!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} removed #{provider} identity from #{user_email}"
      redirect_to admin_identities_path, notice: "Identity removed."
    end

    private

    def set_identity
      @identity = Identity.find(params[:id])
    end
  end
end
