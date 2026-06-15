module StripeHandlers
  class CheckoutSessionCompleted < Base
    def call
      session = event.data.object
      subscription = find_subscription(
        customer_id: session.customer,
        client_reference_id: session.client_reference_id
      )

      if subscription.nil?
        Rails.logger.warn "🟠 WARN: checkout.session.completed could not resolve user (customer=#{session.customer}, ref=#{session.client_reference_id})"
        return
      end

      stripe_subscription = Stripe::Subscription.retrieve(session.subscription) if session.subscription
      price_id = stripe_subscription&.items&.data&.first&.price&.id
      new_tier = price_to_tier(price_id)

      attrs = {
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription
      }
      attrs[:tier] = new_tier if new_tier
      attrs[:stripe_status] = stripe_subscription.status if stripe_subscription
      attrs[:current_period_end] = Time.zone.at(stripe_subscription.current_period_end) if stripe_subscription&.current_period_end

      subscription.update!(attrs)
      subscription.clear_grace_period!
      Rails.logger.info "🔵 INFO: Subscription #{subscription.id} upgraded to #{new_tier} via checkout"
    end
  end
end
