class CreateAuthorizationCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :authorization_codes, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :code, null: false
      t.string :code_challenge, null: false
      t.string :redirect_uri, null: false
      t.string :device_name
      t.string :device_type
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false

      t.timestamps
    end

    add_index :authorization_codes, :code, unique: true
    add_index :authorization_codes, :user_id
    add_foreign_key :authorization_codes, :users
  end
end
