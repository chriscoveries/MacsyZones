Thank you for creating and maintaining MacsyZones. While investigating menu-bar
behavior on Tahoe, I found this small change that may be useful independently
of my local recovery steps. I hope it helps make the status item's saved state
more explicit.

### Change

Set `NSStatusItem.autosaveName` to a stable value derived from the app's bundle
identifier. This is a two-line addition in `createTrayIcon()` that gives each
app identity an explicit namespace for its status-item persistence.

### Scope and validation

- Release build passed at `8d372c1`, using Xcode 26.6 with signing disabled.
- This does not change the product bundle ID, reset preferences, override the
  user's visibility choice, or modify Control Center's private state.
- My local missing-icon recovery also involved a fresh bundle identity. That
  recovery is not evidence that this two-line change alone fixes missing icons.
- This is proposed as a small persistence improvement, not a general Tahoe
  menu-bar repair.

Thanks for taking a look. If there is a preferred autosave naming convention or
compatibility concern, I'm happy to adjust it.
