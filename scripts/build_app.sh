#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/release/Opta.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGNING_COMMON_NAME="Opta Local Code Signing"
SIGNING_KEYCHAIN="$HOME/Library/Keychains/opta-local-signing.keychain-db"
SIGNING_KEYCHAIN_PASSWORD="opta-local-signing"
SIGNING_WORK_DIR="$ROOT_DIR/.build/signing"

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

create_signing_identity
SIGNING_IDENTITY="$(signing_identity)"
if [ -z "$SIGNING_IDENTITY" ]; then
  printf '%s\n' "Could not create or find $SIGNING_COMMON_NAME" >&2
  exit 1
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/opta" "$MACOS_DIR/opta"

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

codesign \
  --force \
  --deep \
  --keychain "$SIGNING_KEYCHAIN" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_DIR" >/dev/null

printf '%s\n' "$APP_DIR"
