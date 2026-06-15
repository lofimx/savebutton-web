module StripeHandlers
  class SubscriptionDeleted < Base
    def call
      stripe_sub = event.data.object
      subscription = find_subscription(customer_id: stripe_sub.customer)

      if subscription.nil?
        Rails.logger.warn "🟠 WARN: customer.subscription.deleted could not resolve user (customer=#{stripe_sub.customer})"
        return
      end

      subscription.update!(
        tier: :free,
        stripe_subscription_id: nil,
        stripe_status: stripe_sub.status,
        current_period_end: stripe_sub.current_period_end ? Time.zone.at(stripe_sub.current_period_end) : nil
      )

      # If existing usage exceeds the free tier's allowance (which is 0), enter grace.
      subscription.start_grace_period! if subscription.bytes_used > Subscription::QUOTAS["free"]
      Rails.logger.info "🔵 INFO: Subscription #{subscription.id} canceled, downgraded to free"
    end
  end
end
