#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ref="${1:-fix/lazy-layout-memory}"
commit="$(git -C "$root" rev-parse --verify "$ref^{commit}")"
echo "Testing $commit"
{
    cat "$root/scripts/tests/lazy-stubs.swift"
    git -C "$root" show "$commit:MacsyZones/UserData.swift" | awk '/^class UserLayout \{/{inside=1} /^struct UpdateStateData:/{inside=0} inside'
    git -C "$root" show "$commit:MacsyZones/Macsy.swift" | awk '/^func startEditing\(\)/{inside=1} /^func getMenuBarHeight\(\)/{inside=0} inside'
    cat "$root/scripts/tests/lazy-assertions.swift"
} | /usr/bin/swift -
