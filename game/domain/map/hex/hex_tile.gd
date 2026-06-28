extends RefCounted
class_name HexTile

const TERRAIN_WATER := "water"

var coord: Vector2i
var terrain: String
var terrain_name: String
var terrain_texture_path: String = ""
var resource_ids: Array[String] = []
var resource_names: Array[String] = []
var resource_icons: Array[String] = []
var resource_texture_paths: Array[String] = []
var owner: String = ""
var population: int = 0
var faith: int = 0
var production: int = 0
var food: int = 0
var buildings: Array[String] = []
var states: Array[String] = []
var hidden_states: Array[String] = []
var revealed: bool = true
var explored: bool = false
var dungeon_entrance_id: String = ""
var dungeon_entrance_name: String = ""
var entrance_revealed: bool = false
var site_id: String = ""
var site_name: String = ""
var site_description: String = ""


func _init(
	hex_coord: Vector2i,
	terrain_type: String,
	terrain_def: Dictionary = {},
	tile_resource_defs: Array = []
) -> void:
	coord = hex_coord
	terrain = terrain_type
	terrain_name = str(terrain_def.get("name", terrain_type))
	terrain_texture_path = str(terrain_def.get("texture", ""))
	_apply_yields(terrain_def, tile_resource_defs)


func claim(new_owner: String) -> void:
	owner = new_owner
	if population == 0 and terrain != TERRAIN_WATER:
		population = 1


func is_passable() -> bool:
	return terrain != TERRAIN_WATER


func reveal_details() -> Dictionary:
	explored = true
	var revealed_states: Array[String] = hidden_states.duplicate()
	for state_id in revealed_states:
		add_state(state_id)
	hidden_states.clear()
	if dungeon_entrance_id != "":
		entrance_revealed = true
	return {
		"states": revealed_states,
		"entrance": dungeon_entrance_name if entrance_revealed else "",
	}


func add_building(building_id: String, yield_bonus: Dictionary = {}) -> bool:
	if building_id.is_empty() or buildings.has(building_id):
		return false
	buildings.append(building_id)
	_apply_yield_bonus(yield_bonus)
	return true


func has_building(building_id: String) -> bool:
	return buildings.has(building_id)


func has_core_building() -> bool:
	return not buildings.is_empty()


func add_state(state_id: String) -> bool:
	if state_id.is_empty() or states.has(state_id):
		return false
	states.append(state_id)
	return true


func remove_state(state_id: String) -> bool:
	var index := states.find(state_id)
	if index < 0:
		return false
	states.remove_at(index)
	return true


func has_state(state_id: String) -> bool:
	return states.has(state_id)


func set_dungeon_entrance(entrance_id: String, entrance_name: String) -> void:
	dungeon_entrance_id = entrance_id
	dungeon_entrance_name = entrance_name


func set_site(new_site_id: String, new_site_name: String, new_site_description: String = "") -> void:
	site_id = new_site_id
	site_name = new_site_name
	site_description = new_site_description


func has_visible_entrance() -> bool:
	return dungeon_entrance_id != "" and entrance_revealed


func get_yields() -> Dictionary:
	return {
		"food": food,
		"production": production,
		"faith": faith,
	}


func get_info() -> Dictionary:
	return {
		"coord": coord,
		"terrain": terrain,
		"terrain_name": terrain_name,
		"terrain_texture_path": terrain_texture_path,
		"resources": resource_names.duplicate(),
		"resource_texture_paths": resource_texture_paths.duplicate(),
		"owner": owner,
		"population": population,
		"buildings": buildings.duplicate(),
		"states": states.duplicate(),
		"hidden_states": hidden_states.duplicate(),
		"revealed": revealed,
		"explored": explored,
		"dungeon_entrance_id": dungeon_entrance_id,
		"dungeon_entrance_name": dungeon_entrance_name,
		"entrance_revealed": entrance_revealed,
		"site_id": site_id,
		"site_name": site_name,
		"site_description": site_description,
		"yields": get_yields(),
	}


func _apply_yields(terrain_def: Dictionary, tile_resource_defs: Array) -> void:
	_apply_yield_bonus(terrain_def.get("base_yields", {}))
	for resource_def in tile_resource_defs:
		if typeof(resource_def) != TYPE_DICTIONARY:
			continue
		resource_ids.append(str(resource_def.get("id", "")))
		resource_names.append(str(resource_def.get("name", "")))
		resource_icons.append(str(resource_def.get("icon", "")))
		resource_texture_paths.append(str(resource_def.get("texture", "")))
		_apply_yield_bonus(resource_def.get("yield_bonus", {}))


func _apply_yield_bonus(bonus: Variant) -> void:
	if typeof(bonus) != TYPE_DICTIONARY:
		return
	food += int(bonus.get("food", 0))
	production += int(bonus.get("production", 0))
	faith += int(bonus.get("faith", 0))
