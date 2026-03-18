class AddCacheErrorToBookmarks < ActiveRecord::Migration[8.1]
  def change
    add_column :bookmarks, :cache_error, :text
  end
end
