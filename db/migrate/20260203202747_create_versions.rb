# This migration creates the `versions` table for the PaperTrail Version class.
# All other migrations PT provides are optional.
class CreateVersions < ActiveRecord::Migration[8.1]
  # The largest text column available in all supported RDBMS is
  # 1024^3 - 1 bytes, roughly one gibibyte.  We specify a size
  # so that MySQL will use `longtext` instead of `text`.  Otherwise,
  # when serializing very large objects, `text` might not be big enough.
  TEXT_BYTES = 1_073_741_823

  def change
    create_table :versions, id: :uuid do |t|
      t.string   :whodunnit
      t.datetime :created_at
      t.string   :item_id,   null: false
      t.string   :item_type, null: false
      t.string   :event,     null: false
      t.text     :object, limit: TEXT_BYTES
    end
    add_index :versions, %i[item_type item_id]
  end
end
