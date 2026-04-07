require "test_helper"

class Platform::AppRegistryTest < ActiveSupport::TestCase
  test "extension_for returns data for known browser" do
    ext = Platform::AppRegistry.extension_for(:chrome)
    assert_equal "Chrome", ext[:name]
    assert ext[:icon].present?
    assert ext[:url].present?
  end

  test "extension_for returns nil for unknown browser" do
    assert_nil Platform::AppRegistry.extension_for(:unknown)
  end

  test "desktop_for returns data for known os" do
    app = Platform::AppRegistry.desktop_for(:windows)
    assert_equal "Windows", app[:name]
    assert_equal "windows", app[:platform]
  end

  test "desktop_for returns nil for mobile os" do
    assert_nil Platform::AppRegistry.desktop_for(:ios)
    assert_nil Platform::AppRegistry.desktop_for(:android)
  end

  test "mobile_for returns data for ios" do
    app = Platform::AppRegistry.mobile_for(:ios)
    assert_equal "App Store", app[:name]
    assert app[:url].present?
  end

  test "mobile_for returns data for android" do
    app = Platform::AppRegistry.mobile_for(:android)
    assert_equal "Google Play", app[:name]
    assert app[:url].present?
  end

  test "mobile_for returns nil for desktop os" do
    assert_nil Platform::AppRegistry.mobile_for(:windows)
  end

  test "all_extensions returns all browser entries" do
    exts = Platform::AppRegistry.all_extensions
    assert_equal 8, exts.size
    assert exts.key?(:chrome)
    assert exts.key?(:firefox)
    assert exts.key?(:safari)
    assert exts.key?(:vivaldi)
  end

  test "all_desktop_apps returns all desktop entries" do
    apps = Platform::AppRegistry.all_desktop_apps
    assert_equal 3, apps.size
    assert apps.key?(:windows)
    assert apps.key?(:macos)
    assert apps.key?(:linux)
  end

  test "all_mobile_apps returns all mobile entries" do
    apps = Platform::AppRegistry.all_mobile_apps
    assert_equal 2, apps.size
    assert apps.key?(:ios)
    assert apps.key?(:android)
  end
end
