import { Controller } from "@hotwired/stimulus"

// Theme controller for managing light/dark mode
// Cycles through: auto -> light -> dark -> auto
//
// data-theme is always resolved to "light" or "dark" for CSS styling.
// data-theme-preference stores the user's choice ("auto", "light", "dark")
// and is used for the footer toggle icon display.
export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.applyTheme()
    this.updateLabel()

    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleMediaChange = () => {
      if (this.getCurrentTheme() === "auto") this.applyTheme()
    }
    this.mediaQuery.addEventListener("change", this.handleMediaChange)
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.handleMediaChange)
    }
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

    root.setAttribute("data-theme-preference", theme)

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
