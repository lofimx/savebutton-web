module StripeHandlers
  class Base
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def call
      raise NotImplementedError
    end

    private

    # Locate the Subscription record either by the Stripe customer ID on the
    # event payload or by client_reference_id (Checkout sessions). Returns nil
    # if neither resolves — the handler should log and return.
    def find_subscription(customer_id: nil, client_reference_id: nil)
      if customer_id.present?
        sub = Subscription.find_by(stripe_customer_id: customer_id)
        return sub if sub
      end

      if client_reference_id.present?
        user = User.find_by(id: client_reference_id)
        return user.subscription if user
      end

      nil
    end

    def price_to_tier(price_id)
      Subscription.tier_for_price_id(price_id)
    end
  end
end
