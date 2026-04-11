class CreateDeviceTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :device_tokens, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :device_name, null: false
      t.string :device_type, null: false
      t.string :app_version
      t.string :refresh_token_digest, null: false
      t.datetime :last_used_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :device_tokens, :user_id
    add_index :device_tokens, :refresh_token_digest, unique: true
    add_foreign_key :device_tokens, :users
  end
end
