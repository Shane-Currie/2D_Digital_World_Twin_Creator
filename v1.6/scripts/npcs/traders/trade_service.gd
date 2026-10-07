extends RefCounted

## Model suggestions are data only. Only explicit acceptance calls purchase().
const Catalog = preload("res://scripts/inventory/item_catalog_store.gd")
const Store = preload("res://scripts/npcs/traders/trader_store.gd")

static func remaining(inventory, npc_id: String, offer: Dictionary) -> int:
	var configured := int(offer.get("stock", 0))
	var saved: Dictionary = inventory.trader_stock.get(npc_id, {}).get(str(offer.get("item_id", "")), {})
	return int(saved.get("remaining", configured)) if int(saved.get("configured_stock", -1)) == configured else configured

static func quote(inventory, npc_id: String, profile: Dictionary, catalog: Dictionary, item_id: String, quantity: Variant) -> Dictionary:
	if not bool(profile.get("enabled", false)): return _error("This character is not a trader.")
	if not Store.valid_amount(quantity) or int(quantity) < 1 or int(quantity) > 99: return _error("Choose a quantity from 1 to 99.")
	var item := Catalog.find_item(catalog, item_id)
	if item.is_empty() or item_id == "keks": return _error("That item is not available for purchase.")
	for offer in profile.get("offers", []):
		if str(offer.get("item_id", "")) != item_id: continue
		if not Store.valid_amount(offer.get("stock")) or not Store.valid_amount(offer.get("price_keks")): return _error("The trader's stock or price is invalid.")
		var total := int(quantity) * int(offer.price_keks)
		if remaining(inventory, npc_id, offer) < int(quantity): return _error("There is not enough stock.")
		if inventory.quantity("keks") < total: return _error("You do not have enough Keks.")
		return {"ok": true, "npc_id": npc_id, "item_id": item_id, "quantity": int(quantity), "unit_price": int(offer.price_keks), "total": total, "item_name": str(item.display_name)}
	return _error("This trader does not sell that item.")

static func purchase(inventory, profile: Dictionary, catalog: Dictionary, accepted: Dictionary) -> Dictionary:
	# Recheck at acceptance: a stale/forged model quote cannot choose a price.
	var current := quote(inventory, str(accepted.get("npc_id", "")), profile, catalog, str(accepted.get("item_id", "")), accepted.get("quantity", 0))
	if not current.ok: return current
	if current.total != accepted.get("total") or current.unit_price != accepted.get("unit_price"): return _error("The price changed. Please confirm a new quote.")
	var next_quantities: Dictionary = inventory.quantities.duplicate(true)
	next_quantities.keks = inventory.quantity("keks") - int(current.total)
	next_quantities[current.item_id] = inventory.quantity(current.item_id) + int(current.quantity)
	var next_stock: Dictionary = inventory.trader_stock.duplicate(true)
	var trader: Dictionary = next_stock.get_or_add(current.npc_id, {})
	for offer in profile.offers:
		if str(offer.item_id) == current.item_id:
			trader[current.item_id] = {"configured_stock": int(offer.stock), "remaining": remaining(inventory, current.npc_id, offer) - int(current.quantity)}
	# One snapshot contains both inventories, including the trader's takings.
	trader["_keks_received"] = int(trader.get("_keks_received", 0)) + int(current.total)
	var saved: Dictionary = inventory.commit_trade(next_quantities, next_stock)
	if not saved.ok: return saved
	return {"ok": true, "message": "Bought %d %s for %d Keks." % [current.quantity, current.item_name, current.total], "trade": current}

static func context(inventory, npc_id: String, profile: Dictionary, catalog: Dictionary) -> Dictionary:
	var items: Array = []
	for offer in profile.get("offers", []):
		var item := Catalog.find_item(catalog, str(offer.get("item_id", "")))
		if not item.is_empty() and str(item.id) != "keks" and Store.valid_amount(offer.get("price_keks")) and Store.valid_amount(offer.get("stock")) and remaining(inventory, npc_id, offer) > 0:
			items.append({"item_id": item.id, "name": item.display_name, "stock": remaining(inventory, npc_id, offer), "price_keks": int(offer.price_keks)})
	return {"role": str(profile.get("trade_role", "Trader")).left(80), "items": items}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}
