class_name StorylineNpcStore
extends RefCounted

## Persistent outdoor and creator-authored interior storyline characters.
## Creators may provide an identity and compatible human persona, or keep the
## random defaults. Artwork remains an existing randomly selected static asset.
## Later versions can add template/artwork choices without changing locations.

const FILE_NAME := "storyline_npcs.json"
const SCHEMA_VERSION := 1
const MAXIMUM_PEDESTRIAN_LINK_METRES := 250.0
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const BuildingInteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")

const NAMES_BY_GENDER := {
	"woman": ["Amelia", "Chloe", "Ella", "Grace", "Hannah", "Isla", "Jade", "Layla", "Maya", "Mia", "Ruby", "Sophie", "Tahlia", "Willow", "Zoe"],
	"man": ["Aiden", "Ben", "Caleb", "Daniel", "Eli", "Finn", "Harrison", "Jack", "Liam", "Lucas", "Mason", "Noah", "Oliver", "Sam", "Thomas"]
}
const SURNAMES := [
	"Baker", "Brown", "Chen", "Clarke", "Davis", "Evans", "Garcia", "Harris", "Ibrahim", "Jones",
	"Khan", "Lee", "Martin", "Nguyen", "Patel", "Robinson", "Singh", "Taylor", "Walker", "Wilson"
]
const SKIN_TONES := ["light", "medium", "dark"]
const AGE_GROUPS := ["young", "adult", "older"]


static func empty_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": "creator_storyline_npcs",
		"npcs": [],
		"notes": {
			"placement": "Outdoor latitude/longitude or stable building, floor and local interior metre coordinates selected by the creator.",
			"appearance": "Random static NPC artwork in v1.5; selectable templates and imported artwork are reserved for a future version."
		}
	}


func load_from_town(town_directory: String, bounds: Dictionary = {}, features: Array = [], persona_data: Dictionary = {}, interior_data: Dictionary = {}) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(), "created_default": true, "message": "No storyline NPCs have been placed yet."}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed, bounds, features, persona_data, false, interior_data)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	return {"ok": true, "data": parsed, "created_default": false, "message": "Storyline NPC placements loaded.", "warnings": validation.warnings}


