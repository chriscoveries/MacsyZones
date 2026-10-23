Thank you for creating and maintaining MacsyZones. I appreciate the work that has
gone into it, and I hope this small change helps keep it a little lighter during
everyday use.

### Change

This replaces the layout switcher's repeating dwell animation with a bounded
two-repeat animation. It addresses the post-hide CPU activity described in #83,
without changing the layout-switching logic.

The change is one line in `Switcher.swift`. No profiling hooks or unrelated
optimizations are included.

### Evidence and validation

- Release build passed at `4d30fcf`, using Xcode 26.6 with signing disabled.
- Earlier local paired measurements recorded mean post-hide CPU of 16.390% with
  the repeating animation and 0.750% with the bounded animation. Those runs used
  the same temporary dwell/hide probe, five pairs, a ten-second cooldown, and
  discarded the first `top` interval. The probe is not part of this PR.
- Those are historical measurements from a specific setup, not a new benchmark
  of this revision or a guarantee of the same reduction on every Mac.
- A final manual check of the visible dwell pulse and repeated opening remains.

Thanks for taking a look. I'm happy to adjust the pulse duration or approach to
fit the interaction you want for MacsyZones.
