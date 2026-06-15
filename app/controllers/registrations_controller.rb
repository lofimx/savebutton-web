class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  VALID_PENDING_TIERS = %w[basic advanced].freeze

  def new
    capture_pending_tier
    @user = User.new
  end

  def create
    capture_pending_tier
    @user = User.new(user_params)
    @user.password_confirmation_required = true

    if @user.save
      start_new_session_for @user
      pending_tier = session.delete(:pending_tier)

      if VALID_PENDING_TIERS.include?(pending_tier.to_s)
        redirect_to_stripe_checkout(pending_tier)
      else
        redirect_to after_authentication_url, notice: "Welcome! Your account has been created."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end

  def capture_pending_tier
    tier = params[:pending_tier].to_s
    if VALID_PENDING_TIERS.include?(tier)
      session[:pending_tier] = tier
    end
  end

  def redirect_to_stripe_checkout(tier)
    session = StripeCheckoutSessionCreator.new(
      @user, tier,
      success_url: billing_return_url,
      cancel_url: billing_cancel_url
    ).call
    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue StripeCheckoutSessionCreator::Error, Stripe::StripeError => e
    Rails.logger.error "🔴 ERROR: Post-signup Stripe checkout failed for user #{@user.id}: #{e.message}"
    redirect_to account_path, notice: "Welcome! Your account has been created.", alert: "Billing checkout could not be started: #{e.message}"
  end
end
