require "test_helper"

class EverythingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    delete session_path
    get app_everything_path
    assert_redirected_to new_session_path
  end

  test "index shows empty state when no angas" do
    get app_everything_path
    assert_response :success
    assert_select ".empty-state"
  end

  test "index shows angas in reverse chronological order" do
    create(:anga, user: @user, filename: "2025-06-28T120000-note.md")
    create(:anga, user: @user, filename: "2025-06-29T130000-note.md")

    get app_everything_path
    assert_response :success
    assert_select ".anga-tile", 2
  end

  test "index filters angas by search query" do
    create(:anga, user: @user, filename: "2025-06-28T120000-hello.md")
    create(:anga, user: @user, filename: "2025-06-29T130000-world.md")

    get app_everything_path, params: { q: "hello" }
    assert_response :success
    assert_select ".anga-tile", 1
  end

  test "app root redirects to everything" do
    get "/app"
    assert_redirected_to "/app/everything"
  end

  test "root redirects to everything when signed in" do
    get root_path
    assert_redirected_to app_everything_path
  end
end
