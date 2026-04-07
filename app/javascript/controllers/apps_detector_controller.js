import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["expanded", "expandButton", "browserIcon", "browserName"];
  static values = { chromiumBased: Boolean };

  connect() {
    if (this.chromiumBasedValue) {
      this.refineChromiumBrowser();
    }
  }

  toggle() {
    this.expandedTarget.classList.toggle("hidden");

    const isHidden = this.expandedTarget.classList.contains("hidden");
    this.expandButtonTarget.textContent = isHidden ? "See all apps" : "Show fewer";
  }

  async refineChromiumBrowser() {
    try {
      // Brave has a proprietary API
      if (navigator.brave && (await navigator.brave.isBrave())) {
        this.setBrowser("Brave", "/icons/browsers/brave.png");
        return;
      }
    } catch (e) {
      // Brave detection unavailable
    }

    // Use Client Hints to distinguish Chromium from Chrome.
    // Chrome sends "Google Chrome" + "Chromium"; Chromium sends only "Chromium".
    // Masked forks (Vivaldi, Arc) spoof "Google Chrome" so they fall through
    // to Chrome — acceptable since the extension installs from the same store.
    if (navigator.userAgentData && navigator.userAgentData.brands) {
      const brands = navigator.userAgentData.brands.map((b) => b.brand);
      const hasGoogleChrome = brands.some((b) => b === "Google Chrome");
      const hasChromium = brands.some((b) => b === "Chromium");

      if (hasChromium && !hasGoogleChrome) {
        this.setBrowser("Chromium", "/icons/browsers/chromium.png");
      }
    }
  }

  setBrowser(name, icon) {
    if (this.hasBrowserIconTarget) {
      this.browserIconTarget.src = icon;
      this.browserIconTarget.alt = name;
    }
    if (this.hasBrowserNameTarget) {
      this.browserNameTarget.textContent = name;
    }
  }
}
