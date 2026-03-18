# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  email_address       :string           not null
#  incidental_password :boolean          default(FALSE), not null
#  password_digest     :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
end
