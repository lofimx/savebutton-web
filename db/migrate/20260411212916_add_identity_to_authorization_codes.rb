class AddIdentityToAuthorizationCodes < ActiveRecord::Migration[8.1]
  def change
    add_column :authorization_codes, :identity_provider, :string
    add_column :authorization_codes, :identity_email, :string
  end
end
