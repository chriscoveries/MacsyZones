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
| #105 support reminders | `476a11b9a36594f03630f42e8fcd2180d167c963` | Release and 87 production-source assertions passed |
| #106 lazy layout lifecycle | `03f67f19f13b78b85a8c534ba5eab6602bb4b34a` | Release and 139 model assertions passed |
| #107 QuickSnapper follow-up | `69f1019032cf5e30ae16f4e934ee49393e8903f0` | Release and 33 executable assertions passed |
| Stable status-item identity, separate branch | `8d372c1aa4a68671855eec955e4ef350474ab7f1` | Release passed |

On #106, `bash scripts/check_lazy_lifecycle.sh` now tests the checked-out
`UserLayout` class and editing functions against Foundation-only fake window
collaborators. All 139 assertions pass for cold allocation, nonallocating
hide/stop-editing paths, graph reuse and configuration propagation. A missing
`stopEditing` fixture was rejected before Swift execution. The maintained
branch's older revision-selecting runner remains available separately as
`scripts/check_lazy_lifecycle.sh fix/lazy-layout-memory`. Neither runner launches
an app, accesses settings, or tests AppKit rendering, real window ownership,
snapping or multiple monitors.

On #105, `bash scripts/check_support_reminders.sh` passes 87 assertions using
the actual reminder lifecycle and complete settings schema/load/save/reset
implementation. It substitutes an in-memory panel, queued scheduler and storage;
only the reminder UI constructor is replaced, and the settings import uses
Combine in place of SwiftUI. The checks cover busy-state guards, pending/Pro/
enabled gates, stale callback generations, default/missing/null settings keys,
round-tripping true/false, reset and final interval saturation. No real settings
or application is touched. SwiftUI bindings, focus/timing and filesystem
persistence remain UI/integration checks.

Both test additions leave their PRs' application source trees unchanged. Fresh
Release builds passed at the new commits above; the parent independently reran
the 139 and 87 assertions and the existing 33 QuickSnapper assertions.

The first review found that #107's immediate array clear could crash queued
hotkey callbacks. Follow-up `69f1019` guards window selection, queues snapping on
the main actor, prevents closed layout hotkeys from changing layouts, and uses
generation checks for animation completion and hotkey registration. The second
review caught the closed Left/Right path; that was fixed before the final build.

`scripts/check_quicksnapper_lifecycle.sh` on the QuickSnapper branch executes
nine actual production methods and the actual queued Left/Right callback bodies
against deterministic fake panel/animation/delay collaborators. All 33
assertions passed, including empty/closed selection, bounds, wraparound, stale
close completion, stale delayed layout show, and preservation of reopened
content. Supplemental scoped wiring checks cover asynchronous registration and
Enter/Escape guards. These tests do not replace a real panel/keyboard UI pass.

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

## Remaining UI checklist before release

Use the single canonical app and a settings backup during a deliberately planned
installation test; never launch a second test app beside it. The broader #106
and #107 changes are not in the current daily build, so testing today's installed
app cannot validate those PRs.

- #103: repeat drag/dwell/release across layouts, confirm the pulse and selection,
  then sample post-hide CPU after a cooldown.
- #104: launch with existing saved layouts and confirm selection and snapping.
- #105: toggle reminders from both controls, relaunch to check persistence, and
  verify a pending reminder does not interrupt dragging or return after disable.
- #106: exercise zone/grid switching, editing, renaming/removing layouts, hover
  resizers, and screen changes; compare canonicalized settings before/after.
- #107: repeat open/close/reopen with empty and populated window lists, including
  Left/Right, Tab/Shift-Tab, number, Enter and Escape hotkeys around the fade.
- Status item: check position/visibility across relaunch, preserving the same
  bundle identity; do not reset private Control Center state as part of QA.

Record the tested commit, expected/observed result and configuration. Leave
unchecked items explicitly pending instead of interpreting a build as UI QA.
