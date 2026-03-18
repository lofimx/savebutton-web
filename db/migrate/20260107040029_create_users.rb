class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :users, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest
      t.boolean :incidental_password, default: false, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
