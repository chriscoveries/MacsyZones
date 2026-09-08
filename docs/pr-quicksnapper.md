Thank you for the work behind MacsyZones and QuickSnapper. I hope this change
helps release some content that no longer needs to stay around after the panel
closes, while keeping the close/reopen interaction reliable.

### Change

The panel's window list is cleared on close, and its hosting view is released
when the fade finishes. The follow-up also handles asynchronous work that can
arrive during teardown:

- Selection and snapping ignore empty or closed panels and clamp stale indices.
- Layout hotkeys ignore a closed panel.
- Generation checks prevent an old fade completion or delayed layout display
  from altering a newly reopened panel.
- Deferred hotkey registration and unregistration use the same generation check.
- Snapping hotkeys deliver their work on the main actor.

The fade is preserved. This does not change shortcuts or the persisted settings
format and is independent of the lazy-layout and other optimization PRs.

### Validation and remaining checks

At `69f1019`:

- Release build passed with Xcode 26.6 and signing disabled.
- The included `scripts/check_quicksnapper_lifecycle.sh` passed 33 executable
  assertions using production methods and deterministic collaborators.
- Coverage includes closed/empty selection, bounds, wrapping, stale callbacks,
  preservation of reopened content, and closed layout hotkeys.
- Supplemental wiring checks cover deferred registration and Enter/Escape guards.

These checks did not launch an app or measure AppKit memory. A real keyboard and
panel close/reopen pass remains before treating the change as fully validated.

Thanks for reviewing it. I'm happy to adjust the teardown strategy if there is
a lifecycle convention you'd prefer to keep here.
