# Icon Export Guide

## Source Files

| File | Purpose |
|---|---|
| `yellow-floppy4.svg` | Base icon, no background (transparent) |
| `yellow-floppy4-light.svg` | Light mode: warm white-to-cream gradient background |
| `yellow-floppy4-dark.svg` | Dark mode: warm charcoal gradient background |

All three share the same floppy artwork with black outlines. The light/dark variants add a full-bleed background `<rect>` with a subtle top-to-bottom linear gradient that simulates overhead lighting (iOS-style soft 3D button feel).

## Background Gradients

**Light mode** (`bg-gradient`): `#ffffff` at top to `#e8e4dc` at bottom — warm white cream, gently darker toward the bottom.

**Dark mode** (`bg-gradient`): `#3a3530` at top to `#1a1714` at bottom — warm charcoal, lighter at top where light hits.

Both use warm undertones (not cold gray) to complement the gold floppy.

## Export

### iOS (Xcode Asset Catalog)

Export both light and dark SVGs at 1024x1024 PNG. Xcode generates all other sizes.

```bash
inkscape yellow-floppy4-light.svg --export-type=png --export-width=1024 --export-filename=icon-light-1024.png
inkscape yellow-floppy4-dark.svg --export-type=png --export-width=1024 --export-filename=icon-dark-1024.png
```

In Xcode, add both to the AppIcon asset catalog with Appearances set to "Any, Dark".

### Android (res/mipmap)

Export at each density:

```bash
for size in 48 72 96 144 192 512; do
  inkscape yellow-floppy4-light.svg --export-type=png --export-width=$size --export-filename=icon-light-${size}.png
  inkscape yellow-floppy4-dark.svg --export-type=png --export-width=$size --export-filename=icon-dark-${size}.png
done
```

Place light icons in `res/mipmap-*` and dark icons in `res/mipmap-night-*`.

### Web

- Use `yellow-floppy4.svg` (transparent background) directly as `icon.svg` for favicon
- Export 180x180 PNG from the light variant for `apple-touch-icon`
- Export 192x192 and 512x512 PNGs from light variant for PWA manifest

## Editing Holes

The hole positions are defined in two places that must stay in sync:

1. The `<mask id="hole-mask">` circles in `<defs>` (controls transparency punch-through)
2. The visible `<circle>` border elements (controls the drawn outline)

To reposition holes: move the border circles in Inkscape, note the final `cx`/`cy` values, then update the mask circles to match.
