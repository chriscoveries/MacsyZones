# Maintained fork

The canonical source is `/Users/chrisd/Documents/MacsyZonesFork`, on
`local/maintained`. The only installed app belongs at
`/Applications/MacsyZones.app`. `origin` points to
<https://github.com/eafire15/MacsyZones>; `upstream` points to
<https://github.com/rohanrhu/MacsyZones>. Keep upstream contributions on the
separate branches listed in [PULL_REQUESTS.md](PULL_REQUESTS.md).

The maintained branch contains the idle animation fix, removal of the duplicate
startup layout load, optional support reminders, the Tahoe status-item autosave
identity fix, protection against upstream replacement, and the local build and
startup workflow. The broader lazy-layout and QuickSnapper PRs are separate;
their presence in this repository does not mean they are installed.

## Identity and provenance

Preserve bundle ID `local.chrisd.macsyzones.20260903` and signing team
`U454V8N2L2`. This identity's first Finder launch restored the menu-bar icon on
September 3, 2026. Routine updates retain it. The custom build disables upstream
in-app updates because installing an upstream release would overwrite the
identity and local changes.

Run `scripts/status.sh` to inspect the current branch, installed signature,
embedded source revision, running processes, and unpacked repository apps.
New release builds embed `MacsyZonesSourceCommit`, `MacsyZonesSourceTree`, and
`MacsyZonesSourceRepository` in the installed app's `Info.plist`. Compare those
values with Git; the branch name alone is not proof of what is installed.

## Build and update

Commit the intended source revision first: the build script archives a committed
Git revision and excludes uncommitted changes. Run from the canonical repository:

```sh
scripts/build.sh --check local/maintained
scripts/build.sh --release local/maintained
scripts/install.sh local/maintained
scripts/status.sh
```

`--check` performs a Release build and removes the generated app. `--release`
uses the maintained bundle identity, signs the app, embeds source provenance,
and keeps only `.local/releases/<commit>/MacsyZones.zip`. It requires Xcode and
the configured Apple Development signing identity. Build logs are in
`.local/reports/`.
Build cleanup explicitly unregisters the temporary app from Launch Services
before removing it, because Xcode registers application products even inside
hidden build directories. The release mode also rejects revisions predating
the maintained fork's updater protection.

The installer verifies the release identity, signature, signing team, and source
commit. It archives the previous installed app and ordinary settings separately
under `.local/backups/`, stops the
canonical process, replaces the app in place, and leaves it stopped. It aborts
if another MacsyZones process is running from an unexpected path. After checking
status, launch MacsyZones from Finder → Applications.

## Start at login

The maintained app uses macOS's native `SMAppService.mainApp` registration. After
installation, while the app is stopped, this launch requests registration:

```sh
/usr/bin/open /Applications/MacsyZones.app --args --enable-start-at-login
```

If it is already running, quit through its menu before using this command so
the launch argument reaches a new process. Do not use `open -n`. Inspect System
Settings → General → Login Items & Extensions for the native login item and any
required approval. A successful registration request and an actual login test
are separate checks; only a logout/login or restart confirms automatic launch
end to end. Check that exactly one MacsyZones process and one menu-bar icon
remain after that test.

## Storage hygiene

`.local/` is ignored local storage for release ZIPs, backups, reports, temporary
reviews, and historical archives. Old work directories are archival evidence,
not alternate canonical repositories or launch targets. Keep recoverable app
backups compressed. Never unpack them into Applications or a searchable work
folder as a second installation. The build scripts clean up generated apps on
exit; after an interrupted build, inspect leftover temporary directories before
removing them.

This repository overrides the machine's ignore-all Git setting locally, so new
source files appear in `git status`. Its own `.gitignore` excludes generated and
private artifacts. A complete pre-cleanup Git bundle and the verified historical
optimization ZIP are retained in `.local/archive/`; old generated Xcode caches
and redundant historical folders were moved to Trash on September 8.

The lazy-layout PR changes window creation and teardown across multiple paths.
Keep it out of the day-to-day installation until current UI checks cover layout
editing, dragging, screen changes, snap-resizer behavior, and repeated show/hide
cycles. A source review or successful compiler run does not establish these
behaviors.
