import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];

  search() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      // Use Turbo's fetch to update the frame without affecting focus
      const frame = document.getElementById("anga-results");
      if (frame) {
        const url = new URL(this.element.action);
        url.searchParams.set("q", this.inputTarget.value);
        frame.src = url.toString();
      }
    }, 300);
  }

  submit(event) {
    // Prevent default form submission on Enter, just trigger the search
    event.preventDefault();
    clearTimeout(this.timeout);
    const frame = document.getElementById("anga-results");
    if (frame) {
      const url = new URL(this.element.action);
      url.searchParams.set("q", this.inputTarget.value);
      frame.src = url.toString();
    }
  }
}
