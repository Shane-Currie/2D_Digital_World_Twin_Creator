extends RefCounted

## Ground floor counts as one. These overrides never change source geometry.
const MAX_FLOORS := 200
const STYLES := {"automatic": "Automatic / existing design", "brick": "Brick", "rendered": "Rendered concrete", "commercial": "Shopfront", "tall": "Glass office", "industrial": "Industrial"}

static func positive_floor_count(value: Variant) -> int:
	if value is int or value is float:
		if not is_finite(float(value)) or float(value) != floorf(float(value)): return 0
		return int(value) if value >= 1 and value <= MAX_FLOORS else 0
	var text := str(value).strip_edges()
	if not text.is_valid_int(): return 0
	var number := int(text)
	return number if number >= 1 and number <= MAX_FLOORS else 0

static func resolve(tags: Dictionary, design: Dictionary = {}) -> Dictionary:
	var overridden := positive_floor_count(design.get("total_floors", ""))
	if overridden > 0: return {"total_floors": overridden, "source": "Creator override", "review": false}
	var mapped := positive_floor_count(tags.get("building:levels", ""))
	if mapped > 0: return {"total_floors": mapped, "source": "OpenStreetMap building:levels", "review": false}
	return {"total_floors": 1, "source": "Default (no usable floor count)", "review": tags.has("building:levels")}

static func set_floors(data: Dictionary, feature_id: String, value: int) -> Dictionary:
	if feature_id.is_empty() or value < 1 or value > MAX_FLOORS: return {"ok": false, "message": "Use a whole floor count from 1 to 200."}
	var updated := data.duplicate(true)
	var record: Dictionary = updated.buildings.get(feature_id, {"feature_id": feature_id}).duplicate(true)
	record["total_floors"] = value
	updated.buildings[feature_id] = record
	return {"ok": true, "data": updated}

static func restore(data: Dictionary, feature_id: String) -> Dictionary:
	var updated := data.duplicate(true)
	if updated.buildings.has(feature_id):
		updated.buildings[feature_id].erase("total_floors")
		if updated.buildings[feature_id].size() == 1: updated.buildings.erase(feature_id)
	return updated

## A new playable floor may raise the exterior, but must never shrink it.
static func ensure_minimum_floors(data: Dictionary, feature: Dictionary, minimum: int) -> Dictionary:
	var id := str(feature.get("id", ""))
	var current: int = resolve(feature.get("tags", {}), data.get("buildings", {}).get(id, {})).total_floors
	if minimum <= current: return {"ok": true, "data": data.duplicate(true)}
	return set_floors(data, id, minimum)

static func set_style(data: Dictionary, feature_id: String, style: String) -> Dictionary:
	var updated := data.duplicate(true)
	var record: Dictionary = updated.buildings.get(feature_id, {"feature_id": feature_id}).duplicate(true)
	if style == "automatic": record.erase("building_style")
	elif STYLES.has(style): record["building_style"] = style
	updated.buildings[feature_id] = record
	return updated
