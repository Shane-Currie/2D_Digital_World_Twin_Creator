# Player inventory and stats

A small backpack sits at the lower-right edge of the play area, above the bottom information bar. Click it to open or close the compact itemised list. Escape closes a consume prompt before the backpack; inventory clicks never click a building underneath the panel.

## Starting contents

- **100 Keks** — the game's currency.
- **3 bananas** — a nutrient consumable restoring 20 points by default.
- **3 water bottles** — a hydration consumable restoring 25 points by default.

Keks and bananas have been migrated into the same item catalogue used by water and creator-added items. They are no longer a separate display-only special case. Quantities are gameplay data, not text painted into the HUD. Future shops, rewards and pickups should change them through `RuntimePlayerInventory`, which prevents negative quantities and saves successful changes immediately.

## Consuming an item

Click a nutrient or hydration item in the open backpack. The game asks whether to consume one and shows the restoration value. Confirming removes one item and immediately adds the points to the matching player stat, capped at 100. The item is not removed when the matching stat is already full. Currency and general items cannot be consumed.

The **Player Stats** button is in the top-right of the play area. The nutrient and hydration bars are hidden until it is clicked. A new player begins with **50/100 nutrients** and **50/100 hydration**. This stage does not reduce either stat over time.

Each town keeps its own player inventory in `saves/player_inventory.json`. The previous readable save is retained as `.bak` before replacement. If the main file is damaged but the backup is valid, the backup is loaded. If neither can be read, saving is disabled and the existing files remain untouched.

Player stats use the same safe pattern in `saves/player_stats.json`. Existing player saves retain their current quantities when a town catalogue changes. A newly introduced catalogue item is added once at its configured starting quantity rather than resetting existing items.

## Creator Studio item editor

Open a town project and select **Inventory items** in Creator Studio. The editor can:

- edit Keks, bananas and water through the same catalogue used for custom items;
- add a custom item name and starting quantity;
- choose General, Currency, Nutrient or Hydration type;
- set 1–100 nutrient or hydration restoration points for a consumable; and
- import a PNG, JPEG or WebP picture, which is copied into that town's `assets/items/` folder.

Select **Save item catalogue**, then reopen Play test to use the change. Definitions are stored in human-readable `data/item_catalog.json`. Built-in entries cannot be deleted so later economy and survival systems retain stable IDs, but their names, quantities, types and restoration values remain editable.

## Layout and artwork

The open backpack is deliberately compact. Item icons render at 24×24 game pixels in short rows, and the bounded list scrolls when more items are added. Full-resolution transparent artwork and lightweight 128×128 runtime versions live in `assets/inventory/`:

- `backpack_icon_v1.png` / `backpack_icon_runtime.png`
- `kek_coins_icon_v1.png` / `kek_coins_icon_runtime.png`
- `bananas_icon_v1.png` / `bananas_icon_runtime.png`
- `water_bottle_icon_v1.png` / `water_bottle_icon_runtime.png`

Shops, trading, pickups, nutrient/hydration depletion and weight/capacity remain later features.
