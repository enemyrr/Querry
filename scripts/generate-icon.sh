#!/usr/bin/env bash
#
# Regenerate Quarry's app icon and vector mark.
# Requires ImageMagick (brew install imagemagick).
#
# A squircle body with an inset squircle knocked out of it. Every dimension is
# a constant in the Python block below — edit and re-run to retune.
#
# Usage: scripts/generate-icon.sh

set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v magick >/dev/null || { echo "x ImageMagick not found — brew install imagemagick" >&2; exit 1; }

ASSETS="pluk/Resources/Assets.xcassets"
ICONSET="$ASSETS/AppIcon.appiconset"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$TMP/icon.svg" "$ASSETS/quarry_logo_mark.imageset/quarry_logo_mark.svg" <<'PY'
import pathlib, sys

# --- palette -------------------------------------------------------------
BODY = "#000000"
MARK = "#FFFFFF"

# --- geometry, on a 1024 canvas ------------------------------------------
CANVAS       = 1024
BODY_SIZE    = 900     # Apple's grid is 824; larger so it fills the Dock tile
BODY_CORNER  = 0.3146  # corner run as a share of the side (0.5 = fully round)
INNER_RATIO  = 0.44    # inner square as a share of the body
INNER_CORNER = 0.36
# Inner square offset from the body's center, as a share of body size.
# Measured off the original artwork: left of center and below it.
INNER_DX = -0.1038
INNER_DY =  0.0983

# Continuous-corner profile, read off the original mark: each corner is three
# cubics whose control points sit at these fractions of the corner run. This is
# what gives the smooth Apple squircle instead of a plain circular fillet.
P = (0.6500, 0.4750, 0.3413, 0.2237, 0.1280, 0.0681)
A, B, C, D, E, F = P


def squircle(x, y, size, corner):
    """Rounded-square path with a continuous (squircle) corner."""
    k = size * corner
    x0, y0, x1, y1 = x, y, x + size, y + size
    n = lambda v: f"{v:.4f}"
    return " ".join([
        f"M{n(x0 + k)} {n(y0)}",
        f"L{n(x1 - k)} {n(y0)}",
        f"C{n(x1 - A*k)} {n(y0)} {n(x1 - B*k)} {n(y0)} {n(x1 - C*k)} {n(y0 + F*k)}",
        f"C{n(x1 - D*k)} {n(y0 + E*k)} {n(x1 - E*k)} {n(y0 + D*k)} {n(x1 - F*k)} {n(y0 + C*k)}",
        f"C{n(x1)} {n(y0 + B*k)} {n(x1)} {n(y0 + A*k)} {n(x1)} {n(y0 + k)}",
        f"L{n(x1)} {n(y1 - k)}",
        f"C{n(x1)} {n(y1 - A*k)} {n(x1)} {n(y1 - B*k)} {n(x1 - F*k)} {n(y1 - C*k)}",
        f"C{n(x1 - E*k)} {n(y1 - D*k)} {n(x1 - D*k)} {n(y1 - E*k)} {n(x1 - C*k)} {n(y1 - F*k)}",
        f"C{n(x1 - B*k)} {n(y1)} {n(x1 - A*k)} {n(y1)} {n(x1 - k)} {n(y1)}",
        f"L{n(x0 + k)} {n(y1)}",
        f"C{n(x0 + A*k)} {n(y1)} {n(x0 + B*k)} {n(y1)} {n(x0 + C*k)} {n(y1 - F*k)}",
        f"C{n(x0 + D*k)} {n(y1 - E*k)} {n(x0 + E*k)} {n(y1 - D*k)} {n(x0 + F*k)} {n(y1 - C*k)}",
        f"C{n(x0)} {n(y1 - B*k)} {n(x0)} {n(y1 - A*k)} {n(x0)} {n(y1 - k)}",
        f"L{n(x0)} {n(y0 + k)}",
        f"C{n(x0)} {n(y0 + A*k)} {n(x0)} {n(y0 + B*k)} {n(x0 + F*k)} {n(y0 + C*k)}",
        f"C{n(x0 + E*k)} {n(y0 + D*k)} {n(x0 + D*k)} {n(y0 + E*k)} {n(x0 + C*k)} {n(y0 + F*k)}",
        f"C{n(x0 + B*k)} {n(y0)} {n(x0 + A*k)} {n(y0)} {n(x0 + k)} {n(y0)}",
        "Z",
    ])


body_xy = (CANVAS - BODY_SIZE) / 2
inner_size = BODY_SIZE * INNER_RATIO
inner_x = CANVAS / 2 + INNER_DX * BODY_SIZE - inner_size / 2
inner_y = CANVAS / 2 + INNER_DY * BODY_SIZE - inner_size / 2

outer_d = squircle(body_xy, body_xy, BODY_SIZE, BODY_CORNER)
inner_d = squircle(inner_x, inner_y, inner_size, INNER_CORNER)

pathlib.Path(sys.argv[1]).write_text(
    f'<svg width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}" '
    f'xmlns="http://www.w3.org/2000/svg">\n'
    f'  <path d="{outer_d}" fill="{BODY}"/>\n'
    f'  <path d="{inner_d}" fill="{MARK}"/>\n'
    f'</svg>\n'
)

# Flat vector mark for the premium card: one fill, inner knocked out.
s = 294 / CANVAS
mark_outer = squircle(body_xy * s, body_xy * s, BODY_SIZE * s, BODY_CORNER)
mark_inner = squircle(inner_x * s, inner_y * s, inner_size * s, INNER_CORNER)
p = pathlib.Path(sys.argv[2])
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(
    '<svg width="294" height="294" viewBox="0 0 294 294" fill="none" '
    'xmlns="http://www.w3.org/2000/svg">\n'
    f'<path fill-rule="evenodd" d="{mark_outer} {mark_inner}" fill="#D9D9D9"/>\n'
    '</svg>\n'
)

print(f"    body {BODY_SIZE}/{CANVAS} corner {BODY_CORNER:.3f} | "
      f"inner {inner_size:.0f} ({INNER_RATIO:.0%}) corner {INNER_CORNER:.3f}")
PY

cat > "$ASSETS/quarry_logo_mark.imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "quarry_logo_mark.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
JSON

echo "==> Rendering"
magick -background none -density 384 "$TMP/icon.svg" -resize 1024x1024 "$TMP/1024.png"
for size in 1024 512 256 128 64 32 16; do
    magick "$TMP/1024.png" -filter Lanczos -resize "${size}x${size}" -strip "$ICONSET/${size}-mac.png"
done
echo "    ok 7 sizes + quarry_logo_mark.imageset"
