class_name BuildingFootprintExporter
extends RefCounted

## Exports an imported building footprint as a Paint-friendly transparent PNG.
## The canvas keeps the footprint's real map proportions and north-up direction.

const LONGEST_EDGE_PIXELS := 2048
const MINIMUM_EDGE_PIXELS := 16
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0


func export_png(feature: Dictionary, destination_path: String) -> Dictionary:
	if str(feature.get("kind", "")) != "building":
		return {"ok": false, "message": "Select an imported building footprint before exporting a template."}
	var outer := _points(feature.get("points", []))
	if outer.size() < 3:
		return {"ok": false, "message": "That building does not contain a usable footprint shape."}
	var path_value := destination_path
	if path_value.get_extension().is_empty():
		path_value += ".png"
	if path_value.get_extension().to_lower() != "png":
		return {"ok": false, "message": "Footprint templates must be saved as PNG files so transparency is preserved."}
	var parent_directory := path_value.get_base_dir()
	if parent_directory.is_empty() or DirAccess.make_dir_recursive_absolute(parent_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the selected export folder."}

	var origin := _polygon_centre(outer)
	var projected_outer := _project_ring(outer, origin)
	var projected_holes: Array[PackedVector2Array] = []
	for hole_value in feature.get("holes", []):
		var hole := _points(hole_value)
		if hole.size() >= 3:
			projected_holes.append(_project_ring(hole, origin))
	var bounds := _bounds(projected_outer)
	if bounds.size.x <= 0.01 or bounds.size.y <= 0.01:
		return {"ok": false, "message": "That building footprint is too narrow to export safely."}
	var output_size := _output_size(bounds.size)
	var path_parts := PackedStringArray([_svg_ring(projected_outer, bounds, output_size)])
	for hole in projected_holes:
		path_parts.append(_svg_ring(hole, bounds, output_size))
	var stroke_width := maxf(2.0, float(maxi(output_size.x, output_size.y)) / 512.0)
	var svg := (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
		+ '<path d="%s" fill="#d8d1bf" fill-rule="evenodd" stroke="#34443d" stroke-width="%.2f" stroke-linejoin="round"/>'
		+ '</svg>'
	) % [output_size.x, output_size.y, output_size.x, output_size.y, " ".join(path_parts), stroke_width]
	var image := Image.create_empty(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	var load_error := image.load_svg_from_string(svg)
	if load_error != OK or image.is_empty():
		return {"ok": false, "message": "Creator Studio could not draw this footprint template."}
	var save_error := image.save_png(path_value)
	if save_error != OK:
		return {"ok": false, "message": "Creator Studio could not save the footprint PNG in that location."}
	return {
		"ok": true,
		"path": path_value,
		"width": output_size.x,
		"height": output_size.y,
		"message": "Building footprint template exported for Microsoft Paint."
	}


func suggested_file_name(feature: Dictionary) -> String:
	var display_name := str(feature.get("tags", {}).get("name", "building"))
	var safe_name := _safe_name(display_name)
	var feature_id := _safe_name(str(feature.get("id", "unknown")))
	return "%s_%s_footprint_template.png" % [safe_name, feature_id]


func _points(values: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Vector2:
			result.append(value)
		elif value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _polygon_centre(points: PackedVector2Array) -> Vector2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds.get_center()


func _project_ring(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(
			(point.x - origin.x) * longitude_scale,
			(origin.y - point.y) * METRES_PER_LATITUDE_DEGREE
		))
	return result


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _output_size(size_metres: Vector2) -> Vector2i:
	if size_metres.x >= size_metres.y:
		return Vector2i(LONGEST_EDGE_PIXELS, maxi(MINIMUM_EDGE_PIXELS, roundi(LONGEST_EDGE_PIXELS * size_metres.y / size_metres.x)))
	return Vector2i(maxi(MINIMUM_EDGE_PIXELS, roundi(LONGEST_EDGE_PIXELS * size_metres.x / size_metres.y)), LONGEST_EDGE_PIXELS)


func _svg_ring(points: PackedVector2Array, bounds: Rect2, output_size: Vector2i) -> String:
	var commands := PackedStringArray()
	for index in points.size():
		var normalized := (points[index] - bounds.position) / bounds.size
		var pixel := normalized * Vector2(output_size)
		commands.append("%s %.3f %.3f" % ["M" if index == 0 else "L", pixel.x, pixel.y])
	commands.append("Z")
	return " ".join(commands)


func _safe_name(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	result = result.trim_prefix("_").trim_suffix("_")
	return result if not result.is_empty() else "building"
