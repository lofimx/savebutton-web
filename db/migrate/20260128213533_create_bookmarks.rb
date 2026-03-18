class CreateBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmarks, id: :uuid do |t|
      t.uuid :anga_id, null: false
      t.string :url
      t.datetime :cached_at

      t.timestamps
    end

    add_index :bookmarks, :anga_id
    add_foreign_key :bookmarks, :angas
  end
end
