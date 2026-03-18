class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words, id: :uuid do |t|
      t.uuid :anga_id, null: false
      t.string :source_type, null: false
      t.datetime :extracted_at
      t.text :extract_error

      t.timestamps
    end

    add_index :words, :anga_id, unique: true
    add_foreign_key :words, :angas
  end
end
