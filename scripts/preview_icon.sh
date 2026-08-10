#!/usr/bin/env bash
# Renders every appearance macOS 26 can ask Opta's icon for, and checks the one
# property the mark cannot afford to lose.
#
# The background colour in icon.json is not free. macOS derives the Dark
# rendition's mark colour from that seed: a seed that is light enough or
# saturated enough makes the system draw the mark as a tinted material instead
# of white, which drops the mark to roughly 2.5:1 against its own background.
# The chosen seed sits well inside the region that keeps the mark white, but the
# boundary is a system heuristic rather than a documented contract, so this
# script fails if a future macOS moves it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DOCUMENT="$ROOT_DIR/Resources/Opta.icon"
OUTPUT_DIR="${1:-$ROOT_DIR/.build/icon-preview}"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

RENDITIONS=(Default Dark TintedLight TintedDark ClearLight ClearDark)

if [ ! -x "$ICTOOL" ]; then
  printf '%s\n' "ictool not found at $ICTOOL; install Xcode 26 or newer" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for rendition in "${RENDITIONS[@]}"; do
  "$ICTOOL" "$ICON_DOCUMENT" \
    --export-image \
    --output-file "$OUTPUT_DIR/$rendition.png" \
    --platform macOS \
    --rendition "$rendition" \
    --width 512 \
    --height 512 \
    --scale 1 >/dev/null
done

# ictool writes 16-bit RGBA PNGs and macOS ships no stdlib-free way to read a
# pixel back, so the check decodes one itself. Reading a small render keeps the
# pure-Python unfiltering cheap.
"$ICTOOL" "$ICON_DOCUMENT" \
  --export-image \
  --output-file "$OUTPUT_DIR/.dark-probe.png" \
  --platform macOS \
  --rendition Dark \
  --width 128 \
  --height 128 \
  --scale 1 >/dev/null

# Samples the mark's top-left arm, which sits clear of the specular highlight
# running down the diagonal.
mark_colour() {
  python3 - "$1" <<'PY'
import struct
import sys
import zlib

data = open(sys.argv[1], "rb").read()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    sys.exit("not a PNG")

header = None
compressed = bytearray()
offset = 8
while offset < len(data):
    length, kind = struct.unpack(">I4s", data[offset:offset + 8])
    body = data[offset + 8:offset + 8 + length]
    if kind == b"IHDR":
        header = struct.unpack(">IIBBBBB", body)
    elif kind == b"IDAT":
        compressed += body
    elif kind == b"IEND":
        break
    offset += 12 + length

width, height, depth, colour_type, _, _, interlace = header
if interlace or colour_type != 6 or depth not in (8, 16):
    sys.exit(f"unsupported PNG: depth={depth} colour_type={colour_type} interlace={interlace}")

sample_size = depth // 8
pixel_bytes = 4 * sample_size
stride = width * pixel_bytes
raw = zlib.decompress(bytes(compressed))

previous = bytearray(stride)
row_start = 0
target_row = int(height * 0.35)
for row in range(target_row + 1):
    filter_type = raw[row_start]
    line = bytearray(raw[row_start + 1:row_start + 1 + stride])
    row_start += 1 + stride
    if filter_type == 1:
        for i in range(pixel_bytes, stride):
            line[i] = (line[i] + line[i - pixel_bytes]) & 0xFF
    elif filter_type == 2:
        for i in range(stride):
            line[i] = (line[i] + previous[i]) & 0xFF
    elif filter_type == 3:
        for i in range(stride):
            left = line[i - pixel_bytes] if i >= pixel_bytes else 0
            line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
    elif filter_type == 4:
        for i in range(stride):
            left = line[i - pixel_bytes] if i >= pixel_bytes else 0
            up = previous[i]
            upper_left = previous[i - pixel_bytes] if i >= pixel_bytes else 0
            estimate = left + up - upper_left
            da, db, dc = abs(estimate - left), abs(estimate - up), abs(estimate - upper_left)
            line[i] = (line[i] + (left if da <= db and da <= dc else up if db <= dc else upper_left)) & 0xFF
    elif filter_type != 0:
        sys.exit(f"unknown PNG filter {filter_type}")
    previous = line

column = int(width * 0.33) * pixel_bytes
print(previous[column], previous[column + sample_size], previous[column + 2 * sample_size])
PY
}

read -r red green blue < <(mark_colour "$OUTPUT_DIR/.dark-probe.png")
rm -f "$OUTPUT_DIR/.dark-probe.png"

if [ "$red" -lt 200 ] || [ "$green" -lt 200 ] || [ "$blue" -lt 200 ]; then
  printf '%s\n' "Dark rendition drew the mark as $red,$green,$blue instead of white." >&2
  printf '%s\n' "macOS now tints the mark for this background seed. Darken or desaturate" >&2
  printf '%s\n' "the automatic-gradient colour in Resources/Opta.icon/icon.json until this" >&2
  printf '%s\n' "check passes again." >&2
  exit 1
fi

printf '%s\n' "$OUTPUT_DIR"
