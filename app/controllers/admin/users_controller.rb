module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :destroy, :toggle_friend, :restrict, :unrestrict, :sync_to_stripe, :recalculate_usage ]

    def index
      scope = User.left_joins(:subscription).includes(:subscription)
      if params[:q].present?
        scope = scope.where("email_address ILIKE ?", "%#{params[:q]}%")
      end
      @users = scope.order(created_at: :desc).limit(200)
    end

    def show
      @session_count = @user.sessions.count
      @identity_count = @user.identities.count
      @anga_count = @user.angas.count
      @device_token_count = @user.device_tokens.count
    end

    def destroy
      email = @user.email_address
      @user.destroy!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} deleted user #{email}"
      redirect_to admin_users_path, notice: "User #{email} deleted."
    end

    # Toggle the friend tier on/off. Per the prompt, the only valid target is `free`
    # when toggling out of friend (Stripe-backed users have to go through Stripe).
    def toggle_friend
      sub = @user.subscription
      if sub.friend?
        sub.update!(tier: :free)
        notice = "Removed friend tier from #{@user.email_address}."
      else
        if sub.stripe_backed?
          redirect_to admin_user_path(@user), alert: "User has an active Stripe subscription. Cancel it via Stripe first." and return
        end
        sub.update!(tier: :friend)
        notice = "Granted friend tier to #{@user.email_address}."
      end
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} toggled friend tier on #{@user.email_address}: #{sub.tier}"
      redirect_to admin_user_path(@user), notice: notice
    end

    def restrict
      @user.update!(restricted_at: Time.current)
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} restricted #{@user.email_address}"
      redirect_to admin_user_path(@user), notice: "Account restricted."
    end

    def unrestrict
      @user.update!(restricted_at: nil)
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} unrestricted #{@user.email_address}"
      redirect_to admin_user_path(@user), notice: "Account unrestricted."
    end

    def sync_to_stripe
      sub = @user.subscription
      if sub.stripe_customer_id.blank?
        redirect_to admin_user_path(@user), alert: "No Stripe customer to sync." and return
      end
      sub.sync_from_stripe!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} synced #{@user.email_address} from Stripe"
      redirect_to admin_user_path(@user), notice: "Synced from Stripe."
    rescue Stripe::StripeError => e
      redirect_to admin_user_path(@user), alert: "Stripe sync failed: #{e.message}"
    end

    def recalculate_usage
      total = @user.subscription.recalculate_bytes_used!
      Rails.logger.info "🔵 INFO: Staff #{Current.user.email_address} recalculated usage for #{@user.email_address}: #{total} bytes"
      redirect_to admin_user_path(@user), notice: "Usage recalculated: #{number_to_human_size(total)}."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def number_to_human_size(bytes)
      view_context.number_to_human_size(bytes)
    end
  end
end
