# Save Button Design

Save Button borrows all its design principles from DaisyUI.

## Icons

Symbolic icons should always use https://lucide.dev/, retaining symmetry with other icons on a screen/view. If an icon isn't available from Lucide, Material UI icons may be used. Exceptions 
include icons which are actually logos, such as the "local-first" icon and Docker.

Lucide icons are licensed ISC.

## UI Rules

**Colors**: Use theme system, never hardcoded values

**Accessibility**:
- Minimum [48dp/44pt] touch targets
- Alt text/labels required for icons (use `null` only for decorative)
- Don't rely solely on color - pair with icons/text
- Loading indicators must have labels for screen readers
