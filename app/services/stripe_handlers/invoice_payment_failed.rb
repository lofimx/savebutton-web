module StripeHandlers
  class InvoicePaymentFailed < Base
    def call
      invoice = event.data.object
      subscription = find_subscription(customer_id: invoice.customer)

      if subscription.nil?
        Rails.logger.warn "🟠 WARN: invoice.payment_failed could not resolve user (customer=#{invoice.customer})"
        return
      end

      subscription.update!(stripe_status: "past_due")
      subscription.start_grace_period!
      Rails.logger.info "🔵 INFO: Subscription #{subscription.id} payment failed, marked past_due, grace started"
    end
  end
end
