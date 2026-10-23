#!/bin/bash
# Replace the single installed app, preserving its working Tahoe identity.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
commit="$(git -C "$ROOT" rev-parse --verify "${1:-HEAD}^{commit}")"
archive="$ROOT/.local/releases/$commit/MacsyZones.zip"
target=/Applications/MacsyZones.app
bundle_id=local.chrisd.macsyzones.20260903
test -f "$archive"
test -d "$target"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist")" = "$bundle_id"
mkdir -p "$ROOT/.local/backups"
scratch="$(mktemp -d "$ROOT/.local/install.XXXXXX")"
swapped=0
cleanup() {
    # Before a completed swap, restore the original app if necessary.
    if [[ "$swapped" == 0 && -d "$scratch/previous.app" && ! -e "$target" ]]; then
        mv "$scratch/previous.app" "$target"
    fi
    case "$scratch" in "$ROOT"/.local/install.*) rm -rf -- "$scratch";; esac
}
trap cleanup EXIT
ditto -x -k "$archive" "$scratch"
app="$scratch/MacsyZones.app"
codesign --verify --deep --strict "$app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = "$bundle_id"
test "$(/usr/libexec/PlistBuddy -c 'Print :MacsyZonesSourceCommit' "$app/Contents/Info.plist")" = "$commit"
codesign -dv "$app" 2>&1 | /usr/bin/grep -q '^TeamIdentifier=U454V8N2L2$'
backup="$ROOT/.local/backups/before-$commit-$(date +%Y%m%d-%H%M%S).zip"
ditto -c -k --sequesterRsrc --keepParent "$target" "$backup"
/usr/bin/unzip -tq "$backup" >/dev/null
settings="$HOME/Library/Application Support/$bundle_id"
if [[ -d "$settings" ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$settings" "${backup%.zip}-settings.zip"
    /usr/bin/unzip -tq "${backup%.zip}-settings.zip" >/dev/null
fi
# Stop only processes executing the canonical installed binary.
pids="$(pgrep -x MacsyZones || true)"
for pid in $pids; do
    executable="$(ps -p "$pid" -o comm=)"
    [[ "$executable" == "$target/Contents/MacOS/MacsyZones" ]] || { echo "Unexpected MacsyZones process: $pid $executable" >&2; exit 1; }
done
for pid in $pids; do kill -TERM "$pid"; done
for attempt in {1..30}; do
    if ! pgrep -x MacsyZones >/dev/null; then break; fi
    sleep 0.2
done
if pgrep -x MacsyZones >/dev/null; then echo 'MacsyZones has not quit; install aborted.' >&2; exit 1; fi
mv "$target" "$scratch/previous.app"
mv "$app" "$target"
if ! codesign --verify --deep --strict "$target"; then
    mv "$target" "$scratch/failed.app"
    mv "$scratch/previous.app" "$target"
    exit 1
fi
swapped=1
echo "Installed $commit at $target"
echo "Previous app archived at $backup"
echo 'App left stopped. Launch the canonical installed app once after verification.'
