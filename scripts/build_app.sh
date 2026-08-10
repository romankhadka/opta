#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/release/Opta.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGNING_COMMON_NAME="Opta Local Code Signing"
# codesign's spelling for an ad-hoc signature, kept as a name so the comparisons
# below read as intent rather than as a bare dash.
ADHOC_IDENTITY="-"
SIGNING_KEYCHAIN="$HOME/Library/Keychains/opta-local-signing.keychain-db"
SIGNING_KEYCHAIN_PASSWORD="opta-local-signing"
SIGNING_WORK_DIR="$ROOT_DIR/.build/signing"
ICON_DOCUMENT="$ROOT_DIR/Resources/Opta.icon"
ICON_WORK_DIR="$ROOT_DIR/.build/icon"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

ensure_keychain_in_search_list() {
  if security list-keychains -d user | grep -Fq "$SIGNING_KEYCHAIN"; then
    return
  fi

  # shellcheck disable=SC2046
  security list-keychains -d user -s "$SIGNING_KEYCHAIN" $(security list-keychains -d user | tr -d '"')
}

signing_identity() {
  security find-identity -v -p codesigning "$SIGNING_KEYCHAIN" 2>/dev/null |
    sed -n "s/^[[:space:]]*[0-9]*) \\([A-F0-9]*\\) \"$SIGNING_COMMON_NAME\"$/\\1/p" |
    head -n 1
}

create_signing_identity() {
  mkdir -p "$SIGNING_WORK_DIR"

  if [ ! -f "$SIGNING_KEYCHAIN" ]; then
    security create-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
  fi

  security unlock-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
  security set-keychain-settings -lut 21600 "$SIGNING_KEYCHAIN"
  ensure_keychain_in_search_list

  if [ -n "$(signing_identity)" ]; then
    return
  fi

  cat > "$SIGNING_WORK_DIR/openssl.cnf" <<'OPENSSL'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = code_signing

[ dn ]
CN = Opta Local Code Signing

[ code_signing ]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
OPENSSL

  openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -x509 \
    -days 3650 \
    -config "$SIGNING_WORK_DIR/openssl.cnf" \
    -keyout "$SIGNING_WORK_DIR/opta.key" \
    -out "$SIGNING_WORK_DIR/opta.crt" >/dev/null 2>&1

  openssl pkcs12 \
    -legacy \
    -export \
    -inkey "$SIGNING_WORK_DIR/opta.key" \
    -in "$SIGNING_WORK_DIR/opta.crt" \
    -name "$SIGNING_COMMON_NAME" \
    -out "$SIGNING_WORK_DIR/opta.p12" \
    -password "pass:$SIGNING_KEYCHAIN_PASSWORD" >/dev/null

  security import \
    "$SIGNING_WORK_DIR/opta.p12" \
    -k "$SIGNING_KEYCHAIN" \
    -P "$SIGNING_KEYCHAIN_PASSWORD" \
    -T /usr/bin/codesign >/dev/null

  security add-trusted-cert \
    -p codeSign \
    -k "$SIGNING_KEYCHAIN" \
    "$SIGNING_WORK_DIR/opta.crt" >/dev/null

  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$SIGNING_KEYCHAIN_PASSWORD" \
    "$SIGNING_KEYCHAIN" >/dev/null
}

# A release is signed with a Developer ID so that Gatekeeper and notarisation
# have something to trust. Everything else keeps the self-signed local identity,
# which never leaves this machine.
#
# Creating that local identity calls `security add-trusted-cert`, which asks the
# window server for authorisation and therefore blocks forever on a machine with
# no one at the keyboard. CI passes an identity in to skip the whole path.
if [ -n "${OPTA_SIGNING_IDENTITY:-}" ]; then
  SIGNING_IDENTITY="$OPTA_SIGNING_IDENTITY"
  SIGNING_KEYCHAIN="${OPTA_SIGNING_KEYCHAIN:-$SIGNING_KEYCHAIN}"
else
  create_signing_identity
  SIGNING_IDENTITY="$(signing_identity)"
  if [ -z "$SIGNING_IDENTITY" ]; then
    printf '%s\n' "Could not create or find $SIGNING_COMMON_NAME" >&2
    exit 1
  fi
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/opta" "$MACOS_DIR/opta"

