class_name RuntimeActorArt
extends RefCounted

## Transparent production sprites shared by every imported town. Keep the
## drawing rectangles in the caller so artwork never changes collision size.
## Ground characters share one smaller world-space box. Its bottom edge is the
## actor position, so different source images cannot change apparent height or
## make feet float above/below the path.
const GROUND_CHARACTER_DRAW_SIZE := Vector2(7.5, 13.75)
const PATHS := {
	"player": "res://assets/actors/player_v2.png",
	"npr": "res://assets/actors/npr_v2.png",
	"npd": "res://assets/actors/npd_v2.png",
	"wagon": "res://assets/actors/wagon_v2.png",
	"npc_light_man_young": "res://assets/actors/npc_light_man_young_v3.png",
	"npc_light_man_adult": "res://assets/actors/npc_light_man_adult_v3.png",
	"npc_light_man_older": "res://assets/actors/npc_light_man_older_v3.png",
	"npc_light_woman_young": "res://assets/actors/npc_light_woman_young_v3.png",
	"npc_light_woman_adult": "res://assets/actors/npc_light_woman_adult_v3.png",
	"npc_light_woman_older": "res://assets/actors/npc_light_woman_older_v3.png",
	"npc_medium_man_young": "res://assets/actors/npc_medium_man_young_v3.png",
	"npc_medium_man_adult": "res://assets/actors/npc_medium_man_adult_v3.png",
	"npc_medium_man_older": "res://assets/actors/npc_medium_man_older_v3.png",
	"npc_medium_woman_young": "res://assets/actors/npc_medium_woman_young_v3.png",
	"npc_medium_woman_adult": "res://assets/actors/npc_medium_woman_adult_v3.png",
	"npc_medium_woman_older": "res://assets/actors/npc_medium_woman_older_v3.png",
	"npc_dark_man_young": "res://assets/actors/npc_dark_man_young_v3.png",
	"npc_dark_man_adult": "res://assets/actors/npc_dark_man_adult_v3.png",
	"npc_dark_man_older": "res://assets/actors/npc_dark_man_older_v3.png",
	"npc_dark_woman_young": "res://assets/actors/npc_dark_woman_young_v3.png",
	"npc_dark_woman_adult": "res://assets/actors/npc_dark_woman_adult_v3.png",
	"npc_dark_woman_older": "res://assets/actors/npc_dark_woman_older_v3.png",
	"car_sedan_blue": "res://assets/actors/car_sedan_blue_v3.png",
	"car_sedan_red": "res://assets/actors/car_sedan_red_v3.png",
	"car_sedan_silver": "res://assets/actors/car_sedan_silver_v3.png",
	"car_sedan_green": "res://assets/actors/car_sedan_green_v3.png",
	"car_wagon_white": "res://assets/actors/car_wagon_white_v3.png",
	"car_wagon_blue": "res://assets/actors/car_wagon_blue_v3.png",
	"car_wagon_bronze": "res://assets/actors/car_wagon_bronze_v3.png",
	"car_wagon_grey": "res://assets/actors/car_wagon_grey_v3.png",
	"car_ute_red": "res://assets/actors/car_ute_red_v3.png",
	"car_ute_blue": "res://assets/actors/car_ute_blue_v3.png",
	"car_ute_white": "res://assets/actors/car_ute_white_v3.png",
	"car_ute_green": "res://assets/actors/car_ute_green_v3.png"
}

## Directional atlases keep identity and outfit choices static while giving
## walking actors honest front, side and back views. Columns are ordered
## down, left, right, up. Player/NPR rows are walk frames; NPC rows are ages.
const DIRECTIONAL_ATLASES := {
	"player": {"path": "res://assets/actors/directional/player_directional_v4.png", "columns": 4, "rows": 4, "animated": true},
	"npr": {"path": "res://assets/actors/directional/npr_directional_v4.png", "columns": 4, "rows": 4, "animated": true},
	"npc_light_man": {"path": "res://assets/actors/directional/npc_light_man_directional_v4.png", "columns": 4, "rows": 3},
	"npc_light_woman": {"path": "res://assets/actors/directional/npc_light_woman_directional_v4.png", "columns": 4, "rows": 3},
	"npc_medium_man": {"path": "res://assets/actors/directional/npc_medium_man_directional_v4.png", "columns": 4, "rows": 3},
	"npc_medium_woman": {"path": "res://assets/actors/directional/npc_medium_woman_directional_v4.png", "columns": 4, "rows": 3},
	"npc_dark_man": {"path": "res://assets/actors/directional/npc_dark_man_directional_v4.png", "columns": 4, "rows": 3},
	"npc_dark_woman": {"path": "res://assets/actors/directional/npc_dark_woman_directional_v4.png", "columns": 4, "rows": 3}
}
const AGE_ROWS := {"young": 0, "adult": 1, "older": 2}

static var cached_sprites: Dictionary = {}
static var cached_directional_atlases: Dictionary = {}


