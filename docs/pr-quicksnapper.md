Closing QuickSnapper retains its last window list, accessibility references and
SwiftUI content graph. This change releases the model's list on close and releases
the hosting view when the fade completes.

The teardown also guards asynchronous work: queued selection and snap callbacks
ignore an empty or closed panel, layout hotkeys ignore a closed panel, and generation
checks stop an old close completion or delayed layout presentation from changing a
newly reopened panel. Deferred hotkey registration/unregistration uses the same
generation check. Snapping hotkeys deliver their work on the main actor.

Validation at `69f1019032cf5e30ae16f4e934ee49393e8903f0`:

- Unsigned Release build passed with Xcode 26.6.
- `scripts/check_quicksnapper_lifecycle.sh` passed 33 executable assertions using
  actual production methods with deterministic UI collaborators. It covers
  closed/empty selection, index clamping, wraparound, stale animation/delay
  callbacks, reopened content preservation and closed layout hotkeys.
- Additional wiring checks verify generation guards on deferred registration
  and open-state guards for Enter/Escape.
- This current validation did not launch an app. Real keyboard/panel interaction
  remains a manual QA check; the model tests do not claim to measure AppKit memory.

The change is independent of the lazy-layout, dwell-animation and support-reminder
PRs. It does not change shortcuts or the persisted settings format.
