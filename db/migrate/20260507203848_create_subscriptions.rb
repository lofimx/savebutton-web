class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.integer :tier, default: 0, null: false
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :stripe_status
      t.datetime :current_period_end
      t.datetime :grace_period_ends_at
      t.bigint :bytes_used, default: 0, null: false
      t.boolean :slop_enabled, default: false, null: false

      t.timestamps
    end

    add_index :subscriptions, :stripe_customer_id, unique: true, where: "stripe_customer_id IS NOT NULL"
    add_index :subscriptions, :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL"
    add_index :subscriptions, :tier
  end
end
