# == Schema Information
#
# Table name: processed_stripe_events
# Database name: primary
#
#  id           :uuid             not null, primary key
#  event_type   :string           not null
#  processed_at :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  event_id     :string           not null
#
# Indexes
#
#  index_processed_stripe_events_on_event_id  (event_id) UNIQUE
#
class ProcessedStripeEvent < ApplicationRecord
  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :processed_at, presence: true

  def self.record!(event_id, event_type)
    create!(event_id: event_id, event_type: event_type, processed_at: Time.current)
  end
end
