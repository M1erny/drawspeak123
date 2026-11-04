#!/bin/bash
# Archive, export, validate and (optionally) upload Drawspeak to TestFlight.
#
#   scripts/testflight.sh --no-upload   archive + export + IPA checks + altool --validate-app
#   scripts/testflight.sh               the same, then altool --upload-package
#
# Signing is manual: "Apple Distribution" + the "Drawspeak App Store" profile, set for the
# Release config of the app target in App/project.yml (see docs/RELEASE.md). Heavy steps run through ~/.local/bin/heavy-check.
# The ASC API key is found by altool in ~/.appstoreconnect/private_keys and is never read here.
# Compatible with macOS /bin/bash 3.2.
set -euo pipefail

TEAM_ID=7S3F9767BM
BUNDLE_ID=com.wydrox.drawspeak
PROFILE_NAME="Drawspeak App Store"
SIGN_IDENTITY="Apple Distribution"
API_KEY_ID=2PX9L952HH
API_ISSUER=21e40dd1-5b96-4c70-a35e-f5b49ba22361
SCHEME=Drawspeak
DERIVED_DATA=${DS_DERIVED_DATA:-/tmp/ds-archive-dd}
RELEASE_ROOT=${DS_RELEASE_ROOT:-/tmp/ds-release}
HEAVY=${HEAVY_CHECK:-$HOME/.local/bin/heavy-check}
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

UPLOAD=1
for arg in "$@"; do
  case "$arg" in
    --no-upload) UPLOAD=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $arg" >&2; exit 64 ;;
  esac
done

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_DIR="$ROOT/App"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions.plist"

step() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# Run a command through the heavy-check queue, logging to a file.
# Exit 75/77 from the queue means the command did NOT run.
heavy() {
  local log=$1; shift
  local rc=0
  "$HEAVY" "$@" >"$log" 2>&1 || rc=$?
  if [ "$rc" -eq 75 ] || [ "$rc" -eq 77 ]; then
    tail -5 "$log" >&2
    echo "error: heavy-check refused (exit $rc): the command did NOT run" >&2
    exit "$rc"
  fi
  if [ "$rc" -ne 0 ]; then
    grep -E 'error:|\*\* .* FAILED \*\*' "$log" | head -30 >&2 || true
    tail -20 "$log" >&2
    echo "error: command failed (exit $rc); full log: $log" >&2
    exit "$rc"
  fi
}

