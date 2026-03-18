require "test_helper"

class RefreshGithubReleasesJobTest < ActiveJob::TestCase
  test "calls Releases::GithubRelease.refresh_cache" do
    called = false
    Releases::GithubRelease.stub(:refresh_cache, -> { called = true }) do
      RefreshGithubReleasesJob.perform_now
    end

    assert called, "Expected refresh_cache to be called"
  end
end
