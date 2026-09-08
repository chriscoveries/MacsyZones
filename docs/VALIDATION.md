# Validation — 2026-09-08

## Installed maintained fork

The installed app is `/Applications/MacsyZones.app`, source revision
`324a4906b7b4b55c388104e8536cc1f23e3d8402`, tagged `installed/2026-09-08`.
Its `MacsyZones/` tree is `7839718d6144f1af7ced1991ac9b649cc025f81a`.
Later documentation/tooling commits do not change this installed application
source; compare the embedded tree with `git rev-parse HEAD:MacsyZones`.

- Clean Release build passed on Xcode 26.6, with Apple Development signing.
- `codesign --verify --deep --strict` passed before and after installation.
- The successful bundle identity remains `local.chrisd.macsyzones.20260903`,
  signing team `U454V8N2L2`.
- Exactly one process ran from the canonical application path after replacement.
- Native background-task state records one MacsyZones application login item
  as `[enabled, allowed, notified]`, targeting `file:///Applications/MacsyZones.app/`.
- Control Center accepted the current host and created its menu-bar displayable;
  no blocked-host message was observed for this launch. The computer-use service
  timed out, so this is host-log evidence, not a current visual icon check.
- No logout/reboot was performed. The persistent startup registration is verified;
  launching after a real login remains an end-to-end check.
- AppSettings, UpdateState, SpaceLayoutPreferences and OnboardingState retained
  their pre-install file hashes. UserLayouts is re-encoded by the existing
  `UserLayouts.load()` → `save()` startup path; its raw file hash changed.
  A pre-install semantic snapshot was not captured, so this report does not
  claim byte-for-byte layout preservation. Future installs archive settings too.

## Upstream branches

| PR / change | Commit built | Result |
| --- | --- | --- |
| #103 bounded dwell animation | `4d30fcfc1ffdcbe46157eb7e2894946387832271` | Release passed |
| #104 duplicate layout load | `4af86df75102cacc258dbb1eaa878a6c74ccf533` | Release passed |
| #105 support reminders | `15ed0c2cf5d48000a771d66ea4ae80450e0aeb22` | Release passed |
| #106 lazy layout lifecycle | `c57c6cb7d764df06f7a5a9d744d205297b15d751` | Release and 139 model assertions passed |
| Stable status-item identity, separate branch | `8d372c1aa4a68671855eec955e4ef350474ab7f1` | Release passed |

`scripts/check_lazy_lifecycle.sh fix/lazy-layout-memory` compiles the actual
`UserLayout` class and editing functions taken from that Git revision against
Foundation-only fake window collaborators. It tests cold allocation, nonallocating
hide/stop-editing paths, lazy graph reuse, and configuration propagation.
It does not launch an app, access user settings, or test AppKit rendering,
real window ownership, snapping, or multiple monitors.

The first review found that #107's immediate array clear could crash queued
hotkey callbacks. A corrective commit and executable regression tests are being
prepared on that PR's branch; its final evidence belongs in `PULL_REQUESTS.md`.

## Build and repository hygiene

The Git repository now contains full upstream history and has `origin` set to
the user's fork and `upstream` to the original repository. Historical experiment
branches are preserved under `archive/` tags and in a verified pre-cleanup Git
bundle. The old audit workspace has a redirect README; historical evidence is
compressed under `.local/archive/`.

Xcode 26.6 still emitted `RegisterWithLaunchServices` when passed
`REGISTER_WITH_LAUNCH_SERVICES=NO`. The build helper therefore explicitly calls
`lsregister -u` on its exact temporary app before removing the generated build
directory. Checks confirmed temporary registration records were removed.
The ineffective build setting was subsequently removed from the helper.

Compiler logs, raw validation reports and rollback ZIPs stay in ignored `.local/`.
