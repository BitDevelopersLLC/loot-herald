# Loot Herald: Plan

_Started 2026-11-13. Owner: BitDevelopers LLC. Open source (MIT)._

## Goal

Help players know **what to roll Need on**. When gear drops in a dungeon, it
compares the item with what they're wearing, for the role they're playing, and
alerts them when it's an upgrade or about equal.

## What we learned about the target game (Nov 2026)

| Fact | Source / confidence |
|---|---|
| WoW Forever is a separate Blizzard game: a Vanilla foundation with new content, level cap 60, included with a WoW subscription. Launched 2026-11-04. | guildorder.com wiki, several fan sites |
| It runs the **modern (Mainline) addon API** ("the vast majority of APIs in 12.1.5"), not the Classic one. Classic Era addons don't load. | forevermeta.me (citing Blizzard's 2026-09-15 author post), hyzor/ForeverAddons |
| TOC `## Interface: 16001` (client 1.60.x). Game type `camelot`, `WOW_PROJECT_CAMELOT` = 18. | Shtian/bff-wow issue #3, hyzor/ForeverAddons |
| A plain `.toc` with no suffix works. The BigWigs packager supports a 16xxx interface since v2.6.0. | bff-wow issue #3 |
| Addons install to `World of Warcraft\_forever_\Interface\AddOns`. | hyzor/ForeverAddons |
| Dungeon loot uses **Need / Greed / Pass** rolls. The exact Need-eligibility rules are not documented. | Spoots Loots (a Forever roll addon), fan loot guides: medium |
| Stats are Classic-style, but **spell/melee/ranged hit are merged into one Hit stat, and the crit stats into one Crit stat**. | guildorder.com wiki |
| Talents: 51 points at level 60 across three trees. | brokenmeta.gg |
| Restrictions: secret values in combat, no combat-log events for addons, **no addon messages inside instances**. | forevermeta.me |

Still unknown until we test in the live client: whether `C_Item.GetItemStats`
reports Vanilla "Equip:" bonuses, how hit/crit appear (percent or rating), and
which talent API Forever exposes. The addon has a fallback for each of these.
See [TESTING-IN-GAME.md](TESTING-IN-GAME.md).

## Similar addons (why build this one)

Retail has *Need or Greed?*, *Lootified*, *Magpie*, *Better Dungeon Loot* and
*Pawn*. Forever has *Spoots Loots* (a roll window and wishlist, with no upgrade
logic) and *ForeverGear* (a gear planner). We could not confirm that any of the
retail upgrade advisors support Forever. Our angle:

1. **Built for Forever's stat system.** It handles Vanilla Equip: bonuses and
   merged hit/crit.
2. **Role first.** It asks for your role on dungeon entry, and it understands
   one tree with two roles (Feral Bear vs Cat).
3. **Open.** The weights are readable and overridable, and `/lh debug` shows
   every step. No black box.

## Architecture

```
LootHerald/
  LootHerald.toc
  Core/Init.lua          namespace, defaults, helpers
  Data/Profiles.lua      class/spec/role profiles + stat weights   <- most PRs land here
  Data/ClassRules.lua    armor types, weapon skills, dual wield, relics
  Data/TooltipPatterns.lua  English "Equip:" text patterns
  Core/Scoring.lua       pure math (score, % change, classify)
  Core/ItemReader.lua    item link -> stats (API + tooltip, no double counting)
  Core/Compare.lua       which slots to compare, usability, verdict
  Core/Role.lua          detect + choose profile, dungeon-entry prompt
  Core/Judge.lua         verdict + off-spec + wording + history
  UI/Theme.lua           Warcraft look built from the game's own art and fonts
  UI/AlertFrame.lua      stacked, movable alerts with Need/Greed/Pass and a timer
  UI/RolePicker.lua      "Choose Your Role" dialog
  UI/Options.lua         settings panel
  UI/Tooltip.lua         verdict line on item tooltips
  Core/Events.lua        events: load, dungeon entry, START_LOOT_ROLL, talent changes
  Core/Slash.lua         /lh commands, test alerts
  Core/Announce.lua      optional Need line in group chat
  Core/SelfTest.lua      /lh selftest health check
tools/check_game_version.py   watches Blizzard's patch server (run by game-watch.yml)
tools/known-builds.json       last build seen
tests/run_tests.lua      offline tests with game API stubs (Lua 5.1 / LuaJIT)
tests/test_check_game_version.py   watcher tests
```

