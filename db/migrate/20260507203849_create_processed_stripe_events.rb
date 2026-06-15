class CreateProcessedStripeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_stripe_events, id: :uuid do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.datetime :processed_at, null: false

      t.timestamps
    end

    add_index :processed_stripe_events, :event_id, unique: true
  end
end
