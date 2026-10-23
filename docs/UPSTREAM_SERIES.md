# Proposed upstream contribution series

MacsyZones is maintained by **Oğuzhan Eroğlu**. These are candidate changes to
offer for his review, after local testing and Chris's explicit approval. The
fork retains its own packaging, configuration and release workflow. **No
upstream branches or pull requests have been created from this plan.**

Start from upstream `rohanrhu/MacsyZones` 3.1.1 (`2d5ce44`), refreshing `main`
before preparing each proposal. Extract the smallest relevant source diff;
the fork's combined commit history is not itself a clean upstream patch series.
Keep one purpose per PR, its own tests, and plain-language AppKit/AX comments.

| Order | Proposed PR | Primary change | Dependency |
| --- | --- | --- | --- |
| 1 | `fix/snap-frame-corrections` | Validate AX window frames, bound retries, prevent stale corrections after a newer snap or manual drag; retain per-app minimum-size fallback. | Independent |
| 2 | `perf/fast-snap-overlay` | Remove unnecessary overlay fades, redundant AX reads/updates and unchanged-frame writes on the hot drag path. | Review against 1 to avoid mixing placement and latency fixes |
| 3 | `feat/snap-key-delay` | Give Snap Key a separate delay setting with zero-delay default; start timing on a genuine move event and cancel pending activation safely. | Prefer 2 first; isolate Settings/Popover and timer changes |
| 4 | `fix/overlapping-zone-editor` | Cycle covered zones on modifier-click, supporting an otherwise unreachable editor window. | Independent of 3; port only the editor hit-testing and event routing |
| 5 | `fix/retired-window-lifecycle` | Detach and close deleted zone/grid windows; break ownership cycles and cancel resizer work. | Independent, but smoke-test with 4 |
| 6 | `perf/lazy-zone-editor` | Build editor NSWindows and toolbar only on entry to Edit Zones; dispose them on exit while retaining snap overlays. | Stack on 5 for review, then rebase after it merges |

The order is a review strategy, not a release schedule. The UI tests below
could move an item later or lead to a smaller additional patch. Grouping
corrections with performance work would obscure the observed behaviour changes.

## Existing fork review checkpoints

- Window teardown is in [`sync/memory-lifecycle-20261024`](https://github.com/chriscoveries/MacsyZones/tree/sync/memory-lifecycle-20261024), built successfully by the [fork's macOS CI](https://github.com/chriscoveries/MacsyZones/actions/runs/39970254733).
- Lazy zone editor is developed as a *stacked* fork-only change on top of that
  teardown checkpoint. Compare the two branches to inspect editor changes in
  isolation. Its own CI and real-macOS UI test remain the acceptance gates.
- The snap-speed, timer and overlap work currently coexist on the integration
  branch. Before submission, reconstruct items 1–4 against upstream so each
  PR contains only the advertised changes. Avoid cherry-picking combined
  commits that touch several behaviours at once.

## Reviewer evidence to gather

- **1: Alignment:** exact before/after window rectangles for normal and
  minimum-size-constrained apps; rapidly snap twice while a correction is
  pending; repeat across screens and Spaces.
- **2: Latency:** overlay appearance and mouse-to-hover timing with a fixed
  workload, sampled before and after on the same Mac; capture idle CPU too.
- **3: Modifier timing:** default zero, custom delay, release during delay,
  settings migration and changing the key mid-drag.
- **4: Editor selection:** partly overlapping and fully nested zones, repeated
  modifier-click cycling, drag/resize of the selected zone and plain clicks.
- **5: Window retirement:** repeated zone and layout delete/undo, Save and
  Cancel; inspect NSWindow/NSHostingView counts after cleanup.
- **6: Lazy editor:** first and repeated Edit Zones entry time, Save/Cancel,
  smart gap, keyboard modifiers, screen changes, memory at idle and after exit.

Keep screenshots/logs concise. The existing unsigned Release CI build and
model assertions are useful compiler and source checks; AppKit behaviour and
the approximately 250 MB memory observation still need a controlled macOS run.

## Fork-only work

Keep the bundle identity, signing team, login item registration, update guard,
personal paths, release scripts, local readmes and optional support-reminder
setting in this fork. Upstream already merged earlier lazy-layout/QuickSnapper
improvements, so do not resubmit them. The historical PR map lives in
[PULL_REQUESTS.md](PULL_REQUESTS.md).

Prepare drafts and branch comparisons privately. Obtain Chris's authorisation
before opening a PR, pushing to the upstream repository, or contacting its
maintainer. Credit the original design and describe measured results precisely.
