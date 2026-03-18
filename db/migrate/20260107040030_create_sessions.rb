class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :sessions, :user_id
    add_foreign_key :sessions, :users
  end
end
