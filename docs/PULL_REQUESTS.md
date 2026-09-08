# Upstream pull requests

Snapshot checked September 8, 2026. All five PRs target `rohanrhu/MacsyZones:main`
from `eafire15/MacsyZones`. They already exist; update their branches instead of
opening duplicate PRs. GitHub reported all five open and mergeable, with no
reported status checks. Mergeability is not a test result.

| PR | Branch | GitHub status | Scope and remaining gate |
| --- | --- | --- | --- |
| [#103 Stop layout switcher animation after dwell](https://github.com/rohanrhu/MacsyZones/pull/103) | `fix/layout-switcher-idle-cpu` | Draft | Stop hidden/dwell animation work; verify dwell completion and repeated opening. |
| [#104 Avoid loading layout windows twice at launch](https://github.com/rohanrhu/MacsyZones/pull/104) | `fix/avoid-duplicate-layout-load` | Draft | Small startup fix; overlaps the duplicate-load removal included in #106. |
| [#105 Make automatic support reminders non-intrusive](https://github.com/rohanrhu/MacsyZones/pull/105) | `feat/nonintrusive-support-reminders` | Draft | Optional automatic reminders; verify enabled/disabled behavior and persistence. |
| [#106 Lazily materialize layout windows](https://github.com/rohanrhu/MacsyZones/pull/106) | `fix/lazy-layout-memory` | Open, non-draft | Broader window lifecycle changes; current UI smoke coverage remains a release gate. |
| [#107 Release QuickSnapper content when closed](https://github.com/rohanrhu/MacsyZones/pull/107) | `fix/release-quicksnapper-content` | Open, non-draft | Follow-up `69f1019` fixes queued hotkeys and close/reopen races; Release and 33 execution assertions pass; real keyboard/panel QA remains. |

## Integration order

Prefer the small independent fixes #103 and #104 first; #105 is independent and
can be considered separately. #106 already includes the behavioral equivalent
of #104. After #104 merges, integrate current `upstream/main` into #106 and
reconcile that overlap so its remaining diff describes only the lifecycle work.
Do not apply both duplicate-load removals blindly. #107 is independently
reviewable; if combined with #106 later, smoke-test their combined lifetime
behavior before promoting that combination to `local/maintained`.

## Updating existing PRs

Keep each fix on its named branch and commit only its intended source changes.
Do not switch a branch underneath another worker. Temporary review worktrees
belong inside ignored `.local/`; remove them when finished. The canonical
working tree should return to `local/maintained`.

After reviewing and committing an update, build that exact branch with the
canonical build script, which does not require checking it out:

```sh
scripts/build.sh --check fix/layout-switcher-idle-cpu
scripts/build.sh --check fix/avoid-duplicate-layout-load
scripts/build.sh --check feat/nonintrusive-support-reminders
scripts/build.sh --check fix/lazy-layout-memory
scripts/build.sh --check fix/release-quicksnapper-content
```

Run only the builds relevant to the changes being pushed. Then use the matching
ordinary push; these commands update the existing PRs and refuse a non-fast-forward
replacement:

```sh
git push origin fix/layout-switcher-idle-cpu
git push origin fix/avoid-duplicate-layout-load
git push origin feat/nonintrusive-support-reminders
git push origin fix/lazy-layout-memory
git push origin fix/release-quicksnapper-content
```

Refresh remote state before preparing updates. If a branch has diverged, inspect
both histories and preserve others' work. Prefer adding a corrective commit or
merging current upstream over rewriting an already published PR. Update PR
descriptions with the final behavior and actual validation, including any UI
checks that remain. Draft/non-draft status should reflect that evidence.

The maintained bundle ID, signing configuration, update protection, local login
registration workflow, packaging scripts, and fork documentation belong on
`local/maintained`. They are not part of these optimization PRs.

## Additional prepared branch

`fix/tahoe-status-item-identity` is now a standalone two-line change directly on
`upstream/main`, rather than the earlier combined local build. It passed a clean
Release build at `8d372c1`. [Draft PR text](pr-status-item.md) describes the precise
scope without claiming this alone repairs every missing icon.
This branch and `local/maintained` have been pushed to the user's fork; installed
source tags are also pushed. An upstream PR for the status-item change has not
yet been opened.

```sh
git push origin fix/tahoe-status-item-identity
gh pr create --repo rohanrhu/MacsyZones --base main \
  --head eafire15:fix/tahoe-status-item-identity --draft \
  --title 'Give the menu-bar item a stable autosave identifier' \
  --body-file docs/pr-status-item.md
```

The creation command is prepared for the next upstream submission; no duplicate
of an existing PR is needed. See [VALIDATION.md](VALIDATION.md) for the exact
revisions built and the distinction between model tests and remaining UI checks.