compile_app_icon() {
  rm -rf "$ICON_WORK_DIR"
  mkdir -p "$ICON_WORK_DIR"

  # actool turns the Icon Composer document into two things: Assets.car, which
  # carries the Default, Dark, Tinted, and Clear renditions macOS 26 picks
  # between, and Opta.icns, the flat fallback macOS 14 and 15 use instead.
  xcrun actool \
    --output-format human-readable-text \
    --notices \
    --warnings \
    --app-icon Opta \
    --output-partial-info-plist "$ICON_WORK_DIR/icon.plist" \
    --target-device mac \
    --minimum-deployment-target 14.0 \
    --platform macosx \
    --compile "$RESOURCES_DIR" \
    "$ICON_DOCUMENT" >/dev/null

  if [ ! -f "$RESOURCES_DIR/Assets.car" ] || [ ! -f "$RESOURCES_DIR/Opta.icns" ]; then
    printf '%s\n' "actool did not produce both Assets.car and Opta.icns" >&2
    exit 1
  fi
}

# actool's own .icns stops at 256 points, so Finder's larger icon sizes would
# upscale it on the macOS 14 and 15 installs that have no Assets.car to read.
# Rendering the Default appearance at every size iconutil accepts replaces it
# with one that stays sharp all the way up.
build_legacy_icns() {
  if [ ! -x "$ICTOOL" ]; then
    printf '%s\n' "ictool not found at $ICTOOL; install Xcode 26 or newer" >&2
    exit 1
  fi

  local iconset="$ICON_WORK_DIR/Opta.iconset"
  mkdir -p "$iconset"

  local size
  for size in 16 32 64 128 256 512 1024; do
    "$ICTOOL" "$ICON_DOCUMENT" \
      --export-image \
      --output-file "$ICON_WORK_DIR/$size.png" \
      --platform macOS \
      --rendition Default \
      --width "$size" \
      --height "$size" \
      --scale 1 >/dev/null
  done

  cp "$ICON_WORK_DIR/16.png" "$iconset/icon_16x16.png"
  cp "$ICON_WORK_DIR/32.png" "$iconset/icon_16x16@2x.png"
  cp "$ICON_WORK_DIR/32.png" "$iconset/icon_32x32.png"
  cp "$ICON_WORK_DIR/64.png" "$iconset/icon_32x32@2x.png"
  cp "$ICON_WORK_DIR/128.png" "$iconset/icon_128x128.png"
  cp "$ICON_WORK_DIR/256.png" "$iconset/icon_128x128@2x.png"
  cp "$ICON_WORK_DIR/256.png" "$iconset/icon_256x256.png"
  cp "$ICON_WORK_DIR/512.png" "$iconset/icon_256x256@2x.png"
  cp "$ICON_WORK_DIR/512.png" "$iconset/icon_512x512.png"
  cp "$ICON_WORK_DIR/1024.png" "$iconset/icon_512x512@2x.png"

  iconutil --convert icns --output "$RESOURCES_DIR/Opta.icns" "$iconset"
}

compile_app_icon
build_legacy_icns

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Opta</string>
  <key>CFBundleExecutable</key>
  <string>opta</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.romankhadka.opta</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Opta</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

# actool reports the icon's bundle keys rather than having them hand-copied, so
# CFBundleIconName and CFBundleIconFile cannot drift from the document's name.
/usr/libexec/PlistBuddy -c "Merge $ICON_WORK_DIR/icon.plist" "$CONTENTS_DIR/Info.plist" >/dev/null

# A tagged release stamps its own version. A local build keeps the development
# one. Both happen before signing, because editing the bundle after codesign
# invalidates the signature.
if [ -n "${OPTA_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $OPTA_VERSION" \
    "$CONTENTS_DIR/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion ${OPTA_BUILD:-$OPTA_VERSION}" \
    "$CONTENTS_DIR/Info.plist" >/dev/null
fi

CODESIGN_FLAGS=(--force --deep --sign "$SIGNING_IDENTITY")
if [ "$SIGNING_IDENTITY" != "$ADHOC_IDENTITY" ]; then
  CODESIGN_FLAGS+=(--keychain "$SIGNING_KEYCHAIN")

  if [ -n "${OPTA_SIGNING_IDENTITY:-}" ]; then
    # Notarisation rejects a bundle that lacks the hardened runtime or a secure
    # timestamp. An ad-hoc signature can carry neither, which is why this is
    # tied to a real identity.
    CODESIGN_FLAGS+=(--options runtime --timestamp)
  fi
fi

codesign "${CODESIGN_FLAGS[@]}" "$APP_DIR" >/dev/null

printf '%s\n' "$APP_DIR"
