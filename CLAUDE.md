# Loot Herald

Open-source (MIT) World of Warcraft: **Forever** addon by BitDevelopers LLC.
When gear drops in a dungeon, it compares the item with the player's equipped
gear for their chosen class role and alerts them to consider rolling Need.

**Resuming? Read `.claude/memory/checkpoint.md` first.**

## Where this project lives
- **Main development copy:** the home server **bigweb** (Ubuntu), at
  `/mnt/bigdata/projects/loot-herald`. The folder name matches the GitHub repo
  `BitDevelopersLLC/loot-herald`. The owner SSHes in from any computer and runs
  `claude` in this folder, usually inside `tmux`.
- The old copy in Dropbox (`...\BitDevelopersLLC\WOWDungeonDrop`) is retired
  once the move is confirmed. Don't work in both.
- The game itself runs on the owner's Windows PC. To test in game, code reaches
  that PC through GitHub. See `docs/MOVING-TO-BIGWEB.md` under "Testing in game".

## Project layout
- `LootHerald/` is the addon itself. The folder name must match
  `LootHerald.toc`. This is the folder players copy into
  `World of Warcraft\_forever_\Interface\AddOns`.
- `docs/` holds `PLAN.md` (research, architecture, roadmap),
  `TESTING-IN-GAME.md`, `MAINTENANCE.md` (game patches), `LAUNCH-CHECKLIST.md`
  (share and promote) and `MOVING-TO-BIGWEB.md`.
- `tools/` holds `setup-dev.sh` (server setup check), `run-tests.sh`, the game
  watcher `check_game_version.py`, and `package-for-transfer.sh`.
- `tests/` holds the Lua logic tests and the Python watcher tests.

## How to work here
- **Tests:** `bash tools/run-tests.sh` (Lua 5.1 or LuaJIT, plus python3). Run
  them after every change.
- **Watcher dry run:** `python3 tools/check_game_version.py`.
- Target: WoW Forever runs the Mainline addon API (`## Interface: 16001`, game
  type `camelot`, Blizzard product code `wowf`).
- Keep game-API calls out of the logic files so they stay unit-testable:
  `Core/Scoring.lua`, `Data/*`, and the pure functions in `Core/ItemReader.lua`,
  `Core/Role.lua`, `Core/Judge.lua`, `Core/Announce.lua` and `Core/SelfTest.lua`.
- After a data review for a game patch, bump `ns.DATA_REVIEWED_FOR` in
  `Data/Profiles.lua`. See `docs/MAINTENANCE.md`.
- **Never auto-roll for the player.** The Need, Greed and Pass buttons only act
  on a click. The group-chat Need announcement is opt-in.

## Owner's standing rules (carried over from the BitDevelopersLLC workspace)
- **Log every change in `ClaudeLog.md`** using this format:
  `## [YYYY-MM-DD]`, then `### Changes Made` and `### Notes`. Memory file edits
  don't need a log entry.
- **Commit, push or publish only with the owner's OK.** That covers GitHub,
  CurseForge and Wago. The GitHub account is `BitDevelopersLLC`. The repo is
  public because the owner explicitly approved open source.
- **No secrets in git.** If a feature ever needs keys (for example a
  CurseForge API key), use GitHub Actions secrets or a gitignored file with a
  committed `.template`.
- Stay inside this project folder. Don't read or change other folders on the
  server unless the owner asks.
- Before suggesting any new name, check it thoroughly: web search, trademark,
  stores and domains. Say which checks didn't run.

## Memory
- Project memory lives in `.claude/memory/` (the index is `MEMORY.md`, one topic
  file per memory, and `checkpoint.md` for where we left off). It's gitignored
  and stays on bigweb, which is the single place this project is worked on.
- **Never save memory under `~/.claude/`.** Keep it in this folder. Before
  ending a session, update `checkpoint.md` with what was done, the current state
  and the exact next steps.

@.claude/memory/MEMORY.md
