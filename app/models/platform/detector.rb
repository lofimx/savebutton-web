module Platform
  class Detector
    BROWSER_MAP = {
      "Chrome" => :chrome,
      "Chrome Mobile" => :chrome,
      "Chrome Mobile iOS" => :chrome,
      "Chromium" => :chromium,
      "Firefox" => :firefox,
      "Firefox Mobile" => :firefox,
      "Firefox Mobile iOS" => :firefox,
      "Microsoft Edge" => :edge,
      "Edge Mobile" => :edge,
      "Safari" => :safari,
      "Mobile Safari" => :safari,
      "Vivaldi" => :vivaldi,
      "Brave" => :brave,
      "Opera" => :chromium,
      "Opera Mobile" => :chromium,
      "Arc" => :chromium
    }.freeze

    CHROMIUM_FAMILY = %i[chrome chromium].freeze

    OS_MAP = {
      "Windows" => :windows,
      "Mac" => :macos,
      "GNU/Linux" => :linux,
      "Ubuntu" => :linux,
      "Fedora" => :linux,
      "Android" => :android,
      "iOS" => :ios
    }.freeze

    Result = Struct.new(:browser, :os, :chromium_based?, keyword_init: true)

    def self.detect(user_agent)
      new(user_agent).detect
    end

    def initialize(user_agent)
      @client = DeviceDetector.new(user_agent.to_s)
    end

    def detect
      browser = resolve_browser
      os = resolve_os

      Rails.logger.debug("🟢 Platform::Detector — browser=#{browser} os=#{os} ua_name=#{@client.name.inspect}")

      Result.new(
        browser: browser,
        os: os,
        "chromium_based?": CHROMIUM_FAMILY.include?(browser)
      )
    end

    private

    def resolve_browser
      name = @client.name
      return :unknown if name.nil?

      BROWSER_MAP[name] || (chromium_engine? ? :chromium : :unknown)
    end

    def resolve_os
      os_name = @client.os_name
      return :unknown if os_name.nil?

      OS_MAP[os_name] || :unknown
    end

    def chromium_engine?
      @client.send(:user_agent)&.include?("Chrome/")
    end
  end
end
