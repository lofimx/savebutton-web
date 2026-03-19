import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "panel"];

  open(event) {
    const platform = event.currentTarget.dataset.downloadPlatform;
    this.showPanel(platform);
    this.modalTarget.showModal();
  }

  close() {
    this.modalTarget.close();
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  showPanel(platform) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.platform !== platform);
    });
  }
}
