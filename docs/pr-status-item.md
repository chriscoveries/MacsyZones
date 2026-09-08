# Give the menu-bar item a stable autosave identifier

MacsyZones currently lets AppKit assign an automatic name to its status item.
Set `NSStatusItem.autosaveName` to a stable value derived from the bundle ID so
position and visibility persistence have an explicit namespace for each app
identity. The change is two lines in `createTrayIcon()`.

This does not change the product bundle ID, reset preferences, override the
user's menu-bar visibility setting, or repair Control Center's private state.
A local Tahoe recovery used a new bundle identity as well as this change;
that recovery is not evidence that the autosave-name change alone fixes every
missing-icon issue.

Validation: unsigned Release build passed on Xcode 26.6 at
`8d372c1aa4a68671855eec955e4ef350474ab7f1`.