# Print the installed profile file (newest) whose Name matches $PROFILE_NAME.
find_profile() {
  local f name best="" best_date=""
  for f in "$PROFILE_DIR"/*.mobileprovision; do
    [ -f "$f" ] || continue
    security cms -D -i "$f" >"$WORK/p.plist" 2>/dev/null || continue
    name=$(/usr/libexec/PlistBuddy -c 'Print :Name' "$WORK/p.plist" 2>/dev/null || true)
    [ "$name" = "$PROFILE_NAME" ] || continue
    local created
    created=$(plutil -extract CreationDate raw "$WORK/p.plist" 2>/dev/null || true)
    if [ -z "$best" ] || [[ "$created" > "$best_date" ]]; then best=$f; best_date=$created; fi
  done
  [ -n "$best" ] && echo "$best"
}

plist_get() { plutil -extract "$1" raw -o - "$2" 2>/dev/null || true; }

# ---------------------------------------------------------------- preflight
BUILD=${DS_BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}
OUT="$RELEASE_ROOT/$BUILD"
ARCHIVE="$OUT/Drawspeak.xcarchive"
EXPORT_DIR="$OUT/export"
WORK="$OUT/work"
RECEIPT="$RELEASE_ROOT/receipt-$BUILD.json"
[ -e "$OUT" ] && die "$OUT already exists (build $BUILD); wait a minute or set DS_BUILD_NUMBER"
mkdir -p "$WORK"

step "Preflight (build $BUILD, upload=$UPLOAD)"
command -v xcodegen >/dev/null || die "xcodegen not found"
[ -x "$HEAVY" ] || die "heavy-check not found at $HEAVY"
[ -f "$EXPORT_OPTIONS" ] || die "missing $EXPORT_OPTIONS"
[ -f "$HOME/.appstoreconnect/private_keys/AuthKey_$API_KEY_ID.p8" ] || die "ASC API key $API_KEY_ID not installed"
# Capture before grep: with pipefail, grep -q closing the pipe early fails the pipeline.
IDENTITIES=$(security find-identity -v -p codesigning)
grep -q "\"$SIGN_IDENTITY: .*($TEAM_ID)\"" <<<"$IDENTITIES" \
  || die "no valid '$SIGN_IDENTITY' identity for team $TEAM_ID in the keychain"
PROFILE_FILE=$(find_profile) || die "profile '$PROFILE_NAME' not installed in $PROFILE_DIR (see docs/RELEASE.md)"
security cms -D -i "$PROFILE_FILE" >"$WORK/profile.plist"
PROFILE_UUID=$(plist_get UUID "$WORK/profile.plist")
PROFILE_APPID=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$WORK/profile.plist")
PROFILE_EXP=$(plist_get ExpirationDate "$WORK/profile.plist")
[ "$PROFILE_APPID" = "$TEAM_ID.$BUNDLE_ID" ] || die "profile app id is $PROFILE_APPID, expected $TEAM_ID.$BUNDLE_ID"
echo "profile $PROFILE_UUID (expires $PROFILE_EXP)"
GIT_COMMIT=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
GIT_DIRTY=false
[ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] && GIT_DIRTY=true
echo "git $GIT_COMMIT (dirty=$GIT_DIRTY)"

# Manual signing lives in App/project.yml (target Drawspeak, config Release). Passing
# PROVISIONING_PROFILE_SPECIFIER on the xcodebuild command line also hits the SwiftPM
# resource-bundle targets ("DrawspeakKit_HTMLKit does not support provisioning profiles").
for want in "CODE_SIGN_STYLE: Manual" "CODE_SIGN_IDENTITY: $SIGN_IDENTITY" "PROVISIONING_PROFILE_SPECIFIER: $PROFILE_NAME"; do
  grep -q "^ *$want\$" "$APP_DIR/project.yml" \
    || die "App/project.yml lacks '$want' in the Drawspeak Release config (see docs/RELEASE.md)"
done

# ---------------------------------------------------------------- built-in key
# The ElevenLabs key comes from the environment (run this script through Apassy with
# DRAWSPEAK_ELEVENLABS_API_KEY set). It is written to a git-ignored xcconfig only for
# the archive and removed on exit. It is never printed.
SECRETS="$APP_DIR/Config/Secrets.xcconfig"
[ -n "${DRAWSPEAK_ELEVENLABS_API_KEY:-}" ] || die "DRAWSPEAK_ELEVENLABS_API_KEY is not set (run via Apassy)"
if [ -z "${DRAWSPEAK_ANTHROPIC_API_KEY:-}" ]; then
  echo "warning: DRAWSPEAK_ANTHROPIC_API_KEY is not set; Refine with Claude stays off in this build" >&2
fi
trap 'rm -f "$SECRETS"' EXIT
umask 077
printf 'ELEVENLABS_API_KEY = %s\nANTHROPIC_API_KEY = %s\n' "$DRAWSPEAK_ELEVENLABS_API_KEY" "${DRAWSPEAK_ANTHROPIC_API_KEY:-}" >"$SECRETS"

# ---------------------------------------------------------------- generate
step "xcodegen generate"
(cd "$APP_DIR" && xcodegen generate --spec project.yml --quiet)

# ---------------------------------------------------------------- archive
step "Archive (Release, generic/platform=iOS) -> $ARCHIVE"
heavy "$OUT/archive.log" xcodebuild archive \
  -project "$APP_DIR/Drawspeak.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$DERIVED_DATA" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  DEVELOPMENT_TEAM="$TEAM_ID"
[ -d "$ARCHIVE" ] || die "archive not created; see $OUT/archive.log"

# ---------------------------------------------------------------- export
step "Export IPA -> $EXPORT_DIR"
heavy "$OUT/export.log" xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"
IPA=$(ls "$EXPORT_DIR"/*.ipa 2>/dev/null | head -1 || true)
[ -n "$IPA" ] && [ -f "$IPA" ] || die "no IPA in $EXPORT_DIR; see $OUT/export.log"
echo "ipa $IPA ($(du -h "$IPA" | cut -f1))"

# ---------------------------------------------------------------- verify IPA
step "Verify IPA contents"
rm -rf "$WORK/ipa"
unzip -q "$IPA" -d "$WORK/ipa"
APP=$(ls -d "$WORK/ipa/Payload/"*.app | head -1)
INFO="$APP/Info.plist"
IPA_BUILD=$(plist_get CFBundleVersion "$INFO")
IPA_VERSION=$(plist_get CFBundleShortVersionString "$INFO")
IPA_BUNDLE=$(plist_get CFBundleIdentifier "$INFO")
IPA_ENCRYPTION=$(plist_get ITSAppUsesNonExemptEncryption "$INFO")
echo "CFBundleIdentifier=$IPA_BUNDLE CFBundleShortVersionString=$IPA_VERSION CFBundleVersion=$IPA_BUILD ITSAppUsesNonExemptEncryption=$IPA_ENCRYPTION"
[ "$IPA_BUNDLE" = "$BUNDLE_ID" ] || die "bundle id is '$IPA_BUNDLE', expected $BUNDLE_ID"
[ "$IPA_BUILD" = "$BUILD" ] || die "CFBundleVersion is '$IPA_BUILD', expected $BUILD"
[ "$IPA_ENCRYPTION" = "false" ] || die "ITSAppUsesNonExemptEncryption must be false, got '$IPA_ENCRYPTION'"
[ "$(plist_get DSElevenLabsAPIKey "$INFO")" = "$DRAWSPEAK_ELEVENLABS_API_KEY" ] \
  || die "built-in ElevenLabs key missing from the IPA Info.plist"
if [ -n "${DRAWSPEAK_ANTHROPIC_API_KEY:-}" ]; then
  [ "$(plist_get DSAnthropicAPIKey "$INFO")" = "$DRAWSPEAK_ANTHROPIC_API_KEY" ] \
    || die "built-in Anthropic key missing from the IPA Info.plist"
fi
[ -n "$(plist_get 'CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName' "$INFO")" ] \
  || die "no compiled iPad app icon in Info.plist (CFBundleIcons~ipad)"
security cms -D -i "$APP/embedded.mobileprovision" >"$WORK/embedded.plist"
EMBEDDED_UUID=$(plist_get UUID "$WORK/embedded.plist")
[ "$EMBEDDED_UUID" = "$PROFILE_UUID" ] || die "embedded profile $EMBEDDED_UUID != installed $PROFILE_UUID"
codesign --verify --deep --strict "$APP" || die "codesign verification failed"
SIGN_INFO=$(codesign -dvv "$APP" 2>&1)
grep -q "^Authority=Apple Distribution: .*($TEAM_ID)" <<<"$SIGN_INFO" \
  || die "app is not signed with Apple Distribution ($TEAM_ID)"
IPA_SHA256=$(shasum -a 256 "$IPA" | cut -d' ' -f1)
echo "signature ok, embedded profile ok, sha256 $IPA_SHA256"

# ---------------------------------------------------------------- validate
step "altool --validate-app"
VALIDATE=failed
if xcrun altool --validate-app "$IPA" --api-key "$API_KEY_ID" --api-issuer "$API_ISSUER" \
    >"$OUT/validate.log" 2>&1; then
  VALIDATE=passed
fi
tail -15 "$OUT/validate.log"

UPLOAD_STATUS=skipped
DELIVERY_ID=""
write_receipt() {
  cat >"$RECEIPT" <<EOF
{
  "app": "Drawspeak",
  "bundleId": "$BUNDLE_ID",
  "marketingVersion": "$IPA_VERSION",
  "build": "$BUILD",
  "createdUtc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gitCommit": "$GIT_COMMIT",
  "gitDirty": $GIT_DIRTY,
  "profileUuid": "$PROFILE_UUID",
  "ipa": "$IPA",
  "ipaSha256": "$IPA_SHA256",
  "validate": "$VALIDATE",
  "upload": "$UPLOAD_STATUS",
  "deliveryId": "$DELIVERY_ID",
  "logs": "$OUT"
}
EOF
  echo "receipt $RECEIPT"
}
if [ "$VALIDATE" != passed ]; then
  write_receipt
  die "validation failed; full log: $OUT/validate.log"
fi

# ---------------------------------------------------------------- upload
if [ "$UPLOAD" -eq 1 ]; then
  step "altool --upload-package (build $BUILD)"
  if xcrun altool --upload-package "$IPA" --api-key "$API_KEY_ID" --api-issuer "$API_ISSUER" \
      >"$OUT/upload.log" 2>&1; then
    UPLOAD_STATUS=uploaded
    DELIVERY_ID=$(grep -Eio 'delivery ?uuid[^0-9a-f]*[0-9a-f-]{36}' "$OUT/upload.log" | grep -Eo '[0-9a-f-]{36}' | head -1 || true)
  else
    UPLOAD_STATUS=failed
  fi
  tail -15 "$OUT/upload.log"
  write_receipt
  [ "$UPLOAD_STATUS" = uploaded ] || die "upload failed; full log: $OUT/upload.log"
  echo "UPLOADED Drawspeak $IPA_VERSION ($BUILD); processing takes ~5-30 min before TestFlight shows it"
else
  write_receipt
  echo "DRY RUN OK: Drawspeak $IPA_VERSION ($BUILD) validated, not uploaded"
fi
