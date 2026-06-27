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

var terrain_defs: Dictionary = {}
var resource_defs: Dictionary = {}
var rng := RandomNumberGenerator.new()


func generate(radius: int, seed_value: int = 20260625) -> Dictionary:
	rng.seed = seed_value
	_load_defs()
	var tiles: Dictionary = {}
	for q in range(-radius, radius + 1):
		var r_min: int = max(-radius, -q - radius)
		var r_max: int = min(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			var coord := Vector2i(q, r)
			var terrain: String = _pick_terrain(q, r, radius)
			var resources: Array = _pick_resources_for_terrain(terrain)
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


func _pick_terrain(q: int, r: int, radius: int) -> String:
	var distance: int = max(abs(q), abs(r), abs(-q - r))
	if distance == radius and rng.randf() < 0.22:
		return TERRAIN_WATER
	var roll := rng.randf()
	if roll < 0.12:
		return TERRAIN_RUIN
	if roll < 0.34:
		return TERRAIN_FOREST
	if roll < 0.55:
		return TERRAIN_HILL
	return TERRAIN_PLAIN


func _pick_resources_for_terrain(terrain: String) -> Array:
	if terrain == TERRAIN_WATER and rng.randf() > 0.28:
		return []
	if rng.randf() > 0.46:
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
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for candidate in candidates:
		cursor += int(candidate["weight"])
		if roll <= cursor:
			return [candidate["resource"]]
	return []
