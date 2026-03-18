import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fallback"];

  connect() {
    const img = this.element.querySelector("img");
    if (img && img.complete && img.naturalWidth === 0) {
      this.showDefault();
    }
  }

  showDefault() {
    if (this.hasFallbackTarget) {
      this.element.innerHTML = this.fallbackTarget.innerHTML;
    }
  }
}
