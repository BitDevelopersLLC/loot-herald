# Loot Herald

**Know when to roll Need.** Loot Herald is a free, open-source addon for
**World of Warcraft: Forever**. When an item drops in a dungeon, it compares the
item with the gear you have on, for the role you're playing. If the item is an
upgrade (or about equal), it pops up a Warcraft-style alert telling you to
consider rolling **Need** instead of Greed.

It works for every class and role, for example:
- Restoration Druid: healing, Intellect, mana regen
- Feral Druid as a Bear tank or as Cat DPS
- Protection Warrior: Stamina, Defense, Armor, Block
- Fire Mage: spell damage and fire damage, Hit, Crit

> The addon never rolls for you. It tells you what it found and why, and you
> make the call.

## Features

- **Role picker when you enter a dungeon.** It suggests a role from your
  talents and your group role, and you confirm it. You can change it at any
  time with `/lh role`. Tick "Don't ask again" and it only asks again when your
  talents or group role change.
- **Upgrade alerts on loot rolls.** Each alert shows the item, the % change for
  your role, the item it replaces, and a roll timer. The Need / Greed / Pass
  buttons do the same thing as the game's own buttons.
- **Four kinds of alert:**
  - **Upgrade!** Consider rolling Need. Upgrades also glow, play a raid-warning
    sound and show big text.
  - **About Equal.** A sidegrade within your threshold (3% by default).
  - **Off-Spec Upgrade.** Not better for your current role, but better for one of
    your class's other roles (for example, Bear gear for a Resto Druid). It
    suggests Greed.
  - **Take a Look.** The item has a "Use:" or "Chance on hit:" effect that can't
    be turned into a number.
- **The why, in plain English.** For example, "Why: +22 Healing, +8 Int, -5
  Spirit". It lists the stat changes that matter for your role, biggest first,
  on alerts, in chat and on tooltips.
- **Group check.** For example, "Also good for: Shadowstep (Combat Rogue)". It
  tells you who else in your party could use the drop, so you can roll fairly.
  It uses only what the game already shows about party members (class, level,
  group role), so it works even though WoW Forever blocks addon messages in
  dungeons.
- **Bind on Equip reminder.** BoE items can be traded or sold, so the alert
  reminds you to Need only if you'll actually wear the item.
- **Hit cap aware.** Hit past the cap is worth nothing. It adds up the Hit on
  your gear (plus any talent bonus you set) and stops valuing Hit you can't use.
  `/lh hitcap 9 16 3` sets the melee cap, spell cap and talent bonus.
- **Tell your group why you rolled Need (optional, off by default).** When you
  roll Need on something Loot Herald called an Upgrade or About Equal, it
  posts one line in party, raid or instance chat. For example:
  `[Loot Herald] Need on [Robe of the Archmage]: +14% upgrade for my Restoration Druid (+22 Healing, +8 Int, -5 Spirit)`.
  It works whether you click Need on Loot Herald's alert or on Blizzard's roll
  window. It never posts about items it didn't recommend. Turn it on with
  `/lh announce` or in the settings panel.
- **Armor-type sense.** A plate wearer isn't told to Need mail, and a rogue isn't
  told to Need cloth. The rule follows each class's level-40 armor change.
- **Tooltip line everywhere.** Hover any item (bags, chat links, quest rewards,
  the auction house) to see "Loot Herald: Upgrade +12% for Restoration Druid".
- **You can see how every verdict was reached.** `/lh debug [item]` prints each
  stat, its weight, where it was read from, and the final score.
- **Adjustable weights.** `/lh weights` shows them and `/lh weight CRIT 10`
  overrides one.
- **Loot history.** `/lh history` lists the last drops it judged.
- **Warcraft look.** The alerts use the game's own dialog frames, gold borders
  and the Morpheus title font, so they fit in with the default UI.

## Install

1. Download the latest release zip (or clone this repo).
2. Copy the **`LootHerald`** folder (the one containing `LootHerald.toc`) into:
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Fully restart the game (`/reload` is often not enough for a new addon).
4. On the character screen, open **AddOns** and make sure *Loot Herald* is
   enabled.

## Commands

| Command | What it does |
|---|---|
| `/lh` | Help and your current role |
| `/lh role` | Choose your class role (spec) |
| `/lh test` | Show sample alerts. Drag one to move them all |
| `/lh check [item]` | Is this an upgrade? (shift-click the item into chat) |
| `/lh debug [item]` | Show exactly how the item was scored |
| `/lh weights` | Show the stat weights for your role |
| `/lh weight <STAT> <value>` | Override one weight (`/lh weight reset` to undo) |
| `/lh history` | The last drops judged |
| `/lh announce` | Turn posting your Need rolls (and why) in group chat on or off |
| `/lh post` | Post a Need message the game blocked (it fills your chat box; you press Enter) |
| `/lh hitcap <melee> <spell> [bonus]` | Set the hit caps and your talent hit bonus |
| `/lh selftest` | Health check after a game patch (paste the result into an issue) |
| `/lh on` / `/lh off` | Turn the addon on or off |
| `/lh options` | Settings window (also under Options > AddOns) |
| `/lh resetpos` | Move alerts back to the default spot |

## How the scoring works

1. Read the item's stats from the game API, plus any "Equip:" bonuses from the
   tooltip text (spell damage, healing, hit %, crit %, mp5, defense...). A stat
   is never counted twice.
2. Score = the sum of each **stat × weight** for your role. The weights are in
   [`LootHerald/Data/Profiles.lua`](LootHerald/Data/Profiles.lua) and every
   number has a comment explaining it.
3. Score the item(s) you have equipped in that slot the same way. Rings and
   trinkets are compared with your *weaker* one. A two-hander is compared with
   main hand + off hand together.
4. Compare: at least +threshold% is an **Upgrade**, within ±threshold% is
   **About Equal**.

The weights are simple, community-style starting points, not simulation
results. If you think one is wrong, please open an issue or a pull request.

## Known limitations (v0.1)

- **Not yet tested in the live WoW Forever client.** The logic is unit-tested
  offline. See [docs/TESTING-IN-GAME.md](docs/TESTING-IN-GAME.md) for the
  checklist we're working through.
- Tooltip reading is **English only** (enUS/enGB). Other languages use API
  stats only.
- Set bonuses and Use/proc effects are not scored. Items that have them are
  flagged instead.
- WoW Forever blocks hidden addon-to-addon messages inside instances, so there
  is no data sharing between players' addons. The optional Need announcement is
  an ordinary chat line. If the game blocks addon chat during a fight, the line
  waits until the block lifts (up to 2 minutes); after that, `/lh post` lets
  you send it yourself.

## Development

- Logic lives in `LootHerald/Core` and `LootHerald/Data`. The UI lives in
  `LootHerald/UI`.
- Run all offline tests (Lua 5.1 or LuaJIT, plus python3) from the repo root: `bash tools/run-tests.sh`, or just the Lua part:
  `lua tests/run_tests.lua`
- The plan and roadmap are in [docs/PLAN.md](docs/PLAN.md).
- How the addon stays current as WoW Forever is patched: [docs/MAINTENANCE.md](docs/MAINTENANCE.md).
  A watcher checks Blizzard's patch server every 6 hours and opens a PR and an
  issue when a new game version ships.

## License

[MIT](LICENSE) © BitDevelopers LLC. This addon is free and always will be,
following Blizzard's UI Add-On policy: free, readable code, no ads.

World of Warcraft and WoW are trademarks of Blizzard Entertainment, Inc. This
project is not affiliated with or endorsed by Blizzard Entertainment.