Design rules:
- Keep game-API calls out of the logic files so they can be unit-tested.
- Always fall back gracefully. Register events with pcall, check that APIs exist
  before calling them, and never let an error break the default loot frames.
- The addon never rolls for you.

## Feature list

### v0.1 (built, in this repo)
- [x] Role profiles for all 9 Vanilla classes × 3 trees, with Feral split into Bear and Cat (28 profiles), plus generic fallback profiles
- [x] Role suggestion from talent tree, spec name, and LFG-assigned role
- [x] Role picker on dungeon entry, with "don't ask again unless something changes"
- [x] Judge every loot roll in dungeons (raids optional)
- [x] Upgrade, About Equal, Off-Spec and Take a Look alerts with a Warcraft theme, sound and raid-warning text
- [x] Armor-type and weapon-skill rules
- [x] Correct slot logic: rings and trinkets, two-hander vs main hand + off hand, dual wield, off hand with a two-hander
- [x] Tooltip verdict line on every item
- [x] `/lh debug` transparency, `/lh weights` and `/lh weight` overrides, `/lh history`
- [x] Settings panel
- [x] Plain-English "why" line (the stat changes that matter, biggest first)
- [x] Group check: who else in the party could use the drop (no addon messages needed)
- [x] Bind on Equip reminder
- [x] Hit cap awareness (gear hit + talent bonus; caps set with /lh hitcap)
- [x] Optional Need announcement in group chat, with the why (opt-in)
- [x] Maintenance: game version watcher (GitHub Actions), `/lh selftest`, Dependabot, docs/MAINTENANCE.md
- [x] Offline unit tests (893 Lua checks + 5 Python tests)

### Recommended next (v0.2+)
- [ ] **In-game verification pass** (TESTING-IN-GAME.md), then fix API and pattern differences
- [ ] **Pawn import:** read a Pawn scale string so players can paste community weights
- [ ] **Highlight the Blizzard roll frame** (a green glow on the Need button) as well as our alert
- [ ] **Wishlist / BiS list** per dungeon: "this is on your list" alert, even if it scores lower
- [ ] **Free-for-all / master-loot support:** judge the loot window and items other players link in chat
- [ ] **Minimap or broker button** (LibDBIcon) showing your current role
- [ ] **Localization:** tooltip patterns for deDE, frFR, esES and others (community PRs)
- [ ] **Level-aware advice while leveling:** weigh Stamina more below 60
- [ ] **Trade-window reminder:** for BoP items within the trade timer, tell the winner who it would also help

## Name

The public name is **Loot Herald**. We dropped "WoW" because it is Blizzard's
trademark. We also rejected "Dungeon Drop", which is crowded: it's the name of
an award-winning board game, an iOS game, an Android game, and "Dungeon Drops"
on Steam.

Checks for "Loot Herald" (2026-11-13):
- **USPTO search:** run by the owner. The results are saved locally in
  `trademark-search/`, which is not committed. No LOOT HERALD mark was found.
  There are separate HERALD and LOOT marks, but none of them covers games or
  game software.
- **Web:** no use of the name found.
- **CurseForge and GitHub:** the name is free.
- **Domains:** lootherald.com and lootherald.gg have no DNS records.

## Release plan

See [LAUNCH-CHECKLIST.md](LAUNCH-CHECKLIST.md).
