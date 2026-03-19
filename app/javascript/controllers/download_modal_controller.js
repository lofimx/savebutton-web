import { Controller } from "@hotwired/stimulus";
import * as bootstrap from "bootstrap";

export default class extends Controller {
  static targets = ["modal", "panel"];

  connect() {
    this.bsModal = new bootstrap.Modal(this.modalTarget);
  }

  open(event) {
    const platform = event.currentTarget.dataset.downloadPlatform;
    this.activateTab(platform);
    this.bsModal.show();
  }

  close() {
    this.bsModal.hide();
  }

  activateTab(platform) {
    // Find the tab button for this platform and activate it
    const tabEl = this.modalTarget.querySelector(
      `#${platform}-tab`,
    );
    if (tabEl) {
      const tab = new bootstrap.Tab(tabEl);
      tab.show();
    }
  }
}