func save_to_town(town_directory: String, data: Dictionary, bounds: Dictionary = {}, features: Array = [], persona_data: Dictionary = {}, interior_data: Dictionary = {}) -> Dictionary:
	var validation := validate(data, bounds, features, persona_data, false, interior_data)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var path := data_directory.path_join(FILE_NAME)
	var previous = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	var next_number := maxi(_next_number(data), _next_number(previous) if previous is Dictionary else 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	var saved := data.duplicate(true)
	saved["next_npc_number"] = next_number
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	file.store_string(JSON.stringify(saved, "\t") + "\n")
	return {"ok": true, "data": saved, "path": data_directory.path_join(FILE_NAME), "message": "Storyline NPC placements saved.", "validation": validation, "warnings": validation.warnings}


func move_interior_npc(data: Dictionary, npc_id: String, position_metres: Vector2, interiors: Dictionary) -> Dictionary:
	# Change location only: retain the character's stable ID, persona and artwork.
	var edited := data.duplicate(true)
	for npc in edited.get("npcs", []):
		if str(npc.get("id", "")) != npc_id: continue
		var location: Dictionary = npc.get("location", {}).duplicate(true)
		if str(location.get("space", "")) != "interior":
			return {"ok": false, "message": "Choose a character on this interior floor."}
		location.x_metres = snappedf(position_metres.x, 0.01)
		location.y_metres = snappedf(position_metres.y, 0.01)
		var checked := BuildingInteriorStoreScript.new().validate_location(interiors, location)
		if not checked.ok: return checked
		for other in edited.get("npcs", []):
			var other_location: Dictionary = other.get("location", {})
			if str(other.get("id", "")) == npc_id or str(other_location.get("space", "")) != "interior": continue
			if str(other_location.get("building_id", "")) != str(location.building_id) or str(other_location.get("floor_id", "")) != str(location.floor_id): continue
			if Vector2(float(location.x_metres), float(location.y_metres)).distance_to(Vector2(float(other_location.x_metres), float(other_location.y_metres))) < 0.7:
				return {"ok": false, "message": "Leave space between storyline characters."}
		npc.location = location
		return {"ok": true, "data": edited, "npc": npc, "message": "%s moved. Save the interior layout to keep this position." % str(npc.get("display_name", "NPC"))}
	return {"ok": false, "message": "This storyline character was not found."}


func add_random_outdoor_npc(data: Dictionary, location: Dictionary, town_id: String, persona_data: Dictionary) -> Dictionary:
	return add_outdoor_npc(data, location, town_id, persona_data)


func add_outdoor_npc(data: Dictionary, location: Dictionary, town_id: String, persona_data: Dictionary, requested_name := "", requested_persona_id := "", npc_role := "storyline") -> Dictionary:
	if npc_role not in ["storyline", "trader", "generic", "npr"]: return {"ok": false, "message": "Choose a supported character type."}
	var result := data.duplicate(true)
	if result.is_empty():
		result = empty_data()
	var used_ids: Dictionary = {}
	var used_names: Dictionary = {}
	for value in result.get("npcs", []):
		if value is Dictionary:
			used_ids[str(value.get("id", ""))] = true
			used_names[str(value.get("display_name", ""))] = true
	# Inventory saves refer to this ID: never give a deleted trader's ID to
	# a newly placed character, even after reopening the Creator.
	var number := _next_number(result)
	while used_ids.has("storyline_npc_%03d" % number):
		number += 1
	var npc_id := ("%s_npc_%%03d" % npc_role) % number
	var actor_kind := "npr" if npc_role == "npr" else "npc"
	var seed_text := "%s|%s|%.8f|%.8f|%s" % [town_id, npc_id, float(location.latitude), float(location.longitude), Time.get_datetime_string_from_system(true)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var gender := "woman" if rng.randi_range(0, 1) == 0 else "man"
	var first_names: Array = NAMES_BY_GENDER[gender]
	var display_name := str(requested_name).strip_edges()
	if not display_name.is_empty():
		if display_name.length() > 80 or display_name.contains("\n") or display_name.contains("\r"):
			return {"ok": false, "message": "Keep the storyline NPC name on one line and under 80 characters."}
		if used_names.has(display_name):
			return {"ok": false, "message": "Another storyline NPC already uses the name %s." % display_name}
	else:
		for _attempt in 64:
			var candidate := "%s %s" % [first_names[rng.randi_range(0, first_names.size() - 1)], SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]]
			if not used_names.has(candidate):
				display_name = candidate
				break
		if display_name.is_empty():
			display_name = "%s %s-%03d" % [first_names[rng.randi_range(0, first_names.size() - 1)], SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)], number]
	var persona_ids: Array[String] = []
	for value in persona_data.get("personas", []):
		if value is Dictionary and str(value.get("actor_kind", "")) == actor_kind and (not bool(value.get("trader_only", false)) or str(value.get("id", "")) == requested_persona_id):
			persona_ids.append(str(value.get("id", "")))
	if persona_ids.is_empty():
		return {"ok": false, "message": "Add at least one compatible character persona before placement."}
	var persona_id := str(requested_persona_id).strip_edges()
	if not persona_id.is_empty() and persona_id not in persona_ids:
		return {"ok": false, "message": "Choose a saved compatible persona (human for NPCs, robot for NPRs)."}
	if persona_id.is_empty():
		persona_id = persona_ids[rng.randi_range(0, persona_ids.size() - 1)]
	var skin_tone: String = str(SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)])
	var age_group: String = str(AGE_GROUPS[rng.randi_range(0, AGE_GROUPS.size() - 1)])
	var record := {
		"schema_version": SCHEMA_VERSION,
		"id": npc_id,
		"npc_role": npc_role,
		"actor_kind": actor_kind,
		"display_name": display_name,
		"persona_id": persona_id,
		"location": {
			"space": "outdoors",
			"town_id": town_id,
			"latitude": float(location.latitude),
			"longitude": float(location.longitude)
		},
		"appearance": {
			"mode": "random_static_asset",
			"seed": seed_text.sha256_text(),
			"gender": gender,
			"age_group": age_group,
			"skin_tone_group": skin_tone,
			"npc_asset": "npc_%s_%s_%s" % [skin_tone, gender, age_group],
			"template_id": "",
			"custom_artwork_path": ""
		},
		"behaviour": {"stationary": true},
		"created_utc": Time.get_datetime_string_from_system(true)
	}
	if actor_kind == "npr":
		record.appearance.npc_asset = "npr"
		if requested_name.strip_edges().is_empty():
			var robot_name := "NPR-%03d" % number
			var suffix := 1
			while used_names.has(robot_name):
				robot_name = "NPR-%03d-%d" % [number, suffix]
				suffix += 1
			record.display_name = robot_name
	result["npcs"].append(record)
	result["next_npc_number"] = number + 1
	return {"ok": true, "data": result, "npc": record, "message": "%s was placed outdoors." % display_name}


static func _next_number(data: Dictionary) -> int:
	var number := maxi(1, int(data.get("next_npc_number", 1)))
	for npc in data.get("npcs", []):
		var id_value := str(npc.get("id", ""))
		if id_value.begins_with("storyline_npc_"):
			number = maxi(number, int(id_value.trim_prefix("storyline_npc_")) + 1)
		elif id_value.begins_with("trader_npc_"):
			number = maxi(number, int(id_value.trim_prefix("trader_npc_")) + 1)
		elif id_value.begins_with("generic_npc_"):
			number = maxi(number, int(id_value.trim_prefix("generic_npc_")) + 1)
		elif id_value.begins_with("npr_npc_"):
			number = maxi(number, int(id_value.trim_prefix("npr_npc_")) + 1)
	return number


