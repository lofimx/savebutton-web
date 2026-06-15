# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  bytes_used             :bigint           default(0), not null
#  current_period_end     :datetime
#  grace_period_ends_at   :datetime
#  slop_enabled           :boolean          default(FALSE), not null
#  stripe_status          :string
#  tier                   :integer          default("free"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#  user_id                :uuid             not null
#
# Indexes
#
#  index_subscriptions_on_stripe_customer_id      (stripe_customer_id) UNIQUE WHERE (stripe_customer_id IS NOT NULL)
#  index_subscriptions_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE WHERE (stripe_subscription_id IS NOT NULL)
#  index_subscriptions_on_tier                    (tier)
#  index_subscriptions_on_user_id                 (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @subscription = @user.subscription
  end

  test "auto-creates with free tier when user is created" do
    assert_not_nil @subscription
    assert_equal "free", @subscription.tier
  end

  test "tier predicates" do
    @subscription.update!(tier: :free)
    assert @subscription.free?
    refute @subscription.basic?
    refute @subscription.stripe_backed?

    @subscription.update!(tier: :basic)
    assert @subscription.stripe_backed?

    @subscription.update!(tier: :advanced)
    assert @subscription.stripe_backed?

    @subscription.update!(tier: :friend)
    refute @subscription.stripe_backed?
    assert @subscription.friend?
  end

  test "QUOTAS values per tier" do
    assert_equal 0, Subscription::QUOTAS["free"]
    assert_equal 2.gigabytes, Subscription::QUOTAS["basic"]
    assert_equal 10.gigabytes, Subscription::QUOTAS["advanced"]
    assert_equal Float::INFINITY, Subscription::QUOTAS["friend"]
  end

  test "counts_toward_quota? excludes .url" do
    refute Subscription.counts_toward_quota?("2026-01-01T120000-bookmark.url")
    refute Subscription.counts_toward_quota?("foo.URL")
  end

  test "counts_toward_quota? excludes structural .md suffixes" do
    refute Subscription.counts_toward_quota?("2026-01-01T120000-note.md")
    refute Subscription.counts_toward_quota?("2026-01-01T120000-blurb.md")
    refute Subscription.counts_toward_quota?("2026-01-01T120000-quote.md")
  end

  test "counts_toward_quota? includes other .md and binary" do
    assert Subscription.counts_toward_quota?("2026-01-01T120000-essay.md")
    assert Subscription.counts_toward_quota?("2026-01-01T120000-something.pdf")
    assert Subscription.counts_toward_quota?("2026-01-01T120000-image.png")
  end

  test "single_file_cap_bytes returns 1 MB for structural files" do
    assert_equal 1.megabyte, Subscription.single_file_cap_bytes("2026-01-01T120000-bookmark.url")
    assert_equal 1.megabyte, Subscription.single_file_cap_bytes("2026-01-01T120000-blurb.md")
  end

  test "single_file_cap_bytes returns nil for non-structural files" do
    assert_nil Subscription.single_file_cap_bytes("2026-01-01T120000-essay.md")
    assert_nil Subscription.single_file_cap_bytes("2026-01-01T120000-doc.pdf")
  end

  test "over_quota? at the boundary" do
    @subscription.update!(tier: :basic, bytes_used: 2.gigabytes - 100)
    refute @subscription.over_quota?(99)
    assert @subscription.over_quota?(101)
  end

  test "over_quota? always false for friend" do
    @subscription.update!(tier: :friend, bytes_used: 100.gigabytes)
    refute @subscription.over_quota?(100.gigabytes)
  end

  test "approaching_quota? above and below the 80% threshold" do
    @subscription.update!(tier: :basic)
    quota = 2.gigabytes
    # Smallest bytes_used that satisfies bytes_used * 100 >= quota * 80
    trigger = (quota * 80 + 99) / 100

    @subscription.update!(bytes_used: trigger - 1)
    refute @subscription.approaching_quota?

    @subscription.update!(bytes_used: trigger)
    assert @subscription.approaching_quota?

    @subscription.update!(bytes_used: trigger + 1.megabyte)
    assert @subscription.approaching_quota?
  end

  test "approaching_quota? always false for friend" do
    @subscription.update!(tier: :friend, bytes_used: 100.gigabytes)
    refute @subscription.approaching_quota?
  end

  test "approaching_quota? false for free (zero quota)" do
    @subscription.update!(tier: :free, bytes_used: 0)
    refute @subscription.approaching_quota?
  end

  test "start_grace_period! sets timestamp" do
    assert_nil @subscription.grace_period_ends_at
    @subscription.start_grace_period!
    assert @subscription.grace_period_ends_at > 29.days.from_now
    assert @subscription.grace_period_ends_at < 31.days.from_now
    assert @subscription.in_grace_period?
  end

  test "start_grace_period! is idempotent (does not extend if already in grace)" do
    @subscription.update!(grace_period_ends_at: 5.days.from_now)
    original = @subscription.grace_period_ends_at
    @subscription.start_grace_period!
    assert_equal original, @subscription.reload.grace_period_ends_at
  end

  test "in_grace_period? false when grace expired" do
    @subscription.update!(grace_period_ends_at: 1.day.ago)
    refute @subscription.in_grace_period?
  end

  test "clear_grace_period! nils the timestamp" do
    @subscription.update!(grace_period_ends_at: 5.days.from_now)
    @subscription.clear_grace_period!
    assert_nil @subscription.reload.grace_period_ends_at
  end

  test "record_anga_bytes! increments only for quota-counting files" do
    @subscription.update!(tier: :basic, bytes_used: 0)

    blurb = create(:anga, user: @user, filename: "2026-01-01T120000-blurb.md", file_size: 500)
    @subscription.reload
    assert_equal 0, @subscription.bytes_used, "blurb should not count"

    pdf = create(:anga, user: @user, filename: "2026-01-01T120100-doc.pdf", file_size: 12345)
    @subscription.reload
    assert_equal 12345, @subscription.bytes_used, "pdf should count"
  end

  test "recalculate_bytes_used! recomputes from blobs" do
    @subscription.update!(tier: :basic, bytes_used: 99999)
    create(:anga, user: @user, filename: "2026-01-01T120000-blurb.md", file_size: 500)
    create(:anga, user: @user, filename: "2026-01-01T120100-doc.pdf", file_size: 1000)

    total = @subscription.recalculate_bytes_used!
    assert_equal 1000, total
    assert_equal 1000, @subscription.reload.bytes_used
  end

  test "tier_for_price_id returns nil when credentials are absent" do
    assert_nil Subscription.tier_for_price_id(nil)
    assert_nil Subscription.tier_for_price_id("price_unknown")
  end

  # Backfill for users that predate the subscriptions table.
  test "backfill_missing! creates a friend subscription for users without one" do
    user_without_sub = create(:user)
    user_without_sub.subscription.destroy!
    user_without_sub.reload
    assert_nil user_without_sub.subscription, "guard: precondition is a user with no subscription"

    count = Subscription.backfill_missing!

    assert_equal 1, count
    user_without_sub.reload
    assert_not_nil user_without_sub.subscription
    assert_equal "friend", user_without_sub.subscription.tier
  end

  test "backfill_missing! does not touch users who already have a subscription" do
    user_with_sub = create(:user)
    user_with_sub.subscription.update!(tier: :basic, bytes_used: 12345)

    Subscription.backfill_missing!

    user_with_sub.subscription.reload
    assert_equal "basic", user_with_sub.subscription.tier
    assert_equal 12345, user_with_sub.subscription.bytes_used
  end

  test "backfill_missing! returns the number of subscriptions created" do
    3.times do
      u = create(:user)
      u.subscription.destroy!
    end

    assert_equal 3, Subscription.backfill_missing!
  end

  test "backfill_missing! accepts a default_tier override" do
    user = create(:user)
    user.subscription.destroy!

    Subscription.backfill_missing!(default_tier: :free)

    user.reload
    assert_equal "free", user.subscription.tier
  end
end
