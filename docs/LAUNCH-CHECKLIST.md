# Loot Herald: share and promote checklist

Do the steps in order. Step 2 blocks everything after it: don't promote an
addon that hasn't run in the live game.

## 1. Public repo (ready now)
- [x] Name chosen and checked (Loot Herald). License: MIT.
- [x] README, CHANGELOG, LICENSE, CONTRIBUTING, issue templates
- [x] CI runs the tests on every push and builds a release zip from a `v*` tag
- [ ] Create `BitDevelopersLLC/loot-herald` (public) and push
- [ ] Settings → Actions → General: turn on "Allow GitHub Actions to create and approve pull requests" (the game watcher needs it). Then run **Game version watch** once from the Actions tab.
- [ ] On GitHub: add a description and topics (`world-of-warcraft`, `wow-addon`, `wow-forever`, `lua`, `loot`). Turn on Discussions.

## 2. Verify in the live game (blocks promotion)
- [ ] Work through [TESTING-IN-GAME.md](TESTING-IN-GAME.md) with at least two classes, ideally one healer and one melee.
- [ ] Fix anything `/lh debug` shows reading wrong. Check the hit/crit units and the hit cap numbers for WoW Forever.
- [ ] Have a friend test the group check in a real party.

## 3. Release assets
- [ ] Screenshots: an Upgrade alert, the role picker, a tooltip line, the settings panel. Gameplay screenshots are fine; don't use Blizzard logos or key art.
- [ ] A 20-30 second clip or GIF: a boss dies, the alert pops, you click Need.
- [ ] Project logo (400×400, **original art**). Blizzard's icons are fine inside the game, but not as the addon's public logo.
- [ ] A short description (one sentence) and a long description (features, commands, "never rolls for you", privacy).
- [ ] Privacy line: "Loot Herald collects no data and sends nothing anywhere."

## 4. Publish
- [ ] Tag `v0.1.0`. This creates a GitHub release with the zip.
- [ ] **CurseForge** (the main place players get addons): create the project under the WoW Forever flavor, MIT license, category Loot / Bags & Inventory. Then:
  - add `## X-Curse-Project-ID: <id>` to the `.toc`,
  - add a `CF_API_KEY` secret to the repo,
  - switch the release job to `BigWigsMods/packager@v2`, so every tag uploads to CurseForge automatically.
- [ ] **Wago Addons**: create the project, add `## X-Wago-ID: <id>` and a `WAGO_API_TOKEN` secret. The same packager handles uploads.
- [ ] WoWInterface: optional. The packager skips WoW Forever there, so uploads would have to be manual.

## 5. Stay within the rules
- [ ] Follow Blizzard's UI Add-On Development Policy: free (no paid tier), readable code, no ads, no in-game donation requests, and no hurting game performance. A donation link on GitHub is fine; asking in game is not.
- [ ] Keep the trademark disclaimer in the README and store pages. Never call it "official" or "by Blizzard".
- [ ] Don't use "WoW" or "World of Warcraft" in the addon's name. "for WoW Forever" in a description is fine.

## 6. Promote (after step 2)
- [ ] **Blizzard forums**, WoW Forever section ([US](https://us.forums.blizzard.com/en/wow/c/wow-forever/346), [EU](https://eu.forums.blizzard.com/en/wow/c/wow-forever/359)). Addon authors already announce there. Post a short "what it does" message with a screenshot and links.
- [ ] **Reddit**: r/wow and r/classicwow. Check whether a WoW Forever subreddit exists. Read each subreddit's self-promotion rules first.
- [ ] **WoW UI developer Discord** (WoWUIDev): share in the showcase or addon-release channel, and ask for feedback from other addon authors.
- [ ] **WoW Forever community Discords and guild Discords**.
- [ ] **Addon roundup writers**: send a short pitch and a screenshot to sites that publish "best WoW Forever addons" lists (Icy Veins, Gfinity, Mobalytics, Kami, Warcraft Tavern, ConquestCapped, ExitLag).
- [ ] **Streamers and YouTubers** who cover WoW Forever addons or dungeon guides. Offer a quick demo.
- [ ] **bitdevelopers.com**: a project page or blog post linking to GitHub and CurseForge, which also helps the company's portfolio.
- [ ] BitDevelopers social accounts: a launch post with the GIF.

## 7. After launch
- [ ] **Every WoW Forever patch:** the game watcher opens a TOC PR and a checklist issue automatically. Follow [MAINTENANCE.md](MAINTENANCE.md).
- [ ] Answer CurseForge comments and GitHub issues within a few days. Ask for `/lh debug` output on scoring complaints.
- [ ] Pin the roadmap (docs/PLAN.md) and label easy issues "good first issue" (stat weights, translations).
- [ ] Ask for translations: tooltip patterns for deDE, frFR, esES and others.
- [ ] Watch downloads and feedback. Plan v0.2 from what players actually ask for.
