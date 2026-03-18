class CreateMetas < ActiveRecord::Migration[8.1]
  def change
    create_table :metas, id: :uuid do |t|
      t.string :filename, null: false
      t.string :anga_filename, null: false
      t.uuid :user_id, null: false
      t.uuid :anga_id
      t.boolean :orphan, default: false, null: false

      t.timestamps
    end

    add_index :metas, :user_id
    add_index :metas, [ :user_id, :filename ], unique: true
    add_index :metas, :anga_id
    add_foreign_key :metas, :users
    add_foreign_key :metas, :angas, column: :anga_id, on_delete: :nullify
  end
end
