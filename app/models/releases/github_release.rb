module Releases
  class GithubRelease
    CACHE_KEY_PREFIX = "releases/github"
    CACHE_TTL = 2.hours

    REPOS = {
      windows: "lofimx/kaya-wpf",
      macos: "lofimx/kaya-gtk",
      linux: "lofimx/kaya-gtk"
    }.freeze

    # Asset matchers: pattern => key
    ASSET_MATCHERS = {
      /\.msi\z/i => :windows_msi,
      /x86_64\.dmg\z/i => :macos_intel,
      /arm64\.dmg\z/i => :macos_apple_silicon,
      /\.deb\z/i => :linux_deb,
      /\.rpm\z/i => :linux_rpm,
      /\.flatpak\z/i => :linux_flatpak,
      /\.snap\z/i => :linux_snap,
      /\.ebuild\z/i => :linux_ebuild
    }.freeze

    AUR_URL = "https://aur.archlinux.org/packages/savebutton"

    class << self
      def assets
        cached = Rails.cache.read(cache_key)
        return cached if cached

        refresh_cache
      end

      def refresh_cache
        assets = fetch_all_assets
        Rails.cache.write(cache_key, assets, expires_in: CACHE_TTL)
        Rails.logger.info("🔵 Releases::GithubRelease — cached #{assets.size} download assets")
        assets
      end

      private

      def cache_key
        "#{CACHE_KEY_PREFIX}/latest_assets"
      end

      def fetch_all_assets
        unique_repos = REPOS.values.uniq

        repo_assets = unique_repos.reduce({ aur: AUR_URL }) do |result, repo_path|
          result.merge(fetch_assets_for(repo_path))
        end

        repo_assets
      rescue StandardError => e
        Rails.logger.error("🔴 Releases::GithubRelease — failed to fetch releases: #{e.message}")
        { aur: AUR_URL }
      end

      def fetch_assets_for(repo)
        uri = URI("https://api.github.com/repos/#{repo}/releases/latest")
        response = Net::HTTP.get_response(uri, { "Accept" => "application/vnd.github.v3+json",
                                                  "User-Agent" => "KayaServer" })

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("🟠 Releases::GithubRelease — GitHub API returned #{response.code} for #{repo}")
          return {}
        end

        release = JSON.parse(response.body)
        assets = release["assets"] || []

        assets.each_with_object({}) do |asset, matched|
          name = asset["name"]
          url = asset["browser_download_url"]

          ASSET_MATCHERS.each do |pattern, key|
            if name.match?(pattern)
              matched[key] = url
              break
            end
          end
        end
      end
    end
  end
end
