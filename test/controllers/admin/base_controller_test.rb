require "test_helper"

class Admin::BaseControllerTest < ActionDispatch::IntegrationTest
  test "non-staff user gets 404 from admin root" do
    user = create(:user)
    sign_in_as(user)
    get admin_root_path
    assert_response :not_found
  end

  test "non-staff user gets 404 from admin users index" do
    user = create(:user)
    sign_in_as(user)
    get admin_users_path
    assert_response :not_found
  end

  test "logged-out user is redirected to sign in" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "staff user reaches admin users index" do
    staff = create(:user, :staff)
    sign_in_as(staff)
    get admin_users_path
    assert_response :success
  end

  test "staff user reaches a specific user detail page" do
    staff = create(:user, :staff)
    other = create(:user)
    sign_in_as(staff)
    get admin_user_path(other)
    assert_response :success
  end
end
