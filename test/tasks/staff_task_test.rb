require "test_helper"
require "rake"

class StaffTaskTest < ActiveSupport::TestCase
  setup do
    @rake = Rake::Application.new
    Rake.application = @rake
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/staff.rake")
  end

  teardown do
    Rake.application = nil
  end

  test "promote sets role to staff" do
    user = create(:user, email_address: "promote-me@example.com")
    assert_equal "user", user.role

    capture_io { Rake::Task["kaya:staff:promote"].invoke("promote-me@example.com") }

    assert_equal "staff", user.reload.role
  end

  test "promote is idempotent for already-staff users" do
    user = create(:user, :staff, email_address: "already-staff@example.com")
    capture_io { Rake::Task["kaya:staff:promote"].invoke("already-staff@example.com") }
    assert_equal "staff", user.reload.role
  end

  test "promote normalizes email" do
    user = create(:user, email_address: "test@example.com")
    capture_io { Rake::Task["kaya:staff:promote"].invoke("  TEST@Example.com  ") }
    assert_equal "staff", user.reload.role
  end

  test "promote exits with error for unknown email" do
    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["kaya:staff:promote"].invoke("nobody@example.com") }
    end
    assert_equal 1, error.status
  end

  test "promote exits with error when email is missing" do
    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["kaya:staff:promote"].invoke }
    end
    assert_equal 1, error.status
  end

  test "demote sets role back to user" do
    user = create(:user, :staff, email_address: "demote-me@example.com")
    @rake.tasks.find { |t| t.name == "kaya:staff:promote" } # ensure both tasks loaded
    Rake::Task["kaya:staff:demote"].reenable
    capture_io { Rake::Task["kaya:staff:demote"].invoke("demote-me@example.com") }
    assert_equal "user", user.reload.role
  end

  test "demote exits with error for unknown email" do
    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["kaya:staff:demote"].invoke("nobody@example.com") }
    end
    assert_equal 1, error.status
  end
end
