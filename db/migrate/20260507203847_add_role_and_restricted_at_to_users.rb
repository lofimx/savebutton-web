class AddRoleAndRestrictedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, default: "user", null: false
    add_column :users, :restricted_at, :datetime
    add_index :users, :role
  end
end
