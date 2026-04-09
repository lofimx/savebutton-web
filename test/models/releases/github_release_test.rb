require "test_helper"
require "minitest/mock"

class Releases::GithubReleaseTest < ActiveSupport::TestCase
  FAKE_GTK_RESPONSE = {
    "assets" => [
      { "name" => "SaveButton-1.0.0-x86_64.dmg", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/SaveButton-1.0.0-x86_64.dmg" },
      { "name" => "SaveButton-1.0.0-arm64.dmg", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/SaveButton-1.0.0-arm64.dmg" },
      { "name" => "savebutton_1.0.0_amd64.deb", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton_1.0.0_amd64.deb" },
      { "name" => "savebutton-1.0.0-1.fc41.x86_64.rpm", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton-1.0.0-1.fc41.x86_64.rpm" },
      { "name" => "org.savebutton.SaveButton.flatpak", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/org.savebutton.SaveButton.flatpak" },
      { "name" => "savebutton_1.0.0_amd64.snap", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton_1.0.0_amd64.snap" },
      { "name" => "savebutton-1.0.0.ebuild", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton-1.0.0.ebuild" },
      { "name" => "savebutton-1.0.0-deps.tar.xz", "browser_download_url" => "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton-1.0.0-deps.tar.xz" }
    ]
  }.freeze

  FAKE_WPF_RESPONSE = {
    "assets" => [
      { "name" => "SaveButton-1.0.0-x64.msi", "browser_download_url" => "https://github.com/lofimx/savebutton-wpf/releases/download/v1.0.0/SaveButton-1.0.0-x64.msi" }
    ]
  }.freeze

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "extracts all expected asset keys from GitHub API responses" do
    stub_github_api do
      assets = Releases::GithubRelease.refresh_cache

      assert_equal "https://github.com/lofimx/savebutton-wpf/releases/download/v1.0.0/SaveButton-1.0.0-x64.msi", assets[:windows_msi]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/SaveButton-1.0.0-x86_64.dmg", assets[:macos_intel]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/SaveButton-1.0.0-arm64.dmg", assets[:macos_apple_silicon]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton_1.0.0_amd64.deb", assets[:linux_deb]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton-1.0.0-1.fc41.x86_64.rpm", assets[:linux_rpm]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/org.savebutton.SaveButton.flatpak", assets[:linux_flatpak]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton_1.0.0_amd64.snap", assets[:linux_snap]
      assert_equal "https://github.com/lofimx/savebutton-gtk/releases/download/v1.0.0/savebutton-1.0.0.ebuild", assets[:linux_ebuild]
      assert_equal Releases::GithubRelease::AUR_URL, assets[:aur]
    end
  end

  test "does not extract deps.tar.xz" do
    stub_github_api do
      assets = Releases::GithubRelease.refresh_cache
      urls = assets.values

      refute urls.any? { |url| url.to_s.include?("deps.tar.xz") }
    end
  end

  test "caches results in Rails.cache" do
    stub_github_api do
      Releases::GithubRelease.refresh_cache
    end

    # Second call should return cached data without hitting the API
    assets = Releases::GithubRelease.assets
    assert_equal "https://github.com/lofimx/savebutton-wpf/releases/download/v1.0.0/SaveButton-1.0.0-x64.msi", assets[:windows_msi]
  end

  test "returns cached data when available" do
    cached = { windows_msi: "https://example.com/cached.msi", aur: Releases::GithubRelease::AUR_URL }
    Rails.cache.write("releases/github/latest_assets", cached, expires_in: 1.hour)

    assets = Releases::GithubRelease.assets
    assert_equal "https://example.com/cached.msi", assets[:windows_msi]
  end

  test "returns partial results on API failure" do
    failure_response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
    failure_response.instance_variable_set(:@read, true)

    Net::HTTP.stub(:get_response, failure_response) do
      assets = Releases::GithubRelease.refresh_cache
      assert_equal Releases::GithubRelease::AUR_URL, assets[:aur]
    end
  end

  test "REPOS maps both macos and linux to savebutton-gtk" do
    repos = Releases::GithubRelease::REPOS
    assert_equal "lofimx/savebutton-gtk", repos[:macos]
    assert_equal "lofimx/savebutton-gtk", repos[:linux]
  end

  test "REPOS maps windows to savebutton-wpf" do
    assert_equal "lofimx/savebutton-wpf", Releases::GithubRelease::REPOS[:windows]
  end

  test "fetches assets from both repos when they share the same path" do
    stub_github_api do
      assets = Releases::GithubRelease.refresh_cache

      # From savebutton-wpf
      assert assets[:windows_msi].include?("savebutton-wpf")
      # From savebutton-gtk
      assert assets[:macos_intel].include?("savebutton-gtk")
      assert assets[:linux_deb].include?("savebutton-gtk")
    end
  end

  test "deduplicates API calls for repos shared across OS keys" do
    call_count = 0
    original_stub = method(:stub_github_api)

    fake_responses = {
      "lofimx/savebutton-wpf" => FAKE_WPF_RESPONSE,
      "lofimx/savebutton-gtk" => FAKE_GTK_RESPONSE
    }

    stubbed = lambda { |uri, _headers = {}|
      repo_key = fake_responses.keys.find { |k| uri.to_s.include?(k) }
      if repo_key
        call_count += 1
        response = Net::HTTPSuccess.new("1.1", "200", "OK")
        response.instance_variable_set(:@read, true)
        response.define_singleton_method(:body) { fake_responses[repo_key].to_json }
        response
      end
    }

    Net::HTTP.stub(:get_response, stubbed) do
      Releases::GithubRelease.refresh_cache
    end

    # savebutton-gtk is referenced by both :macos and :linux, but should only be fetched once
    assert_equal 2, call_count, "Expected exactly 2 API calls (one per unique repo)"
  end

  private

  def stub_github_api(&block)
    original_get_response = Net::HTTP.method(:get_response)

    fake_responses = {
      "lofimx/savebutton-wpf" => FAKE_WPF_RESPONSE,
      "lofimx/savebutton-gtk" => FAKE_GTK_RESPONSE
    }

    stubbed = lambda { |uri, _headers = {}|
      repo_key = fake_responses.keys.find { |k| uri.to_s.include?(k) }
      if repo_key
        response = Net::HTTPSuccess.new("1.1", "200", "OK")
        response.instance_variable_set(:@read, true)
        response.define_singleton_method(:body) { fake_responses[repo_key].to_json }
        response
      else
        original_get_response.call(uri)
      end
    }

    Net::HTTP.stub(:get_response, stubbed, &block)
  end
end
