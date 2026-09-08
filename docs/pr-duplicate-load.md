Thank you for making MacsyZones available and continuing to maintain it. I found
a small opportunity to avoid repeated startup work, and I hope this is a useful,
easy-to-review contribution.

### Change

This removes the extra `userLayouts.load()` call from
`applicationDidFinishLaunching`. The global `UserLayouts` instance already loads
through `UserData.init()`, so the later call builds the saved layouts' window
graphs a second time.

The diff removes one line. It leaves the initialization path and persisted data
format unchanged.

### Evidence and validation

- Release build passed at `4af86df`, using Xcode 26.6 with signing disabled.
- Earlier local comparisons using the same saved layouts recorded 381 app
  windows before the change and 191 afterward, with physical footprint changing
  from 400.3 MB to 226.1 MB. Window counts came from
  `CGWindowListCopyWindowInfo`, filtered by PID; footprint came from `vmmap`.
- These are historical measurements from that configuration, not universal
  memory expectations or newly repeated measurements of this revision.
- A final launch check with the saved layouts remains on the current checklist.

### Relationship to #106

The lazy-layout PR currently includes the same removal. This PR can be reviewed
independently; if it lands first, that overlap should be removed from #106's
remaining diff.

Thanks for your time. I hope this small reduction in startup work helps.
