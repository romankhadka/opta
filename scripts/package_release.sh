#!/usr/bin/env bash
# Builds Opta and packages it as a zip for a GitHub release.
#
# macOS only trusts a downloaded app if it is signed with a Developer ID and
# notarised by Apple. Both are opt-in here, driven entirely by whether the
# credentials are present:
#
#   OPTA_SIGNING_IDENTITY  a Developer ID Application identity in the keychain
#   OPTA_SIGNING_KEYCHAIN  the keychain holding it, if not the login keychain
#   OPTA_NOTARY_PROFILE    a notarytool keychain profile to submit with
#
# With them, the result opens with a double click. Without them, the app is
# signed by the throwaway local identity and macOS will refuse it until the
# user clears quarantine by hand; the script says so rather than pretending
# otherwise.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/.build/dist"
VERSION="${OPTA_VERSION:-0.0.0-dev}"
ZIP_PATH="$DIST_DIR/Opta-$VERSION.zip"

log() { printf '==> %s\n' "$1"; }

log "Building Opta $VERSION"
APP_PATH="$("$ROOT_DIR/scripts/build_app.sh" | tail -n 1)"

if [ ! -d "$APP_PATH" ]; then
  printf '%s\n' "build_app.sh did not produce an app bundle" >&2
  exit 1
fi

log "Verifying the signature"
codesign --verify --strict --deep "$APP_PATH"

if [ -n "${OPTA_SIGNING_IDENTITY:-}" ]; then
  # Only a Developer ID signature can satisfy this; the local identity fails it,
  # which is exactly the distinction that matters for a download.
  if ! spctl --assess --type execute "$APP_PATH" 2>/dev/null; then
    log "Gatekeeper does not accept this build yet (expected before notarisation)"
  fi
fi

log "Confirming the icon survived into the bundle"
for resource in Assets.car Opta.icns; do
  if [ ! -f "$APP_PATH/Contents/Resources/$resource" ]; then
    printf '%s\n' "Missing $resource in the packaged app" >&2
    exit 1
  fi
done

BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
if [ "$BUNDLE_VERSION" != "$VERSION" ] && [ -n "${OPTA_VERSION:-}" ]; then
  printf '%s\n' "Bundle version $BUNDLE_VERSION does not match requested $VERSION" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# ditto keeps the bundle's symlinks and extended attributes intact, which plain
# zip does not; a zip built any other way can arrive with a broken signature.
log "Compressing to $(basename "$ZIP_PATH")"
ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$ZIP_PATH"

if [ -n "${OPTA_NOTARY_PROFILE:-}" ]; then
  log "Submitting to Apple for notarisation (this waits for the verdict)"
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$OPTA_NOTARY_PROFILE" \
    --wait

  # The ticket staples to the app, not the archive, so the app is re-zipped
  # afterwards to carry the ticket offline.
  log "Stapling the ticket"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"

  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$ZIP_PATH"

  log "Checking Gatekeeper accepts the stapled build"
  spctl --assess --type execute --verbose "$APP_PATH"
  printf 'notarised\n' > "$DIST_DIR/TRUST"
else
  log "No notary profile set — shipping an unnotarised build"
  printf 'unnotarised\n' > "$DIST_DIR/TRUST"
fi

shasum -a 256 "$ZIP_PATH" | awk '{print $1"  "FILENAME}' FILENAME="$(basename "$ZIP_PATH")" \
  > "$DIST_DIR/SHA256SUMS.txt"

log "Done"
printf '%s\n' "$ZIP_PATH"
