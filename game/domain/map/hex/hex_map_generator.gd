extends RefCounted
class_name HexMapGenerator

const HexTileScript := preload("res://game/domain/map/hex/hex_tile.gd")
const TERRAIN_DEFS_PATH := "res://data/demo/hex_map/terrain_defs.json"
const RESOURCE_DEFS_PATH := "res://data/demo/hex_map/resource_defs.json"

const TERRAIN_PLAIN := "plain"
const TERRAIN_FOREST := "forest"
const TERRAIN_HILL := "hill"
const TERRAIN_WATER := "water"
const TERRAIN_RUIN := "ruin"
const TERRAIN_HOLY_SITE := "holy_site"
const HEX_DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var terrain_defs: Dictionary = {}
var resource_defs: Dictionary = {}
var rng := RandomNumberGenerator.new()
var map_radius := 4
var forest_anchor := Vector2i.ZERO
var hill_anchor := Vector2i.ZERO
var ruin_anchor := Vector2i.ZERO
var wetland_anchor := Vector2i.ZERO
var river_offset := 0


func generate(radius: int, seed_value: int = 20260625) -> Dictionary:
	rng.seed = seed_value
	map_radius = radius
	_prepare_regions(radius)
	_load_defs()
	var tiles: Dictionary = {}
	for q in range(-radius, radius + 1):
		var r_min: int = max(-radius, -q - radius)
		var r_max: int = min(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			var coord := Vector2i(q, r)
			var terrain: String = _pick_terrain(coord)
			var resources: Array = _pick_resources_for_terrain(terrain, _resource_richness(coord, terrain))
			tiles[coord] = HexTileScript.new(coord, terrain, terrain_defs.get(terrain, {}), resources)
	var origin_resources: Array = [resource_defs.get("relic_shard", {})]
	tiles[Vector2i.ZERO] = HexTileScript.new(
		Vector2i.ZERO,
		TERRAIN_HOLY_SITE,
		terrain_defs.get(TERRAIN_HOLY_SITE, {}),
		origin_resources
	)
	return {
		"tiles": tiles,
		"terrain_defs": terrain_defs.duplicate(true),
		"resource_defs": resource_defs.duplicate(true),
	}


func _prepare_regions(radius: int) -> void:
	var inner: int = max(2, radius - 2)
	forest_anchor = Vector2i(HEX_DIRECTIONS[3]) * inner + Vector2i(0, 1)
	hill_anchor = Vector2i(HEX_DIRECTIONS[0]) * inner + Vector2i(0, -1)
	ruin_anchor = Vector2i(HEX_DIRECTIONS[5]) * inner + Vector2i(1, 0)
	wetland_anchor = Vector2i(HEX_DIRECTIONS[1]) * inner + Vector2i(-1, 0)
	river_offset = rng.randi_range(-1, 1)


func _load_defs() -> void:
	if not terrain_defs.is_empty() and not resource_defs.is_empty():
		return
	terrain_defs.clear()
	resource_defs.clear()
	for terrain_def in _read_json_array(TERRAIN_DEFS_PATH):
		if typeof(terrain_def) == TYPE_DICTIONARY:
			terrain_defs[str(terrain_def.get("id", ""))] = terrain_def
	for resource_def in _read_json_array(RESOURCE_DEFS_PATH):
		if typeof(resource_def) == TYPE_DICTIONARY:
			resource_defs[str(resource_def.get("id", ""))] = resource_def


func _read_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON file: " + path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("JSON file must be an array: " + path)
		return []
	return parsed


func _pick_terrain(coord: Vector2i) -> String:
	if coord == Vector2i.ZERO:
		return TERRAIN_HOLY_SITE
	var distance := _hex_distance(Vector2i.ZERO, coord)
	var edge_depth := map_radius - distance
	if distance <= 1:
		return TERRAIN_PLAIN if rng.randf() < 0.72 else TERRAIN_FOREST
	if _is_river_tile(coord, distance) and rng.randf() < 0.82:
		return TERRAIN_WATER
	if _hex_distance(coord, ruin_anchor) <= 1 and rng.randf() < 0.72:
		return TERRAIN_RUIN
	if _hex_distance(coord, forest_anchor) <= 2 and rng.randf() < 0.78:
		return TERRAIN_FOREST
	if _hex_distance(coord, hill_anchor) <= 2 and rng.randf() < 0.78:
		return TERRAIN_HILL
	if _hex_distance(coord, wetland_anchor) <= 2 and rng.randf() < 0.56:
		return TERRAIN_WATER
	if edge_depth <= 0 and rng.randf() < 0.25:
		return TERRAIN_WATER
	if edge_depth <= 1 and rng.randf() < 0.14:
		return TERRAIN_RUIN
	var roll := rng.randf()
	if distance >= map_radius - 1 and roll < 0.16:
		return TERRAIN_RUIN
	if roll < 0.26:
		return TERRAIN_FOREST
	if roll < 0.48:
		return TERRAIN_HILL
	return TERRAIN_PLAIN


func _is_river_tile(coord: Vector2i, distance: int) -> bool:
	if distance <= 1:
		return false
	var river_line := coord.x + 2 * coord.y + river_offset
	if abs(river_line) <= 1:
		return true
	return distance >= map_radius - 1 and abs(river_line) <= 2


func _resource_richness(coord: Vector2i, terrain: String) -> int:
	if terrain == TERRAIN_WATER:
		return 1 if rng.randf() < 0.36 else 0
	var distance := _hex_distance(Vector2i.ZERO, coord)
	var richness := 0
	if rng.randf() < 0.56:
		richness += 1
	if distance >= 3 and rng.randf() < 0.18:
		richness += 1
	if terrain == TERRAIN_RUIN or _hex_distance(coord, forest_anchor) <= 1 or _hex_distance(coord, hill_anchor) <= 1:
		if rng.randf() < 0.28:
			richness += 1
	return min(richness, 2)


func _pick_resources_for_terrain(terrain: String, richness: int = 1) -> Array:
	if richness <= 0:
		return []
	if terrain == TERRAIN_WATER and rng.randf() > 0.28:
		return []
	var candidates: Array[Dictionary] = []
	var total_weight := 0
	for resource_def in resource_defs.values():
		var allowed: Array = resource_def.get("allowed_terrains", [])
		if allowed.has(terrain):
			var weight := int(resource_def.get("spawn_weight", 1))
			total_weight += weight
			candidates.append({
				"resource": resource_def,
				"weight": weight,
			})
	if candidates.is_empty() or total_weight <= 0:
		return []
	var picked: Array = []
	for i in range(richness):
		var resource := _pick_weighted_resource(candidates, total_weight)
		if resource.is_empty():
			continue
		var resource_id := str(resource.get("id", ""))
		var already_picked := false
		for existing in picked:
			if typeof(existing) == TYPE_DICTIONARY and str(existing.get("id", "")) == resource_id:
				already_picked = true
				break
		if not already_picked:
			picked.append(resource)
	return picked


func _pick_weighted_resource(candidates: Array[Dictionary], total_weight: int) -> Dictionary:
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for candidate in candidates:
		cursor += int(candidate["weight"])
		if roll <= cursor:
			return candidate["resource"]
	return {}


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -a.x - a.y - (-b.x - b.y)
	return max(abs(dq), abs(dr), abs(ds))
