module Platform
  class AppRegistry
    BROWSER_EXTENSIONS = {
      chrome:   { name: "Chrome",   icon: "/icons/browsers/chrome.png",   url: "https://chromewebstore.google.com/detail/save-button/eeoleaffndkjkgbdhaojcgehcklfihid" },
      firefox:  { name: "Firefox",  icon: "/icons/browsers/firefox.png",  url: "https://addons.mozilla.org/en-US/firefox/addon/save-button/" },
      edge:     { name: "Edge",     icon: "/icons/browsers/edge.png",     url: "https://microsoftedge.microsoft.com/addons/detail/save-button/ldcpchibphbafmclockfeoiffafjdekj" },
      safari:   { name: "Safari",   icon: "/icons/browsers/safari.png",   url: "https://apps.apple.com/app/save-button-for-safari/id6759535767" },
      chromium: { name: "Chromium", icon: "/icons/browsers/chromium.png", url: "https://chromewebstore.google.com/detail/save-button/eeoleaffndkjkgbdhaojcgehcklfihid" },
      brave:    { name: "Brave",    icon: "/icons/browsers/brave.png",    url: "https://chromewebstore.google.com/detail/save-button/eeoleaffndkjkgbdhaojcgehcklfihid" },
      vivaldi:  { name: "Vivaldi",  icon: "/icons/browsers/vivaldi.png",  url: "https://chromewebstore.google.com/detail/save-button/eeoleaffndkjkgbdhaojcgehcklfihid" },
      arc:      { name: "Arc",      icon: "/icons/browsers/arc.png",      url: "https://chromewebstore.google.com/detail/save-button/eeoleaffndkjkgbdhaojcgehcklfihid" }
    }.freeze

    DESKTOP_APPS = {
      windows: { name: "Windows", icon: "/icons/platforms/windows.png", platform: "windows" },
      macos:   { name: "macOS",   icon: "/icons/platforms/macos.png",   platform: "macos" },
      linux:   { name: "Linux",   icon: "/icons/platforms/linux.png",   platform: "linux" }
    }.freeze

    MOBILE_APPS = {
      ios:     { name: "App Store",   icon: "/icons/platforms/app-store.svg",  url: "https://apps.apple.com/app/save-button-app/id6758891680" },
      android: { name: "Google Play", icon: "/icons/platforms/play-store.svg", url: "https://play.google.com/store/apps/details?id=org.savebutton.app" }
    }.freeze

    def self.extension_for(browser)
      BROWSER_EXTENSIONS[browser]
    end

    def self.desktop_for(os)
      DESKTOP_APPS[os]
    end

    def self.mobile_for(os)
      MOBILE_APPS[os]
    end

    def self.all_extensions
      BROWSER_EXTENSIONS
    end

    def self.all_desktop_apps
      DESKTOP_APPS
    end

    def self.all_mobile_apps
      MOBILE_APPS
    end
  end
end
