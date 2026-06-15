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
class Subscription < ApplicationRecord
  has_paper_trail

  belongs_to :user

  TIERS = { free: 0, basic: 1, advanced: 2, friend: 3 }.freeze
  QUOTAS = {
    "free" => 0,
    "basic" => 2.gigabytes,
    "advanced" => 10.gigabytes,
    "friend" => Float::INFINITY
  }.freeze
  MAX_STRUCTURAL_BYTES = 1.megabyte
  GRACE_PERIOD = 30.days
  APPROACHING_QUOTA_PERCENT = 80
  STRUCTURAL_BLURB_SUFFIXES = %w[-note.md -quote.md -blurb.md].freeze

  enum :tier, TIERS, default: :free

  validates :tier, presence: true
  validates :bytes_used, numericality: { greater_than_or_equal_to: 0 }

  def stripe_backed?
    basic? || advanced?
  end

  def quota_bytes
    QUOTAS.fetch(tier)
  end

  # Returns true when adding a file with this filename should consume the
  # user's GB quota. Bookmarks (.url) and built-in blurbs (-note/-quote/-blurb.md)
  # never count toward the GB quota at any tier; only the 1 MB structural cap applies.
  def self.counts_toward_quota?(filename)
    name = filename.to_s.downcase
    return false if name.end_with?(".url")
    return false if STRUCTURAL_BLURB_SUFFIXES.any? { |suffix| name.end_with?(suffix) }
    true
  end

  # The maximum allowed size for a single file with this filename, regardless
  # of the user's quota. Returns MAX_STRUCTURAL_BYTES for structural files
  # (.url, -note/-quote/-blurb.md). Returns nil for files governed only by GB quota.
  def self.single_file_cap_bytes(filename)
    counts_toward_quota?(filename) ? nil : MAX_STRUCTURAL_BYTES
  end

  def counts_toward_quota?(filename)
    self.class.counts_toward_quota?(filename)
  end

  def single_file_cap_bytes(filename)
    self.class.single_file_cap_bytes(filename)
  end

  def over_quota?(extra_bytes = 0)
    return false if friend?
    bytes_used + extra_bytes > quota_bytes
  end

  def approaching_quota?
    return false if friend?
    return false if quota_bytes.zero?
    bytes_used * 100 >= quota_bytes * APPROACHING_QUOTA_PERCENT
  end

  def in_grace_period?
    grace_period_ends_at.present? && grace_period_ends_at > Time.current
  end

  def start_grace_period!
    return if in_grace_period?
    update!(grace_period_ends_at: Time.current + GRACE_PERIOD)
    Rails.logger.info "🔵 INFO: Grace period started for subscription #{id} (user #{user_id}) ends at #{grace_period_ends_at}"
  end

  def clear_grace_period!
    return if grace_period_ends_at.nil?
    update!(grace_period_ends_at: nil)
    Rails.logger.info "🔵 INFO: Grace period cleared for subscription #{id} (user #{user_id})"
  end

  # Increment the cached bytes_used counter for a newly-created Anga.
  # Only counts toward bytes_used when the file counts toward the GB quota.
  def record_anga_bytes!(anga)
    return unless anga.file.attached?
    return unless counts_toward_quota?(anga.filename)

    with_lock do
      increment!(:bytes_used, anga.file.byte_size)
    end
  end

  # Recompute bytes_used from scratch by summing all of the user's quota-counting
  # anga blobs. Used by the admin "Recalculate usage" button and as a safety valve
  # against drift.
  def recalculate_bytes_used!
    total = user.angas.includes(file_attachment: :blob).sum do |anga|
      next 0 unless anga.file.attached?
      next 0 unless counts_toward_quota?(anga.filename)
      anga.file.byte_size
    end
    update!(bytes_used: total)
    Rails.logger.info "🔵 INFO: Recalculated bytes_used=#{total} for subscription #{id} (user #{user_id})"
    total
  end

  # Pull the latest subscription state from Stripe for users with a stripe_customer_id.
  # Updates tier, stripe_status, current_period_end, stripe_subscription_id from the
  # active subscription on the customer (if any). No-op for free/friend.
  def sync_from_stripe!
    return false if stripe_customer_id.blank?

    subscriptions = Stripe::Subscription.list(customer: stripe_customer_id, status: "all", limit: 10)
    active = subscriptions.data.find { |s| %w[active trialing past_due].include?(s.status) } || subscriptions.data.first

    if active.nil?
      update!(stripe_status: "canceled", stripe_subscription_id: nil)
      apply_tier_for_status!("canceled")
      return true
    end

    price_id = active.items.data.first&.price&.id
    new_tier = price_to_tier(price_id) || tier
    update!(
      stripe_subscription_id: active.id,
      stripe_status: active.status,
      current_period_end: active.current_period_end ? Time.zone.at(active.current_period_end) : nil,
      tier: new_tier
    )
    Rails.logger.info "🔵 INFO: Synced subscription #{id} from Stripe (status=#{active.status}, tier=#{new_tier})"
    true
  rescue Stripe::StripeError => e
    Rails.logger.error "🔴 ERROR: Stripe sync failed for subscription #{id}: #{e.message}"
    raise
  end

  # Create a Subscription for every existing User that lacks one. Used by the
  # data migration that backfills users predating the subscriptions table.
  # Idempotent — re-running creates nothing.
  def self.backfill_missing!(default_tier: :friend)
    count = 0
    User.where.missing(:subscription).find_each do |user|
      user.create_subscription!(tier: default_tier)
      count += 1
    end
    Rails.logger.info "🔵 INFO: Backfilled #{count} subscriptions with tier=#{default_tier}"
    count
  end

  # Map a Stripe Price ID to a tier symbol. Reads from credentials.
  def self.tier_for_price_id(price_id)
    return nil if price_id.blank?
    creds = Rails.application.credentials.stripe
    return nil if creds.blank?
    case price_id
    when creds[:basic_price_id] then :basic
    when creds[:advanced_price_id] then :advanced
    end
  end

  def price_to_tier(price_id)
    self.class.tier_for_price_id(price_id)
  end

  def apply_tier_for_status!(status)
    if status == "canceled"
      update!(tier: :free, stripe_subscription_id: nil)
      start_grace_period! if bytes_used > QUOTAS["free"]
    end
  end
end
