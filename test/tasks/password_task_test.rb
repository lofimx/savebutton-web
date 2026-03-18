require "test_helper"
require "rake"

class PasswordTaskTest < ActiveSupport::TestCase
  setup do
    @rake = Rake::Application.new
    Rake.application = @rake
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/password.rake")

    @user = create(:user, email_address: "reset-me@example.com", password: "oldpassword1")
    @original_digest = @user.password_digest
  end

  teardown do
    Rake.application = nil
  end

  test "resets password and prints new password to stdout" do
    ENV["EMAIL"] = "reset-me@example.com"

    output = capture_io { Rake::Task["kaya:password:reset"].invoke }.first

    new_password = output.strip
    assert_equal 32, new_password.length, "Generated password should be 32 hex characters"
    assert_match(/\A[0-9a-f]+\z/, new_password, "Generated password should be hex")

    @user.reload
    assert_not_equal @original_digest, @user.password_digest, "Password digest should have changed"
    assert @user.authenticate(new_password), "User should authenticate with the new password"
    assert_equal false, @user.incidental_password, "incidental_password should be false"
  ensure
    ENV.delete("EMAIL")
  end

  test "destroys existing sessions on reset" do
    create(:session, user: @user)
    assert_equal 1, @user.sessions.count

    ENV["EMAIL"] = "reset-me@example.com"

    capture_io { Rake::Task["kaya:password:reset"].invoke }

    assert_equal 0, @user.sessions.reload.count, "All sessions should be destroyed"
  ensure
    ENV.delete("EMAIL")
  end

  test "normalizes email before lookup" do
    ENV["EMAIL"] = "  RESET-ME@Example.com  "

    output = capture_io { Rake::Task["kaya:password:reset"].invoke }.first

    assert_match(/\A[0-9a-f]{32}\n\z/, output, "Should find user with non-normalized email")
  ensure
    ENV.delete("EMAIL")
  end

  test "exits with error when EMAIL is missing" do
    ENV.delete("EMAIL")

    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["kaya:password:reset"].invoke }
    end

    assert_equal 1, error.status
  end

  test "exits with error when user is not found" do
    ENV["EMAIL"] = "nobody@example.com"

    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["kaya:password:reset"].invoke }
    end

    assert_equal 1, error.status
  ensure
    ENV.delete("EMAIL")
  end
end
