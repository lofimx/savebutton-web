class BackfillSubscriptionsForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    Subscription.backfill_missing!(default_tier: :friend)
  end

  def down
    # No-op: data backfill. Rolling back would mean deleting subscriptions
    # we cannot reliably distinguish from those created by other means.
  end
end
