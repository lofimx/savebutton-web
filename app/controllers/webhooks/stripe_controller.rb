module Webhooks
  class StripeController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    HANDLERS = {
      "checkout.session.completed" => StripeHandlers::CheckoutSessionCompleted,
      "customer.subscription.updated" => StripeHandlers::SubscriptionUpdated,
      "customer.subscription.deleted" => StripeHandlers::SubscriptionDeleted,
      "invoice.payment_failed" => StripeHandlers::InvoicePaymentFailed
    }.freeze

    def create
      payload = request.raw_post
      signature = request.headers["Stripe-Signature"]
      secret = Rails.application.credentials.dig(:stripe, :webhook_signing_secret)

      if secret.blank?
        Rails.logger.error "🔴 ERROR: Stripe webhook signing secret missing in credentials"
        head :service_unavailable
        return
      end

      begin
        event = Stripe::Webhook.construct_event(payload, signature, secret)
      rescue JSON::ParserError, Stripe::SignatureVerificationError => e
        Rails.logger.warn "🟠 WARN: Stripe webhook rejected: #{e.message}"
        head :bad_request
        return
      end

      # Idempotency: insert into processed_stripe_events. If duplicate, swallow and 200.
      begin
        ProcessedStripeEvent.record!(event.id, event.type)
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.info "🔵 INFO: Stripe event #{event.id} already processed, skipping"
        head :ok
        return
      end

      handler = HANDLERS[event.type]
      if handler
        handler.new(event).call
        Rails.logger.info "🔵 INFO: Stripe event #{event.type} (#{event.id}) processed"
      else
        Rails.logger.info "🔵 INFO: Stripe event #{event.type} (#{event.id}) ignored (no handler)"
      end

      head :ok
    rescue => e
      Rails.logger.error "🔴 ERROR: Stripe webhook handler failed for #{event&.id}: #{e.message}"
      raise
    end
  end
end
