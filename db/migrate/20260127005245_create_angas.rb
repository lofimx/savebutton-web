class CreateAngas < ActiveRecord::Migration[8.1]
  def change
    create_table :angas, id: :uuid do |t|
      t.string :filename, null: false
      t.uuid :user_id, null: false

      t.timestamps
    end

    add_index :angas, :user_id
    add_index :angas, [ :user_id, :filename ], unique: true
    add_foreign_key :angas, :users
  end
end
