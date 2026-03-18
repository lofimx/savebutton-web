import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    const isOpen = this.dropdownTarget.classList.contains("open")

    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.dropdownTarget.classList.add("open")
    document.addEventListener("click", this.closeOnClickOutside)
  }

  close() {
    this.dropdownTarget.classList.remove("open")
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }
}
