# Items & Economy

Lightweight, modular item and economy components.

## Components
- `ItemDef.gd` (Resource): id, name, description, rarity, tags, max_stack, icon
- `InventoryLite.gd` (Node): capacity-limited inventory with save/load hooks
- `LootTable.gd` (Resource): weighted rolls with RNG seed option
- `Pickup.gd` (Area2D): simple item pickup publishing EventBus events
- `Wallet.gd` (Node): multi-currency balances with save/load
- `Shop.gd` (Node): minimal purchase flow using Wallet + InventoryLite
- `Crafting.gd` (Node): stub crafting interface with signal
- `Equipment.gd` (Node): configurable slots and save/load
- `Upgrades.gd` (Node): stat levels with save/load

## Quick Start
```gdscript
# Create an item
var sword := ItemDef.new()
sword.id = "sword_bronze"
sword.display_name = "Bronze Sword"

# Inventory
var inv := InventoryLite.new()
add_child(inv)
inv.capacity = 16
inv.add_item(sword, 1)

# Wallet
var wallet := Wallet.new()
add_child(wallet)
wallet.deposit("gold", 100)

# Shop
var shop := Shop.new()
add_child(shop)
var ok := shop.buy(self, "potion", 25)
```

## Loot
```gdscript
var table := LootTable.new()
table.entries = [
	{"id": "coin", "weight": 5.0, "min": 1, "max": 10},
	{"id": "potion", "weight": 1.0, "min": 1, "max": 2}
]
var drop := table.roll_one()
```

## EventBus Integration
- Pickup publishes `item/picked_up` with `{ item_id, quantity, by }`.
- Shop publishes `shop/purchased` with `{ buyer, item_id, price }`.

## SaveService Integration
- `InventoryLite.save_data()` / `.load_data()`
- `Wallet.save_data()` / `.load_data()`
- `Equipment.save_data()` / `.load_data()`
- `Upgrades.save_data()` / `.load_data()`

## Determinism
- Use `LootTable.roll_one(rng_seed)` and later `RNGService` for deterministic draws in tests.
