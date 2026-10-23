# Memory ownership and measurement

MacsyZones is created and maintained upstream by Oğuzhan Eroğlu. This fork is
an experimental integration branch. Its memory changes stay here until they
have been tested in the running app and reviewed for upstream suitability.

## What is retained

- `UserLayout` creates an AppKit window graph lazily. A hidden layout keeps its
  graph for fast reopening. Cache eviction would trade latency for memory; it
  needs measurements and a defined policy before implementation.
- `LayoutWindow` owns a full-screen overlay, an editor bar and two NSWindows
  per zone. Their hosting views retain SwiftUI models. A retired zone must
  detach its child windows and release the hosting views. `SectionWindow`
  references its parent weakly; button callbacks also capture the parent weakly.
- Removing a layout calls `UserLayout.dispose()`. Both zone and grid layouts
  close their windows, while normal `hide()` preserves caches. Deleting an
  unsaved zone or cancelling an added zone also releases its editor windows.
- Live-snap resizers can schedule callbacks and retain zone models. Layout
  disposal cancels these callbacks and drops the resizer graphs.
- `WindowObserverManager` keeps AX observers for running applications and
  removes them on application termination. Observe its size over a long session
  before changing observation coverage or sacrificing responsiveness.

## Measurements pending on the canonical Mac

The user has observed approximately **250 MB** for the running app. The units
and attribution of that observation have not been captured. An unsigned CI
build and model tests cannot measure retained AppKit windows or process memory.

Capture a stable baseline after launch and repeat each workload three times:

1. Idle for two minutes, record Activity Monitor **Memory**, `ps` RSS and
   `vmmap` physical footprint for the single installed MacsyZones PID.
2. Open and close the tray and QuickSnapper repeatedly, then wait two minutes.
3. Enter and cancel zone editing 20 times, adding and deleting a temporary zone
   each time. Repeat with Save. Count NSWindows and NSHostingViews in Instruments.
4. Duplicate and delete a temporary zone layout and a temporary grid layout;
   observe whether retained editor windows return to the pre-test count.
5. Cycle all saved layouts, then idle again. A steady retained cache differs
   from monotonically growing allocations.

Use the **same signed installed app** for baseline and follow-up measurements.
Record commit SHA, macOS version, number of layouts/zones/displays, uptime and
whether the app was already used for editing. Never launch a second app beside
the canonical copy. Instruments Allocations and the Xcode memory graph are the
useful next tools if memory keeps growing after temporary layouts are deleted.

The target is to eliminate retention after deletion and keep drag/snap latency
fast. A lower idle footprint would be valuable, but the current code changes
have **no measured MB saving** yet. Do not promise a percentage reduction.

## Upstream readiness

Review the teardown changes for AppKit child-window lifetime, SwiftUI hosting
view ownership, timer cancellation and re-entry after editing. Confirm a clean
Release build, model checks, and GUI behaviour on one and two displays.
Prepare a focused diff against current upstream with a minimal reproducer and
before/after measurements. Ask Chris before creating or pushing any upstream PR.
