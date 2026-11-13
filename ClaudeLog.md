# ClaudeLog: Loot Herald

## [2026-11-13]

### Changes Made
- Researched WoW Forever (launched 2026-11-04): Mainline addon API, interface 16001, install folder `_forever_`, Need/Greed/Pass dungeon loot, merged Hit/Crit stats.
- Built the addon (first called "WoW Dungeon Drop"):
  - 28 class/spec/role profiles with stat weights, plus generic fallbacks
  - item reading from the API and tooltip text, slot comparison, armor/weapon rules
  - role picker on dungeon entry
  - Warcraft-themed roll alerts with Need/Greed/Pass buttons and a timer
  - tooltip verdict line, settings panel, and the /lh commands
- Renamed to **Loot Herald**. "WoW" is Blizzard's trademark and "Dungeon Drop" is crowded (board game, mobile games). The owner's USPTO search found no LOOT HERALD mark. License: MIT.
- Added first-release features: the plain-English "why" line, the group check (who else can use a drop), the Bind on Equip reminder, and hit cap awareness.
- Added the opt-in group-chat Need announcement (`/lh announce`, `/lh post`), which respects Blizzard's chat lockdown.
- Added the maintenance system:
  - `tools/check_game_version.py` plus the `game-watch.yml` workflow, which watches Blizzard's patch server (product `wowf`)
  - `/lh selftest`, `ns.DATA_REVIEWED_FOR`, Dependabot, and `docs/MAINTENANCE.md`
- Docs: README, PLAN, TESTING-IN-GAME, LAUNCH-CHECKLIST, CONTRIBUTING, issue templates, CI workflow.
- Prepared the move to the bigweb server:
  - `tools/setup-dev.sh`, `tools/run-tests.sh`, `tools/package-for-transfer.sh`
  - `docs/MOVING-TO-BIGWEB.md`
  - a self-contained CLAUDE.md
  - this ClaudeLog (it should have been created at the start; backfilled)

### Notes
- Tests: 893 Lua checks and 5 Python tests pass. Nothing has been tested in the live game yet.
- No git commits yet. Creating the public repo `BitDevelopersLLC/loot-herald` is waiting for the owner's explicit OK (the permission check blocked it once).
- Set the bigweb location to `/mnt/bigdata/projects/loot-herald`, matching the repo name `loot-herald`. setup-dev.sh now checks write access and detects drives that can't store file permissions (NTFS/exFAT); the docs and memory were updated and the package rebuilt.

## [2026-11-13]
### Changes Made
- First session on bigweb. Ran `tools/setup-dev.sh`: all tools OK (lua5.1, python3, gh logged in, git identity set), 893 Lua checks plus 5 Python tests pass, game watcher dry run shows no change (wowf live 1.60.1.70938).
- Added `*.tar.gz` to `.gitignore` so the transfer package is never committed.
- Added the gitignored `.claude/settings.json` with `autoMemoryEnabled: false`, so memory stays in `.claude/memory/`.

### Notes
- Owner approved: committed v0.1.0, created the public repo `BitDevelopersLLC/loot-herald` and pushed. Deleted the transfer package. The Dropbox copy is to be archived by the owner on Windows.
