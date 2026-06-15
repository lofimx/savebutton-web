module StripeHandlers
  class SubscriptionUpdated < Base
    def call
      stripe_sub = event.data.object
      subscription = find_subscription(customer_id: stripe_sub.customer)

      if subscription.nil?
        Rails.logger.warn "🟠 WARN: customer.subscription.updated could not resolve user (customer=#{stripe_sub.customer})"
        return
      end

      price_id = stripe_sub.items&.data&.first&.price&.id
      new_tier = price_to_tier(price_id)

      attrs = {
        stripe_subscription_id: stripe_sub.id,
        stripe_status: stripe_sub.status,
        current_period_end: stripe_sub.current_period_end ? Time.zone.at(stripe_sub.current_period_end) : nil
      }
      attrs[:tier] = new_tier if new_tier

      subscription.update!(attrs)
      Rails.logger.info "🔵 INFO: Subscription #{subscription.id} updated (status=#{stripe_sub.status}, tier=#{new_tier})"
    end
  end
end
