import { Controller } from "@hotwired/stimulus"

// Theme controller for managing light/dark mode
// Cycles through: auto -> light -> dark -> auto
export default class extends Controller {
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
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
      root.setAttribute("data-theme", prefersDark ? "dark" : "light")
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

    document.querySelectorAll("[data-theme-label]").forEach(el => {
      el.textContent = labels[theme]
    })
  }
}
