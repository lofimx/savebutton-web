import { Controller } from "@hotwired/stimulus"

// Theme controller for managing light/dark mode
// Cycles through: auto -> light -> dark -> auto
export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.applyTheme()
    this.updateLabel()
  }

  toggle() {
    const currentTheme = this.getCurrentTheme()
    const nextTheme = this.getNextTheme(currentTheme)

    this.setTheme(nextTheme)
    this.updateLabel()
  }

  getCurrentTheme() {
    return localStorage.getItem("theme") || "auto"
  }

  getNextTheme(current) {
    const themes = ["auto", "light", "dark"]
    const currentIndex = themes.indexOf(current)
    return themes[(currentIndex + 1) % themes.length]
  }

  setTheme(theme) {
    localStorage.setItem("theme", theme)
    this.applyTheme()
  }

  applyTheme() {
    const theme = this.getCurrentTheme()
    const root = document.documentElement

    if (theme === "auto") {
      root.removeAttribute("data-theme")
    } else {
      root.setAttribute("data-theme", theme)
    }
  }

  updateLabel() {
    const theme = this.getCurrentTheme()
    const labels = {
      auto: "Auto",
      light: "Light",
      dark: "Dark"
    }

    // Update all labels on the page
    document.querySelectorAll("[data-theme-label]").forEach(el => {
      el.textContent = labels[theme]
    })

    // Update data-theme attribute for CSS icon switching
    const root = document.documentElement
    if (theme === "auto") {
      root.removeAttribute("data-theme")
    } else {
      root.setAttribute("data-theme", theme)
    }
  }
}
