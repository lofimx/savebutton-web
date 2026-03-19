import { Controller } from "@hotwired/stimulus";

// Theme controller for managing light/dark mode via Bootstrap's data-bs-theme
// Cycles through: auto -> light -> dark -> auto
export default class extends Controller {
  static targets = ["label"];

  connect() {
    this.applyTheme();
    this.updateLabel();

    // Listen for system theme changes when in auto mode
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    this.mediaQueryHandler = () => {
      if (this.getCurrentTheme() === "auto") {
        this.applyTheme();
      }
    };
    this.mediaQuery.addEventListener("change", this.mediaQueryHandler);
  }

  disconnect() {
    if (this.mediaQuery && this.mediaQueryHandler) {
      this.mediaQuery.removeEventListener("change", this.mediaQueryHandler);
    }
  }

  toggle() {
    const currentTheme = this.getCurrentTheme();
    const nextTheme = this.getNextTheme(currentTheme);

    this.setTheme(nextTheme);
    this.updateLabel();
  }

  getCurrentTheme() {
    return localStorage.getItem("theme") || "auto";
  }

  getNextTheme(current) {
    const themes = ["auto", "light", "dark"];
    const currentIndex = themes.indexOf(current);
    return themes[(currentIndex + 1) % themes.length];
  }

  setTheme(theme) {
    localStorage.setItem("theme", theme);
    this.applyTheme();
  }

  applyTheme() {
    const theme = this.getCurrentTheme();
    const root = document.documentElement;

    if (theme === "auto") {
      // Resolve auto to actual preference
      const prefersDark = window.matchMedia(
        "(prefers-color-scheme: dark)",
      ).matches;
      root.setAttribute("data-bs-theme", prefersDark ? "dark" : "light");
    } else {
      root.setAttribute("data-bs-theme", theme);
    }
  }

  updateLabel() {
    const theme = this.getCurrentTheme();
    const labels = {
      auto: "Auto",
      light: "Light",
      dark: "Dark",
    };

    // Update all labels on the page
    document.querySelectorAll("[data-theme-label]").forEach((el) => {
      el.textContent = labels[theme];
    });

    // Show the correct icon by hiding others
    this.updateIcons(theme);
  }

  updateIcons(theme) {
    const iconMap = {
      auto: "theme-icon-auto",
      light: "theme-icon-light",
      dark: "theme-icon-dark",
    };

    // Hide all icons, show only the active one
    document.querySelectorAll(".theme-icon-auto, .theme-icon-light, .theme-icon-dark").forEach((el) => {
      el.style.display = "none";
    });

    document.querySelectorAll(`.${iconMap[theme]}`).forEach((el) => {
      el.style.display = "";
    });
  }
}
