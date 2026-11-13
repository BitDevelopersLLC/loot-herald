# Loot Herald maintenance plan

WoW Forever is patched often. In its first month it shipped builds 70532,
70630, 70790 and 70938. This plan keeps Loot Herald correct with as little
manual work as possible: **robots notice changes, a human checks them in game,
and the data lives in a few small files.**

## What can go stale, and where it lives

| What changes in a patch | Where it lives in Loot Herald | How we find out |
|---|---|---|
| Game version (interface number) | `## Interface:` in `LootHerald/LootHerald.toc` | **Automatic:** the game watcher opens a PR |
| Hotfix builds (same version) | nothing to edit, unless something broke | **Automatic:** a comment on the "Game build log" issue |
| Addon functions Blizzard changes or removes | `Core/*.lua` | `/lh selftest`: "Missing game functions" |
| New stat types on items | `API_STAT_MAP` in `Core/ItemReader.lua`, then `Data/Profiles.lua` | `/lh selftest`: "Unknown stat keys" |
| Tooltip wording for "Equip:" bonuses | `Data/TooltipPatterns.lua` | `/lh selftest`: "Equip lines that look like stats" |
| Class balance (what each role values) | `Data/Profiles.lua` weights | Patch notes, plus player reports |
| Hit caps | defaults in `Core/Init.lua` (`hitCapMelee`, `hitCapSpell`) | Patch notes, community testing |
| Armor or weapon rules, new class/race pairings | `Data/ClassRules.lua`, `Data/Profiles.lua` | Patch notes. Unknown classes fall back to generic profiles until added |
| GitHub Actions versions | `.github/workflows/*.yml` | **Automatic:** Dependabot PRs, monthly |

`ns.DATA_REVIEWED_FOR` in `Data/Profiles.lua` records the game version the
data was last checked against. `/lh selftest` warns players when the game is
newer.

## The automation

1. **Game watcher** (`.github/workflows/game-watch.yml`, every 6 hours). It
   reads the live WoW Forever version from Blizzard's public patch server
   (`us.patch.battle.net:1119/wowf/versions`), using `tools/check_game_version.py`.
   - **New game version** (for example 1.60.1 → 1.61.0): opens a PR that adds
     the new interface number to the `.toc`, plus an issue with the patch-day
     checklist.
   - **New build of the same version:** adds a comment to the "Game build log
     (automatic)" issue and records the build in `tools/known-builds.json`.
   - Run it by hand any time: **Actions → Game version watch → Run workflow**.
     Locally, `python tools/check_game_version.py` does a dry run that changes
     nothing.
2. **CI** (`ci.yml`) runs the Lua and Python tests on every push and builds the
   release zip from tags.
3. **Dependabot** keeps the GitHub Actions versions current.

One-time repo setting the watcher needs: **Settings → Actions → General →
"Allow GitHub Actions to create and approve pull requests"**.

Two GitHub limits to know about:
- **Scheduled workflows stop after 60 days with no repo activity.** The
  watcher's own build-log commits normally keep it alive. If GitHub emails
  that it was disabled, re-enable it on the Actions tab.
- **PRs opened by the bot don't trigger CI.** Before merging a TOC PR, run the
  tests locally, or push any small commit to the PR branch.

When Blizzard publishes a WoW Forever test server (PTR), add its product code
to `PRODUCTS` in `tools/check_game_version.py`. That gives warning before a
patch goes live.

## Routine

**Every hotfix build** (about 5 minutes, triggered by a build-log comment)
- [ ] Log in and run `/lh selftest`. If anything is flagged, paste it into an issue.

**Every game patch** (1-2 hours, triggered by the patch issue and PR). Work through the checklist in that issue:
- [ ] Read the patch notes for class, talent, stat, item and dungeon changes.
- [ ] Run `/lh selftest` on two or more characters (a caster and a melee). Paste the results into the issue.
- [ ] Run `/lh test` and one real dungeon. Check that tooltips still show the Loot Herald line.
- [ ] Update the data files above as needed. Run `lua tests/run_tests.lua`.
- [ ] Set `ns.DATA_REVIEWED_FOR` to the new version.
- [ ] Merge the TOC PR. Bump `## Version` and update the CHANGELOG.
- [ ] Tag the release (`git tag v0.1.1 && git push --tags`).

**Each new content phase** (new dungeons or raids, new class/race pairings)
- [ ] Use `/lh debug` on a few new items from each new dungeon to check they read correctly.
- [ ] Review the weights for roles the new gear is aimed at.

**Monthly**
- [ ] Triage GitHub issues and CurseForge/Wago comments. Label weight suggestions and "good first issue".
- [ ] Merge Dependabot PRs once CI passes.

**Quarterly**
- [ ] Review all weights against current community guides.
- [ ] Skim Blizzard's UI and addon developer posts for API changes that are coming.

## Versioning
- **Patch** (0.1.**1**): data-only fixes, such as weights, patterns or a TOC bump.
- **Minor** (0.**2**.0): new features.
- Every release gets a CHANGELOG line and a git tag. CI builds the zip, and
  later uploads to CurseForge and Wago (see LAUNCH-CHECKLIST.md).

## Working with Claude on maintenance
Open this project in Claude Code and give it the patch issue, the
`/lh selftest` output and a link to the patch notes. It can update the data
files, add tests and prepare the release. The checklist in each issue is the
script to follow.
