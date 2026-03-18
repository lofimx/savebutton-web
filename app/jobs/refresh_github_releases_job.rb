class RefreshGithubReleasesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("🔵 RefreshGithubReleasesJob — refreshing GitHub release cache")
    Releases::GithubRelease.refresh_cache
  end
end
