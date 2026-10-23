# Validation — 2026-09-08

## Upstream 3.1.1 integration — 2026-10-23

The maintained fork has been rebased in source onto upstream 3.1.1. Its fork
identity, update protection and optional reminders were reconciled. Subsequent
snapping edits replace repeated unconditional delayed position/size writes with
bounded frame-checked retries, prevent older retries from overriding newer snaps,
restrict failed-window reacquisition to the original window ID, and derive a
borderless zone's AX target directly from its AppKit frame. Hover selection
updates now avoid redundant SwiftUI publishes and window raises.

These changes still require a clean Xcode Release build and macOS UI checks.
The first CI compilation exposed two-argument SwiftUI `onChange` calls that
require macOS 14, while upstream's recommended deployment target resolved lower.
The maintained project now declares macOS 14 as its minimum target.
Confirm zone and grid placement, QuickSnapper, multi-monitor movement, per-app
minimum sizes, repeated snapping before previous corrections finish, drag-hover
visual response, and start-at-login. Capture intended and observed window frames
for any alignment discrepancy. The September installed-build results below are
historical and must not be treated as validation of this integration.

## Fast drag path — 2026-10-23

The maintained fork's performance pass removes the 350 ms fade from normal
zone/grid overlay show and hide and the 250 ms layout-switcher fade. Immediate
hide also eliminates stale fade completion callbacks hiding a reopened overlay.
Ordinary unsnapped drags no longer materialize lazy zone windows merely to
clear hover state. An unplaced window movement avoids the AX role, subrole and
position reads previously made on every processed move notification (up to
120 per second). The remaining position read happens when a placed window
needs previous-size recovery. Hover uses zone frames directly; grid-cell
changes only publish when the cell changes. The grid NSHostingView is reused
while size/rows/columns are unchanged. App activation now schedules one scan,
and window recovery only queries the owning PID's AX window list. A fresh
manual drag cancels any remaining frame correction for that same window ID.
Repeated window scans now check the already-observed window ID before asking
the app for AX role/subrole, and unchanged overlay frames skip `setFrame`.
The release handler now resolves the hovered zone at mouse-up and clears its
saved target state at both mouse-down and mouse-up. Previously an out-of-zone
release could reuse the last hovered zone, including across drags. Hiding a
layout now also clears its hover highlight explicitly.

These are source-path and animation-duration comparisons, **not measured wall
clock improvements**. The CI Release build and model checks validate the Swift
source but cannot measure a running Accessibility client on a desktop. On the
canonical Mac, measure (1) snap-key-to-overlay visibility, (2) hover update
latency while dragging between zones, (3) idle CPU with Stage Manager, (4)
frame error and settling time after zone/grid placement, and (5) the first
snap after screen or Space changes. Run each on single and dual displays,
including an application with a constrained minimum window size. Treat UI
checks as pending until recorded against the exact installed commit.

## Snap-key delay and overlapping editor zones — 2026-10-23

The Snap Key setting now has its own 0–2000 ms delay slider (100 ms steps),
matching the Modifier Key control. Its default is **0 ms**; older settings
files load this default without migration. The timer begins when an actual
window-move notification is observed while the snap key is held. Releasing
the snap key, releasing the mouse, or entering Edit Zones cancels a pending
timer. Snap-key activation is still subject to macOS Accessibility move-event
delivery; the zero-delay setting adds no application-side waiting.

In Edit Zones, **Shift-click** (the default Snap Key), **Modifier Key-click**,
or **Option-click** on an overlap brings the next editor zone at that point
to the front. Repeated modified clicks cycle the overlapping zones in zone
number order; the following ordinary drag edits the selected zone. The click
is consumed only when at least two visible editor zones contain that point.
For custom snap/modifier keys, use the configured key or Option.

The macOS GUI acceptance pass is pending. Check zero-delay appearance on a
Shift-drag, Shift held before and after drag start, cancellation if Shift or
mouse is released during a nonzero delay, overlay removal after Shift release
mid-drag, and a Shift-drag after switching Spaces. In Edit Zones, create two
partly overlapping zones and cycle each into the foreground through modified
clicks, then drag and resize each. Also check three fully nested zones,
unmodified clicks, modifier-click outside overlaps, and custom Snap Key and
Modifier Key settings. Build-only CI cannot verify event routing or window
stacking in a live macOS session.

The first CI build compiled both architectures. Its lazy-layout model fixture
did not yet define the newly called snap-key cancellation helper, so the
isolated test compilation failed. The fixture now models that helper and
asserts cancellation for cold-layout editing paths. Re-run the model tests on
the amended commit before treating CI as passing.

## Window teardown and memory — 2026-10-24

The source review found retained window graphs after deleting a grid layout
and after deleting or cancelling editor zones. Terminal teardown now detaches
zone child windows, releases SwiftUI hosting views, removes resizer callbacks
and the layout's mouse monitor, and closes the grid backing window. Section
backreferences and editor callbacks no longer strongly own their parent.
Ordinary layout hiding remains cached to preserve fast switching. The updated
lazy-layout model tests check disposal of cold and warm zone/grid graphs and
re-creation after disposal (144 assertions). The unsigned macOS Release build
and both lifecycle checks passed in [fork CI run 39970254733](https://github.com/chriscoveries/MacsyZones/actions/runs/39970254733).
Live editing/UI validation remains pending.

Capture the user-observed ~250 MB baseline with the same Activity Monitor
metric before and after installing this source. Repeat create/delete/save/cancel
editing, switch among layouts, test live snap resizers, and use Instruments to
count retained NSWindow/NSHostingView objects. See [MEMORY.md](MEMORY.md).
No MB reduction has yet been measured.

## Lazy zone editor — 2026-10-24

The next fork-only change delays construction of zone editor windows, their
SwiftUI views and the editor toolbar until Edit Zones starts. Exit from editing
detaches and closes these windows, while the borderless snap overlays remain
cached. Existing editor geometry helpers can read the snap-frame fallback when
an editor has not yet been created. This should reduce idle retained editor
graphs after normal snapping and after an editing session. The editor may take
longer to appear on each entry, so time that action separately from dragging.

Build and model-test results for this specific change must be recorded against
its eventual remote SHA. Then verify Save/Cancel, adding and deleting zones,
overlap cycling, editor-bar commands and moving/resizing across two screens on
the installed signed app. The user-observed 250 MB has not yet been measured
against this change.

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
