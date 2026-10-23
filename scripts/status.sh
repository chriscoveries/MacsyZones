#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target=/Applications/MacsyZones.app
printf 'Repository: %s\n' "$ROOT"
git -C "$ROOT" status --short --branch
git -C "$ROOT" remote -v
codesign --verify --deep --strict "$target"
for key in CFBundleIdentifier CFBundleShortVersionString MacsyZonesSourceCommit MacsyZonesSourceTree; do
    printf '%s: ' "$key"
    /usr/libexec/PlistBuddy -c "Print :$key" "$target/Contents/Info.plist" 2>/dev/null || echo '(not embedded in this build)'
done
pids="$(pgrep -x MacsyZones || true)"
if [[ -n "$pids" ]]; then
    for pid in $pids; do ps -p "$pid" -o pid=,etime=,%cpu=,rss=,comm=; done
else
    echo 'MacsyZones is not running.'
fi
echo 'Unpacked MacsyZones apps in this repository:'
find "$ROOT" -type d -iname '*MacsyZones*.app' -prune -print
