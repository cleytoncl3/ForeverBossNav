# Forever Boss Nav

Addon for **World of Warcraft: Forever** (client 1.60.1, interface `16001`).

When you enter a dungeon or raid, it opens a window with:

- **Every boss of the instance in the client's order**, split by wing (Scarlet Monastery, Dire Maul, Blackrock Spire, Stratholme).
- The **next boss** highlighted, with an arrow at the top.
- **Automatic kills**: detected through `ENCOUNTER_END` / `BOSS_KILL` and the NPC's death in the combat log (by NPC ID, so it works on a pt-BR client).
- **Learns new dungeons by itself**: the first pull of an unknown boss adds it to the list, and it stays saved.
- **Localized names**: once you target a boss, its Portuguese name shows next to the English one.

## Coverage

45 instances and 300 bosses, read from the WoW: Forever client (via [wowforevertalents.com](https://wowforevertalents.com/dungeons/)):

- Every classic dungeon (Ragefire Chasm to Scholomance), with the boss lists as changed in Forever.
- New dungeons whose bosses are already in the client: **The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran**.
- Announced dungeons that have no data in the client yet: **The Drowned City, Krol'dor Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace** (bosses are learned in game).
- Raids: Onyxia, MC, BWL, ZG, AQ20, AQ40, Naxx, plus the ones already in the client (Nightmare Grove, Scarlet Enclave, etc.) and the announced ones (Barrow Deeps, Hyjal Summit).

## About the arrow and coordinates (important)

Since patch 7.1, Blizzard **blocks** `UnitPosition()` and `GetPlayerFacing()` inside instances, and the Classic/Forever client inherited that block. Forever also has no dungeon map for addons to read. In practice, **no addon can know where you are inside a dungeon**, so it cannot work out the direction or distance to a boss.

What the addon does:

- **Normal mode (always works):** the yellow arrow marks the **next boss in order**.
- **Navigation mode (only if the client gives your position):** if `UnitPosition` returns coordinates, the arrow turns and points to the **closest boss still alive**, with the distance in meters. Positions are saved automatically when you pull each boss, or with `Shift+click` on a boss / `/fbn mark`.

## Commands

| Command | What it does |
| --- | --- |
| `/fbn` | Shows/hides the window |
| `/fbn list` | Lists every dungeon and raid by level |
| `/fbn show <name>` | Shows the bosses of an instance while outside it (e.g. `/fbn show dire`) |
| `/fbn reset` | Resets the kills of the current instance |
| `/fbn mark` | Saves your position as the location of your target or the next boss |
| `/fbn lock` | Locks/unlocks the window |

In the list: **click** marks/unmarks a boss as dead; **Shift+click** saves its position.

## Install

1. Download the repository (Code → Download ZIP).
2. Extract the `ForeverBossNav` folder into `Interface\AddOns\` inside the Forever client folder (in `World of Warcraft\`, the Forever subfolder, the same one that holds its other addons).
3. At the character screen, under AddOns, make sure **Forever Boss Nav** is enabled.

## Updating the data

`tools/gen.js` builds `Data.lua` from the wowforevertalents.com instance pages saved as `raw/<slug>.html` and a `bosses2.json` with the map ID of each one. Run `node tools/gen.js Data.lua` in the folder that has those files.

## License

MIT, see [LICENSE](LICENSE).