func add_interior_npc(data: Dictionary, location: Dictionary, town_id: String, persona_data: Dictionary, requested_name := "", requested_persona_id := "", npc_role := "storyline") -> Dictionary:
	# Reuse the same identity/persona/artwork rules as an outdoor storyline NPC,
	# then replace only the location contract with stable interior coordinates.
	var seed_location := {"latitude": float(location.get("y_metres", 0.0)) / 100000.0, "longitude": float(location.get("x_metres", 0.0)) / 100000.0}
	var result := add_outdoor_npc(data, seed_location, town_id, persona_data, requested_name, requested_persona_id, npc_role)
	if not result.ok:
		return result
	var npc: Dictionary = result.npc
	npc["location"] = {
		"space": "interior",
		"town_id": town_id,
		"building_id": str(location.get("building_id", "")),
		"floor_id": str(location.get("floor_id", "")),
		"x_metres": snappedf(float(location.get("x_metres", 0.0)), 0.01),
		"y_metres": snappedf(float(location.get("y_metres", 0.0)), 0.01)
	}
	result["message"] = "%s was placed inside the building." % str(npc.display_name)
	return result


static func format_interior_location(building_id: String, floor_id: String, position_metres: Vector2) -> String:
	return "Interior: building=%s; floor=%s; x=%.2f; y=%.2f" % [building_id, floor_id, position_metres.x, position_metres.y]


static func parse_location_text(value: String) -> Dictionary:
	var text := value.strip_edges()
	if text.to_lower().begins_with("interior:"):
		var expression := RegEx.new()
		expression.compile("(?i)^interior:\\s*building=([^;]+);\\s*floor=([^;]+);\\s*x=(-?[0-9]+(?:\\.[0-9]+)?);\\s*y=(-?[0-9]+(?:\\.[0-9]+)?)$")
		var found := expression.search(text)
		if found == null:
			return {"ok": false, "message": "Paste the complete interior location copied from Interior Designer."}
		return {"ok": true, "location": {
			"space": "interior",
			"building_id": found.get_string(1).strip_edges(),
			"floor_id": found.get_string(2).strip_edges(),
			"x_metres": float(found.get_string(3)),
			"y_metres": float(found.get_string(4))
		}}
	var outdoors := parse_coordinate_text(text)
	if outdoors.ok:
		outdoors.location["space"] = "outdoors"
	return outdoors


static func parse_coordinate_text(value: String) -> Dictionary:
	var text := value.strip_edges()
	if text.is_empty():
		return {"ok": false, "message": "Paste a latitude and longitude copied from the Advanced map editor."}
	var latitude_regex := RegEx.new()
	var longitude_regex := RegEx.new()
	latitude_regex.compile("(?i)lat(?:itude)?\\s*[:=]\\s*(-?[0-9]+(?:\\.[0-9]+)?)")
	longitude_regex.compile("(?i)lon(?:gitude)?\\s*[:=]\\s*(-?[0-9]+(?:\\.[0-9]+)?)")
	var latitude_match := latitude_regex.search(text)
	var longitude_match := longitude_regex.search(text)
	var latitude := 0.0
	var longitude := 0.0
	if latitude_match != null and longitude_match != null:
		latitude = float(latitude_match.get_string(1))
		longitude = float(longitude_match.get_string(1))
	else:
		var pieces := text.replace(";", ",").split(",", false)
		if pieces.size() != 2 or not pieces[0].strip_edges().is_valid_float() or not pieces[1].strip_edges().is_valid_float():
			return {"ok": false, "message": "Use latitude, longitude—for example -36.080000, 146.920000."}
		latitude = float(pieces[0].strip_edges())
		longitude = float(pieces[1].strip_edges())
	if latitude < -90.0 or latitude > 90.0 or longitude < -180.0 or longitude > 180.0:
		return {"ok": false, "message": "The latitude or longitude is outside the valid world range."}
	return {"ok": true, "location": {"latitude": latitude, "longitude": longitude}}


