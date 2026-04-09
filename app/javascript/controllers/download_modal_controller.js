import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "panel", "title"];
  static values = { platform: String };

  open(event) {
    const platform = event.currentTarget.dataset.downloadPlatform;
    this.showPanel(platform);
    this.modalTarget.classList.add("active");
    document.body.style.overflow = "hidden";
    this.modalTarget.focus();
  }

  close() {
    this.modalTarget.classList.remove("active");
    document.body.style.overflow = "";
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  showPanel(platform) {
    this.panelTargets.forEach((panel) => {
      const isActive = panel.dataset.platform === platform;
      panel.classList.toggle("hidden", !isActive);
      if (isActive && this.hasTitleTarget) {
        const version = panel.dataset.version;
        this.titleTarget.textContent = version
          ? `Download Save Button v${version}`
          : "Download Save Button";
      }
    });
  }
}
