# Save Button Design

Save Button (web) borrows all its design principles from `shadcn/ui`, translated to Tailwind.

## Icons

Icons use Lucide (https://lucide.dev/), inline as SVGs. Lucide icons are licensed ISC.

## UI Rules

**Colors**: Use theme system, never hardcoded values

**Accessibility**:
- Minimum [48dp/44pt] touch targets
- Alt text/labels required for icons (use `null` only for decorative)
- Don't rely solely on color - pair with icons/text
- Loading indicators must have labels for screen readers
