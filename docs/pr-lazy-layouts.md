Thank you for creating MacsyZones and sharing it with the community. This is a
broader optimization for configurations with several saved layouts: the aim is
to avoid constructing window objects until a layout actually needs them. I hope
it can help reduce unnecessary startup work and memory use.

### Change

- Create each layout's window graph on demand, keeping the existing accessors
  as the points that materialize it.
- Let hide/reset/stop-editing paths inspect already-created objects without
  constructing unused layouts.
- Create cross-screen warning panels when a warning is needed.
- Skip snap-resizer hover work for hidden or non-current layout windows.
- Remove the duplicate startup load, which is also proposed separately in #104.

The persisted layout format is unchanged. Preserving switching, editing,
snapping, and multi-monitor behavior is a validation requirement for this work.

### Current validation

- Release build passed at `03f67f1`, using Xcode 26.6 with signing disabled.
- The included `scripts/check_lazy_lifecycle.sh` passed 139 assertions using
  production layout/editing code with deterministic window collaborators. It
  checks deferred construction, nonallocating hide/stop-editing paths, reuse,
  and configuration propagation.
- Run `bash scripts/check_lazy_lifecycle.sh` directly from this PR's checkout;
  no fork-specific branch is needed. Extraction fails if required source
  boundaries or editing functions are missing. An isolated missing-method
  negative check was rejected before Swift ran.
- These model tests do not exercise AppKit rendering, real window ownership,
  keyboard interaction, or multiple monitors. A real UI smoke pass remains.

### Historical performance observations

Earlier local measurements with eight layouts and 58 zones recorded physical
footprints of 390.9 MB for the eager baseline, 228.9 MB with only the duplicate
load removed, 23.1 MB at cold lazy startup, and 65.3 MB after materializing the
active 13-zone layout.

These figures describe different materialization states from that historical
experiment. They are not newly repeated measurements of this exact revision,
steady-state guarantees, or proof that every UI path is correct. Earlier
long-running combined-build observations are also separate from validation of
this standalone PR.

### Review and integration

#104 is the smaller independent fix and can land first. If it does, #106's
overlapping startup change should be reconciled before merging. This PR excludes
the dwell-animation change, support-reminder changes, and QuickSnapper teardown.

Thank you for considering this larger change. I'm happy to split it further or
adapt the lifecycle approach if that would make it easier to review and maintain.
