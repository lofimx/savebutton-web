class BillingController < ApplicationController
  before_action :require_subscription
  rate_limit to: 30, within: 1.minute, only: %i[checkout portal]

  # POST /billing/checkout?tier=basic|advanced
  def checkout
    tier = params[:tier].to_s
    unless %w[basic advanced].include?(tier)
      redirect_to pricing_path, alert: "Unknown plan." and return
    end

    session = StripeCheckoutSessionCreator.new(
      Current.user, tier,
      success_url: billing_return_url,
      cancel_url: billing_cancel_url
    ).call
    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue StripeCheckoutSessionCreator::Error => e
    Rails.logger.error "🔴 ERROR: #{e.message}"
    redirect_to account_path, alert: "Billing is not currently configured. Please contact support."
  rescue Stripe::StripeError => e
    Rails.logger.error "🔴 ERROR: Stripe checkout failed for user #{Current.user.id}: #{e.message}"
    redirect_to account_path, alert: "Could not start checkout: #{e.message}"
  end

  # POST /billing/portal
  def portal
    subscription = Current.user.subscription
    if subscription.stripe_customer_id.blank?
      redirect_to account_path, alert: "No billing account found." and return
    end

    portal_session = Stripe::BillingPortal::Session.create(
      customer: subscription.stripe_customer_id,
      return_url: account_url
    )

    Rails.logger.info "🔵 INFO: Stripe portal session created for user #{Current.user.id}"
    redirect_to portal_session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error "🔴 ERROR: Stripe portal failed for user #{Current.user.id}: #{e.message}"
    redirect_to account_path, alert: "Could not open billing portal: #{e.message}"
  end

  # GET /billing/return — Stripe redirects here after Checkout success.
  # The webhook is what actually updates state; this is just UX.
  def return
    redirect_to account_path, notice: "Thanks! Your subscription is being activated. This may take a few seconds."
  end

  # GET /billing/cancel — Stripe redirects here when the user backs out.
  def cancel
    redirect_to pricing_path, notice: "No charge was made."
  end

  private

  def require_subscription
    return if Current.user&.subscription
    redirect_to root_path, alert: "Sign in to manage billing."
  end
end
