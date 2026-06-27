extends Node

const MapScene := preload("res://scenes/map/hex_civilization_map.tscn")


func _ready() -> void:
	var map := MapScene.instantiate()
	add_child(map)
	await get_tree().process_frame

	var origin := Vector2i.ZERO
	_assert(map.map_state.player_coord == origin, "player starts at origin")
	_assert(map.map_state.action_points == 3, "action points start at 3")

	map._select_tile(origin)
	map._on_map_action_requested("gather")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == 2, "gather adds material")
	_assert(int(map.map_state.inventory.get("relic_fragment", 0)) == 1, "gather adds backpack item")
	_assert(map.tiles[origin].has_state("depleted"), "gather marks tile depleted")

	map._on_map_action_requested("build_secret_shrine")
	_assert(map.tiles[origin].has_building("secret_shrine"), "building adds secret shrine")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == 0, "building spends materials")

	var neighbor := _find_passable_neighbor(map, origin)
	_assert(map.tiles.has(neighbor), "has passable neighbor")
	map._on_primary_map_pressed(map.render_layer.to_global(map.render_layer.hex_to_pixel(neighbor)))
	_assert(map.map_state.player_coord == neighbor, "move changes player coord")
	_assert(map.map_state.action_points == 0, "move spends last action point")

	var faith_before := int(map.map_state.global_resources.get("faith", 0))
	map._on_map_action_requested("end_turn")
	_assert(map.map_state.action_points == 3, "end turn restores action points")
	_assert(int(map.map_state.global_resources.get("faith", 0)) > faith_before, "end turn adds shrine faith")

	map._select_tile(neighbor)
	map.tiles[neighbor].hidden_states.append("polluted")
	map._on_map_action_requested("investigate")
	_assert(map.tiles[neighbor].explored, "investigate explores current tile")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == 1, "investigate adds clue item")

	var pressure_before: int = map.map_state.secrecy_pressure
	map._on_map_action_requested("hide")
	_assert(map.map_state.secrecy_pressure < pressure_before, "hide lowers secrecy pressure")

	var life_before: int = map.map_state.life
	map._on_map_action_requested("rest")
	_assert(map.map_state.life >= life_before, "rest does not reduce life")

	var entrance_coord := _find_tile_with_entrance(map)
	_assert(map.tiles.has(entrance_coord), "map has entrance tile")
	map.map_state.player_coord = entrance_coord
	map.map_state.selected_coord = entrance_coord
	map.render_layer.set_player_coord(entrance_coord)
	var entrance_tile: RefCounted = map.tiles[entrance_coord]
	entrance_tile.explored = true
	entrance_tile.entrance_revealed = true
	map._on_map_action_requested("enter_encounter")
	_assert(entrance_tile.has_state("encounter_active"), "enter encounter marks tile")

	print("HEX_MAP_SMOKE_OK")
	get_tree().quit()


func _find_passable_neighbor(map: Node, origin: Vector2i) -> Vector2i:
	for coord in map.tiles.keys():
		if map._are_neighbors(origin, coord) and map.tiles[coord].is_passable():
			return coord
	return Vector2i(999, 999)


func _find_tile_with_entrance(map: Node) -> Vector2i:
	for coord in map.tiles.keys():
		if map.tiles[coord].dungeon_entrance_id != "":
			return coord
	return Vector2i(999, 999)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("HEX_MAP_SMOKE_FAIL: " + message)
	get_tree().quit(1)
