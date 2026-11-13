# In-game test checklist (WoW Forever)

The logic is unit-tested offline, but the parts that talk to the game client
can only be checked in the live client. Work through this list. Each answer
tells us whether a fallback is needed.

## 1. Loads cleanly
- [ ] `/dump select(4, GetBuildInfo())` prints the interface number. Does it match `16001` in `LootHerald.toc`? If not, update the `.toc`.
- [ ] The addon shows as enabled (not "out of date") on the AddOns screen.
- [ ] No Lua errors at login. Turn on `/console scriptErrors 1` to see them.
- [ ] The welcome message appears once.

## 2. Role detection
- [ ] `/lh` shows a sensible suggested role for your talents.
- [ ] Run `/dump GetSpecialization()`, `/dump GetNumTalentTabs()` and `/dump GetTalentTabInfo(1)`, and write down what they return. Role.lua handles both the old and new GetTalentTabInfo shapes.
- [ ] Entering a dungeon opens the role picker after about 2 seconds.
- [ ] Choosing a role prints "Judging loot for ...".

## 3. Item reading (most important)
Shift-click items into `/lh debug [item]` and check:
- [ ] Plain stats (+Stamina, +Intellect, Armor) appear under **Raw API stats**.
- [ ] Healing/spell damage gear: is the bonus in the API stats, or only read from the tooltip? Either works. Note which.
- [ ] Hit/crit gear: is the value `1` (percent) or a bigger rating number? If it's a rating, check that the converted % looks right. Adjust `RATING_PER_PERCENT` in ItemReader.lua.
- [ ] Is anything counted twice? The total should match what you'd add up by hand.
- [ ] Weapons: DPS is read, and a bow or wand shows as RDPS.
- [ ] "Use:" trinkets show as "special (not scored)".

## 4. Loot rolls
- [ ] In a dungeon, a gear drop prints a chat line, and an alert appears for upgrades.
- [ ] The timer bar counts down. The alert disappears when the roll ends.
- [ ] The **Need** button on our alert rolls Need. For a BoP item, Blizzard's confirmation still appears.
- [ ] Greed and Pass work. Need is greyed out when the game won't let you Need.
- [ ] Several drops at once stack neatly.

## 5. Need announcement (`/lh announce` on, in a group)
- [ ] `/lh test`, then click Need: the chat shows a preview of the line.
- [ ] Real drop: click Need on **Loot Herald's alert**. One line appears in party chat (or instance chat in a dungeon-finder group).
- [ ] Real drop: click Need on **Blizzard's roll window** instead. The line is still posted, exactly once.
- [ ] Bind-on-pickup item: the line appears only after you confirm. Cancel the confirmation and nothing is posted.
- [ ] Note whether the game blocks the message right after a boss kill (it says "Couldn't post..."). If it does, check that `/lh post` fills the chat box.
- [ ] No Lua error or "blocked action" popup.

## 6. Tooltips and UI
- [ ] Hovering gear in bags shows the "Loot Herald:" line.
- [ ] `/lh test` shows three themed alerts. Dragging moves them, and the position is saved after `/reload`.
- [ ] `/lh options` opens the settings panel. The checkboxes save.

Report results as a GitHub issue. Include the `/lh debug` output for anything
that's scored wrong.
