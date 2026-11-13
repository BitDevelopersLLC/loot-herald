# Contributing to Loot Herald

Thanks for helping! The most useful contributions are:

1. **Bug reports with `/lh debug` output.** If an item was judged wrong,
   shift-click it into `/lh debug [item]` and paste the result into a
   [bug report](../../issues/new/choose).
2. **Stat weight improvements.** All weights are in
   `LootHerald/Data/Profiles.lua`. Please explain your reasoning; a link to a
   guide or sim is ideal.
3. **Translations.** Tooltip patterns live in
   `LootHerald/Data/TooltipPatterns.lua`. They're English only so far.

## Development

- Code layout and design rules: [docs/PLAN.md](docs/PLAN.md).
- Keep game-API calls out of the logic files (`Core/Scoring.lua`, `Data/*`, and
  the pure functions in `Core/ItemReader.lua`, `Core/Role.lua` and
  `Core/Judge.lua`), so they stay testable.
- Run the tests before opening a pull request: `bash tools/run-tests.sh`
  (Lua 5.1 or LuaJIT). CI runs them too.
- The addon must never roll for the player. Buttons may only roll on a click.

By contributing, you agree that your work is released under the
[MIT License](LICENSE).
