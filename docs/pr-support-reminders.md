Thank you for all the work you put into MacsyZones. I appreciate that support
helps sustain the project, so I've kept reminders enabled by default and left
Pro entitlement checks unchanged.

This proposes a way to keep automatic reminders from appearing during an active
window-management interaction, together with an explicit, persistent opt-out.
I hope it makes those interactions smoother while respecting how you want to
support the project.

### Change

- Add a saved preference for automatic support reminders, enabled by default.
- Offer the preference in settings and a disable action in the reminder itself.
- Wait two seconds before presenting, then skip presentation if a drag, snap,
  edit, fit, resize, or left-mouse-button interaction is active.
- Cancel pending presentation when reminders are hidden or disabled, including
  across a quick disable/re-enable sequence.
- Restore the enabled default when settings are reset.

This relates to the interruption reported in #84. The optional settings field
keeps older settings JSON readable with the existing enabled default.

### Validation and remaining checks

- Release build passed at `476a11b`, using Xcode 26.6 with signing disabled.
- The included `scripts/check_support_reminders.sh` passed 87 assertions against
  the production reminder lifecycle and settings schema/load/save/reset code.
  It covers busy-state guards, pending callbacks, disable/re-enable races,
  legacy settings defaults, and settings round-tripping.
- The diff preserves Pro checks and uses a generation token to invalidate stale
  presentation callbacks.
- A manual pass through both controls, persistence after relaunch, and active
  window interactions remains. The tests use a deterministic scheduler, panel,
  and in-memory storage; they do not validate SwiftUI bindings, real focus/timing,
  or filesystem persistence. This is still a draft.

The opt-out is a product decision, and I understand if you prefer a different
approach. I'm happy to narrow this to the interruption prevention or adjust the
wording and behavior to match your preference. Thank you for considering it.
