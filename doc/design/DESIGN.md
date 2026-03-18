# Kaya Design

Kaya borrows all its design principles from the [GNOME Human Interface Guidelines](https://developer.gnome.org/hig/), as translated to the web.

## Icons

Symbolic icons should always use the GNOME HIG icons: https://developer.gnome.org/hig/guidelines/ui-icons.html or https://lucide.dev/, retaining symmetry with other icons on a screen/view.

GNOME icons used are Creative Commons Zero 1.0 Universal. Lucide icons are licensed ISC.

## UI Rules

**Strings**: All user-visible text in localization files, never hardcoded
```
# Do:    I18n.t('welcome_message')
# Don't: "Welcome to Kaya"
```

**Date/Time**: All user-visible dates and times localized
```
# Do:    I18n.l(Time.now)
# Don't: Time.now
```

**Colors**: Use theme system, never hardcoded values

**Accessibility**:
- Minimum [48dp/44pt] touch targets
- Alt text/labels required for icons (use `null` only for decorative)
- Don't rely solely on color - pair with icons/text
- Loading indicators must have labels for screen readers
