#!/bin/bash
# Build a committed revision in a disposable, unindexed directory. Never launch it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---check}"
ref="${2:-HEAD}"
case "$mode" in --check|--release) ;; *) echo 'Usage: scripts/build.sh [--check|--release] [git-ref]' >&2; exit 2;; esac
commit="$(git -C "$ROOT" rev-parse --verify "$ref^{commit}")"
mkdir -p "$ROOT/.local/reports" "$ROOT/.local/releases"
scratch="$(mktemp -d "$ROOT/.local/build.XXXXXX")"
cleanup() {
    case "$scratch" in "$ROOT"/.local/build.*) rm -rf -- "$scratch";; esac
}
trap cleanup EXIT
mkdir "$scratch/source"
git -C "$ROOT" archive "$commit" | tar -x -C "$scratch/source"
log="$ROOT/.local/reports/build-$commit-$mode.log"
bundle_id=MeowingCat.MacsyZones
if [[ "$mode" == --release ]]; then
    bundle_id=local.chrisd.macsyzones.20260903
fi
if ! xcodebuild -project "$scratch/source/MacsyZones.xcodeproj" -scheme MacsyZones \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$scratch/DerivedData.noindex" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" build >"$log" 2>&1; then
    tail -n 60 "$log" >&2
    exit 1
fi
app="$scratch/DerivedData.noindex/Build/Products/Release/MacsyZones.app"
test -x "$app/Contents/MacOS/MacsyZones"
if [[ "$mode" == --check ]]; then
    echo "PASS Release build: $commit (app removed on exit)"
    exit 0
fi
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :MacsyZonesSourceCommit string $commit" "$plist"
/usr/libexec/PlistBuddy -c "Add :MacsyZonesSourceTree string $(git -C "$ROOT" rev-parse "$commit:MacsyZones")" "$plist"
/usr/libexec/PlistBuddy -c 'Add :MacsyZonesSourceRepository string https://github.com/eafire15/MacsyZones' "$plist"
codesign --force --options runtime --timestamp \
    --sign 'Apple Development: Christopher De Bruyne (UUK46K4MT8)' "$app"
codesign --verify --deep --strict "$app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = "$bundle_id"
release="$ROOT/.local/releases/$commit"
mkdir -p "$release"
ditto -c -k --sequesterRsrc --keepParent "$app" "$scratch/MacsyZones.zip"
mv "$scratch/MacsyZones.zip" "$release/MacsyZones.zip"
shasum -a 256 "$release/MacsyZones.zip"
echo "Signed release: $release/MacsyZones.zip (no unpacked app retained)"
