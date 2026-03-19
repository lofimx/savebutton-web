# Save Button Design

Save Button (Web) is styled with vanilla Bootstrap.

## Icons

Symbolic icons should always use Bootstrap icons by default.

If Bootstrap does not have a particular icon, use icons from https://lucide.dev/, retaining symmetry with other icons on a screen/view. Lucide icons are licensed ISC.

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
