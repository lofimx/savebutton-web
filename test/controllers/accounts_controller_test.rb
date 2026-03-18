require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = create(:user) }

  test "show requires authentication" do
    get account_path
    assert_redirected_to new_session_path
  end

  test "show when authenticated" do
    sign_in_as(@user)
    get account_path
    assert_response :success
  end

  test "update email address" do
    sign_in_as(@user)
    patch account_path, params: { email_address: "newemail@example.com" }

    assert_redirected_to account_path
    @user.reload
    assert_equal "newemail@example.com", @user.email_address
  end

  test "update password with valid current password" do
    sign_in_as(@user)
    patch account_path, params: {
      current_password: "password",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to account_path
    @user.reload
    assert @user.authenticate("newpassword123")
  end

  test "update password fails without current password" do
    sign_in_as(@user)
    patch account_path, params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to account_path
    assert_equal "Current password is required.", flash[:alert]
  end

  test "update password fails with wrong current password" do
    sign_in_as(@user)
    patch account_path, params: {
      current_password: "wrongpassword",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to account_path
    assert_equal "Current password is incorrect.", flash[:alert]
  end

  test "update password fails when passwords do not match" do
    sign_in_as(@user)
    patch account_path, params: {
      current_password: "password",
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }

    assert_redirected_to account_path
    assert flash[:alert].present?
  end
end
