import { Controller } from "@hotwired/stimulus"

// Theme controller for managing light/dark mode
// Cycles through: auto -> light -> dark -> auto
// Basecoat uses the `dark` class on <html> for dark mode
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

    // Remove existing theme state
    root.classList.remove("dark")
    root.removeAttribute("data-theme")

    if (theme === "dark") {
      root.classList.add("dark")
      root.setAttribute("data-theme", "dark")
    } else if (theme === "light") {
      root.setAttribute("data-theme", "light")
    } else {
      // Auto: follow system preference
      if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
        root.classList.add("dark")
      }
    }
  }

  updateLabel() {
    const theme = this.getCurrentTheme()
    const labels = {
      auto: "Auto",
      light: "Light",
      dark: "Dark"
    }

    document.querySelectorAll("[data-theme-label]").forEach(el => {
      el.textContent = labels[theme]
    })
  }
}
