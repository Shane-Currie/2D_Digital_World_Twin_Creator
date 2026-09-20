# Belconnen collision test data

`source_osm/belconnen_university_town_centre.osm` is the active bounded OpenStreetMap XML extract used to verify the map-independent building-collision/runtime pipeline. It covers API bbox `149.055,-35.245,149.090,-35.225`, extending from Belconnen Town Centre east across the University of Canberra campus and Cooper Lodge. It is not the whole Belconnen district or the whole ACT. The earlier smaller `belconnen_town_centre.osm` is retained as test history.

The player start is on safety-checked exterior ground beside Cooper Lodge's Telita Street frontage. OSM way `297173255` identifies the named building, but the current OSM data has no entrance node on that footprint; the location must not be represented as a surveyed doorway. The nearby player-wagon position is selected by the ordinary map-independent spawn-safety logic.

The repeatable Godot check is `res://tools/tests/verify_belconnen_building_collisions.gd`. Results are written to `reports/building_collision_validation.json`, and the loadable Creator project is written to `../../../../test/belconnen_collision_test/`.

Data © OpenStreetMap contributors, available under ODbL 1.0. See https://www.openstreetmap.org/copyright.
