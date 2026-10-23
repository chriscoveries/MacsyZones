# Maintained MacsyZones fork

This is the canonical repository: `/Users/chrisd/Documents/MacsyZonesFork`.
Read `docs/FORK.md` and `docs/PULL_REQUESTS.md` before changing packaging,
installation, startup, or upstream branches.

- Keep `local/maintained` as the day-to-day integration branch. `origin` is
  `chriscoveries/MacsyZones`; `upstream` is `rohanrhu/MacsyZones`. Do not push
  anything upstream without Chris's explicit authorization. Keep local packaging,
  machine configuration, and fork notes in this fork only.
- Preserve the installed identity `local.chrisd.macsyzones.20260903` and signing
  team `U454V8N2L2`. The working Tahoe menu-bar registration belongs to that
  identity. Do not bump it as a routine build step or replace it with an upstream
  release archive.
- There must be one installed app: `/Applications/MacsyZones.app`, and at most
  one running MacsyZones process. Never launch build products, test copies, or
  archived apps. Do not create parallel visible `.app` bundles.
- Use `scripts/build.sh` and `scripts/install.sh`. Builds use disposable hidden
  storage and retain ZIPs, logs, and provenance under ignored `.local/`. Do not
  add DerivedData, binary archives, private settings, or reports to Git. Remove
  temporary worktrees when finished; keep review work inside `.local/`.
- The first Finder launch of this identity already succeeded. For updates using
  the same identity, verify the installed signature and source commit before
  launching the canonical app. A genuinely new identity would require a separate
  recovery plan, including the first-launch attribution concern.
- Native `SMAppService` registration is the start-at-login mechanism. Do not add
  a second LaunchAgent, login item, or background launcher. Preserve the fork's
  protection against upstream in-app replacement.
- Upstream merged #103, #104, #106 and #107 in September 2026 and reverted #105.
  The original contribution notes are historical. Build the exact committed
  revision; never describe a build as a completed UI smoke test. Do not force-push
  without explicit need and authorization. Preserve a named backup of the old
  tip before changing the maintained branch's history.
- Other agents may be working here. Preserve their changes, coordinate ownership,
  and avoid switching shared branches or touching unrelated repositories.
