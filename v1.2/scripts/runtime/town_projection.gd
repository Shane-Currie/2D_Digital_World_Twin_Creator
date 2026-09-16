class_name TownProjection
extends RefCounted


static func geographic_to_world(location: Vector2, projection: Dictionary, pixels_per_metre: float) -> Vector2:
	return Vector2(
		(location.x - float(projection.origin_longitude)) * float(projection.longitude_metres_per_degree),
		(float(projection.origin_latitude) - location.y) * float(projection.latitude_metres_per_degree)
	) * pixels_per_metre


static func value_to_location(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("longitude", 0.0)), float(value.get("latitude", 0.0)))
	return Vector2.ZERO