static func validate_pedestrian_reachability(location: Dictionary, navigation: Dictionary) -> Dictionary:
	var nodes: Array = navigation.get("pedestrian", {}).get("nodes", [])
	if nodes.is_empty():
		return {"ok": false, "message": "This town has no generated pedestrian network near the selected point."}
	var origin := Vector2(float(location.longitude), float(location.latitude))
	var nearest_distance := INF
	var nearest_node_id := -1
	for value in nodes:
		if not value is Dictionary:
			continue
		var node: Dictionary = value
		var point := Vector2(float(node.get("longitude", 0.0)), float(node.get("latitude", 0.0)))
		var local := Vector2(
			(point.x - origin.x) * 111320.0 * cos(deg_to_rad(origin.y)),
			(point.y - origin.y) * 110540.0
		)
		if local.length() < nearest_distance:
			nearest_distance = local.length()
			nearest_node_id = int(node.get("id", -1))
	if nearest_node_id < 0 or nearest_distance > MAXIMUM_PEDESTRIAN_LINK_METRES:
		return {"ok": false, "message": "Choose a location within %d metres of a generated pedestrian route." % int(MAXIMUM_PEDESTRIAN_LINK_METRES)}
	return {"ok": true, "node_id": nearest_node_id, "distance_metres": nearest_distance}


static func validate(data: Dictionary, bounds: Dictionary = {}, features: Array = [], persona_data: Dictionary = {}, enforce_environment := false, interior_data: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_storyline_npcs":
		errors.append("The storyline NPC file uses an unsupported format.")
	var npcs = data.get("npcs", [])
	if not npcs is Array:
		errors.append("The storyline NPC list is incomplete.")
		return {"passed": false, "errors": errors}
	var valid_personas: Dictionary = {}
	for value in persona_data.get("personas", []):
		if value is Dictionary:
			valid_personas[str(value.get("id", ""))] = str(value.get("actor_kind", ""))
	var ids: Dictionary = {}
	for value in npcs:
		if not value is Dictionary:
			errors.append("Every storyline NPC needs a complete record.")
			continue
		var npc: Dictionary = value
		var role := str(npc.get("npc_role", "storyline"))
		var actor_kind := str(npc.get("actor_kind", "npr" if role == "npr" else "npc"))
		if role not in ["storyline", "trader", "generic", "npr"] or actor_kind != ("npr" if role == "npr" else "npc"):
			errors.append("A placed character has an unsupported type.")
		var npc_id := str(npc.get("id", ""))
		if not npc_id.is_valid_identifier() or npc_id.to_lower() != npc_id or ids.has(npc_id):
			errors.append("Every storyline NPC needs a unique lower-case ID.")
		ids[npc_id] = true
		if str(npc.get("display_name", "")).strip_edges().is_empty():
			errors.append("Storyline NPC %s needs a display name." % npc_id)
		elif str(npc.get("display_name", "")).length() > 80 or str(npc.get("display_name", "")).contains("\n") or str(npc.get("display_name", "")).contains("\r"):
			errors.append("Storyline NPC %s has an invalid display name." % npc_id)
		var persona_id := str(npc.get("persona_id", ""))
		if not persona_data.is_empty() and str(valid_personas.get(persona_id, "")) != actor_kind:
			errors.append("Storyline NPC %s references a missing NPC persona." % npc_id)
		var location: Dictionary = npc.get("location", {})
		var location_space := str(location.get("space", ""))
		if location_space == "outdoors":
			var safety := SpawnSafetyScript.validate_outdoor_actor_location(location, features, bounds)
			if not safety.ok:
				var safety_message := "Storyline NPC %s needs placement review: %s" % [npc_id, safety.message]
				if enforce_environment:
					errors.append(safety_message)
				else:
					warnings.append(safety_message)
		elif location_space == "interior":
			var interior_validation := BuildingInteriorStoreScript.new().validate_location(interior_data, location)
			if not interior_validation.ok:
				errors.append("Storyline NPC %s needs interior placement review: %s" % [npc_id, interior_validation.message])
		else:
			errors.append("Storyline NPC %s has an unsupported location type." % npc_id)
		var appearance: Dictionary = npc.get("appearance", {})
		if str(appearance.get("mode", "")) != "random_static_asset" or str(appearance.get("npc_asset", "")).is_empty():
			errors.append("Storyline NPC %s needs its random static appearance." % npc_id)
		elif actor_kind == "npr":
			if str(appearance.get("npc_asset", "")) != "npr": errors.append("NPR %s must use robot artwork." % npc_id)
		else:
			var gender := str(appearance.get("gender", ""))
			var age_group := str(appearance.get("age_group", ""))
			var skin_tone := str(appearance.get("skin_tone_group", ""))
			if gender not in ["man", "woman"] or age_group not in AGE_GROUPS or skin_tone not in SKIN_TONES:
				errors.append("Storyline NPC %s has an unsupported random appearance." % npc_id)
			elif str(appearance.get("npc_asset", "")) != "npc_%s_%s_%s" % [skin_tone, gender, age_group]:
				errors.append("Storyline NPC %s has an artwork key that does not match its saved random appearance." % npc_id)
	return {"passed": errors.is_empty(), "errors": errors, "warnings": warnings, "storyline_npc_count": npcs.size()}