static func grounded_character_rect() -> Rect2:
	return Rect2(
		-GROUND_CHARACTER_DRAW_SIZE.x * 0.5,
		-GROUND_CHARACTER_DRAW_SIZE.y,
		GROUND_CHARACTER_DRAW_SIZE.x,
		GROUND_CHARACTER_DRAW_SIZE.y
	)


static func sprite(kind: String) -> Dictionary:
	if cached_sprites.has(kind):
		return cached_sprites[kind]
	var image := Image.load_from_file(str(PATHS.get(kind, "")))
	if image == null or image.is_empty():
		cached_sprites[kind] = {}
		return {}
	# The delivered PNGs have transparent padding. Crop only the draw region;
	# leave the original source PNG and its alpha untouched.
	var used_region := _subject_region(image, kind)
	if used_region.size.x <= 0 or used_region.size.y <= 0:
		cached_sprites[kind] = {}
		return {}
	var result := {
		"texture": ImageTexture.create_from_image(image),
		"region": Rect2(used_region)
	}
	cached_sprites[kind] = result
	return result


static func directional_sprite(kind: String, facing: Vector2, frame: int = 0) -> Dictionary:
	var atlas_key := kind
	var row := frame
	if kind.begins_with("npc_"):
		var parts := kind.split("_")
		if parts.size() != 4:
			return sprite(kind)
		atlas_key = "npc_%s_%s" % [parts[1], parts[2]]
		row = int(AGE_ROWS.get(parts[3], 1))
	if not DIRECTIONAL_ATLASES.has(atlas_key):
		return sprite(kind)
	var atlas := _directional_atlas(atlas_key)
	if atlas.is_empty():
		return sprite(kind)
	var columns := int(atlas.columns)
	var rows := int(atlas.rows)
	row = clampi(row, 0, rows - 1)
	var column := direction_column(facing)
	var region_key := "%d:%d" % [column, row]
	var regions: Dictionary = atlas.regions
	if not regions.has(region_key):
		regions[region_key] = _directional_cell_region(atlas.image, column, row, columns, rows)
		atlas.regions = regions
		cached_directional_atlases[atlas_key] = atlas
	var region: Rect2i = regions[region_key]
	if not region.has_area():
		return sprite(kind)
	return {"texture": atlas.texture, "region": Rect2(region)}


static func direction_column(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 2 if facing.x > 0.0 else 1
	return 3 if facing.y < 0.0 else 0


static func _directional_atlas(atlas_key: String) -> Dictionary:
	if cached_directional_atlases.has(atlas_key):
		return cached_directional_atlases[atlas_key]
	var config: Dictionary = DIRECTIONAL_ATLASES.get(atlas_key, {})
	var image := Image.load_from_file(str(config.get("path", "")))
	if image == null or image.is_empty():
		cached_directional_atlases[atlas_key] = {}
		return {}
	var atlas := {
		"image": image,
		"texture": ImageTexture.create_from_image(image),
		"columns": int(config.get("columns", 4)),
		"rows": int(config.get("rows", 1)),
		"regions": {}
	}
	cached_directional_atlases[atlas_key] = atlas
	return atlas


static func _directional_cell_region(image: Image, column: int, row: int, columns: int, rows: int) -> Rect2i:
	# Some generated sheets have dimensions that are not exact grid multiples.
	# Proportional integer boundaries include every source pixel without overlap.
	var x0 := floori(float(column) * image.get_width() / columns)
	var x1 := floori(float(column + 1) * image.get_width() / columns)
	var y0 := floori(float(row) * image.get_height() / rows)
	var y1 := floori(float(row + 1) * image.get_height() / rows)
	var cell := Rect2i(x0, y0, x1 - x0, y1 - y0)
	var cell_image := image.get_region(cell)
	var used := cell_image.get_used_rect()
	if not used.has_area():
		return Rect2i()
	var padding := 2
	var used_start := Vector2i(maxi(0, used.position.x - padding), maxi(0, used.position.y - padding))
	var used_end := Vector2i(
		mini(cell.size.x, used.end.x + padding),
		mini(cell.size.y, used.end.y + padding)
	)
	return Rect2i(cell.position + used_start, used_end - used_start)


static func _subject_region(image: Image, kind: String) -> Rect2i:
	var alpha_region := image.get_used_rect()
	if not kind.begins_with("car_") and not kind.begins_with("npc_"):
		return alpha_region
	# Generated cut-outs can retain a large, faint transparent glow. Treat the
	# solid painted subject as the crop so every catalogue entry reaches the
	# same gameplay scale. Sampling every fourth source pixel keeps startup fast.
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	var sample_step := 4
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			if image.get_pixel(x, y).a < 0.6:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return alpha_region
	var padding := 8
	var start := Vector2i(maxi(0, minimum.x - padding), maxi(0, minimum.y - padding))
	var finish := Vector2i(
		mini(image.get_width(), maximum.x + sample_step + padding),
		mini(image.get_height(), maximum.y + sample_step + padding)
	)
	return Rect2i(start, finish - start)
