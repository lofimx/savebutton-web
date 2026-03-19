import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["message"];

  connect() {
    // Auto-dismiss after 5 seconds
    this.timeout = setTimeout(() => {
      this.dismiss();
    }, 5000);
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  }

  dismiss() {
    // Use Bootstrap's fade class for smooth dismissal
    this.element.classList.remove("show");
    setTimeout(() => {
      this.element.remove();
    }, 150);
  }
}
