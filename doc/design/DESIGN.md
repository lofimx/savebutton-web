# Save Button Design

Save Button borrows all its design principles from `shadcn/ui` and implements them with `basecoat`.

## Icons

Symbolic icons should always use https://lucide.dev/, retaining symmetry with other icons on a screen/view. Alternatively, Material UI icons can be used if an icon isn't available from Lucide.

Lucide icons are licensed ISC.

## UI Rules

**Colors**: Use theme system, never hardcoded values

**Accessibility**:
- Minimum [48dp/44pt] touch targets
- Alt text/labels required for icons (use `null` only for decorative)
- Don't rely solely on color - pair with icons/text
- Loading indicators must have labels for screen readers
