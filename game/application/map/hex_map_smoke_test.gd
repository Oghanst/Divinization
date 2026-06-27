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
	_assert(int(map.card_controller.resources.get("materials", 0)) == 2, "map material syncs to cards")
	_assert(int(map.map_state.inventory.get("relic_fragment", 0)) == 1, "gather adds backpack item")
	_assert(map.tiles[origin].has_state("depleted"), "gather marks tile depleted")

	var faith_before_card := int(map.map_state.global_resources.get("faith", 0))
	var followers_before_card := int(map.map_state.global_resources.get("followers", 0))
	var pressure_before_card: int = map.map_state.secrecy_pressure
	map.card_controller.hand = ["private_preach"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.play_card(0)
	_assert(int(map.map_state.global_resources.get("faith", 0)) == faith_before_card + 1, "card faith syncs to map")
	_assert(int(map.map_state.global_resources.get("followers", 0)) == followers_before_card + 1, "card followers sync to map")
	_assert(map.map_state.secrecy_pressure == pressure_before_card + 1, "card exposure syncs to secrecy pressure")

	var clues_before_card := int(map.map_state.inventory.get("suspicious_clue", 0))
	map.card_controller.hand = ["observe_symptoms"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.play_card(0)
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == clues_before_card + 1, "card source clue syncs to backpack")

	map._on_map_action_requested("build_secret_shrine")
	_assert(map.tiles[origin].has_building("secret_shrine"), "building adds secret shrine")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == 0, "building spends materials")
	_assert(int(map.card_controller.resources.get("materials", 0)) == 0, "building spend syncs to cards")

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
	var clues_before_investigate := int(map.map_state.inventory.get("suspicious_clue", 0))
	map._on_map_action_requested("investigate")
	_assert(map.tiles[neighbor].explored, "investigate explores current tile")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == clues_before_investigate + 1, "investigate adds clue item")

	var pressure_before: int = map.map_state.secrecy_pressure
	map._on_map_action_requested("hide")
	_assert(map.map_state.secrecy_pressure < pressure_before, "hide lowers secrecy pressure")

	var life_before: int = map.map_state.life
	map._on_map_action_requested("rest")
	_assert(map.map_state.life >= life_before, "rest does not reduce life")

	var event_tile: RefCounted = map.tiles[map.map_state.player_coord]
	map.map_state.action_points = 1
	map.card_controller.pending_event = {
		"id": "smoke_event",
		"name": "烟测预兆",
		"text": "一个用于烟测的预兆。",
		"effects": [
			{"kind": "map_tile_state", "state": "plague"}
		],
		"handled_effects": [
			{"kind": "map_tile_state", "state": "panic"},
			{"kind": "log", "text": "测试事件被主动处理。"}
		],
	}
	_assert(_action_enabled(map._build_actions(), "handle_pending_event"), "pending event enables handling action")
	map._on_map_action_requested("handle_pending_event")
	_assert(map.card_controller.pending_event.is_empty(), "handling clears pending event")
	_assert(map.map_state.action_points == 0, "handling spends action point")
	_assert(event_tile.has_state("panic"), "handled event applies map tile state")
	_assert(not event_tile.has_state("plague"), "handled event does not apply ignored effect")
	_assert(_has_log_prefix(map.event_log, "事件：测试事件"), "handled event writes map log")

	map.map_state.action_points = 1
	var death_before_convert := int(map.map_state.route_affinity.get("death", 0))
	map.card_controller.pending_event = {
		"id": "convert_event",
		"name": "转化烟测",
		"text": "一个用于转化的预兆。",
		"converted_effects": [
			{"kind": "progress", "key": "death_route", "value": 1},
			{"kind": "log", "text": "测试事件被转化。"}
		],
	}
	_assert(_action_enabled(map._build_actions(), "convert_pending_event"), "pending event enables convert action")
	map._on_map_action_requested("convert_pending_event")
	_assert(map.card_controller.pending_event.is_empty(), "converting clears pending event")
	_assert(int(map.map_state.route_affinity.get("death", 0)) == death_before_convert + 1, "converting adds route affinity")
	_assert(_has_log_prefix(map.event_log, "事件：测试事件被转化"), "converted event writes map log")

	map.card_controller.pending_event = {
		"id": "ignore_event",
		"name": "放任烟测",
		"text": "一个用于放任的预兆。",
		"effects": [
			{"kind": "map_tile_state", "state": "enemy_attention"},
			{"kind": "log", "text": "测试事件被放任。"}
		],
	}
	_assert(_action_enabled(map._build_actions(), "ignore_pending_event"), "pending event enables ignore action")
	map._on_map_action_requested("ignore_pending_event")
	_assert(map.card_controller.pending_event.is_empty(), "ignoring clears pending event")
	_assert(event_tile.has_state("enemy_attention"), "ignoring applies event effects")
	_assert(_has_log_prefix(map.event_log, "事件：测试事件被放任"), "ignored event writes map log")

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

	map.card_controller.progress["cure_progress"] = 3
	map.card_controller.progress["source_clues"] = 2
	var preview_snapshot: Dictionary = map._build_ui_snapshot()
	_assert(_preview_ready(preview_snapshot.get("crisis_preview", []), "resolve_cleanse_plague"), "snapshot previews prepared cleanse option")
	map.map_state.event_countdown = 1
	map._advance_stage_event()
	_assert(map.map_state.crisis_active, "stage countdown opens crisis")
	var crisis_actions: Array = map._build_actions()
	_assert(_action_enabled(crisis_actions, "resolve_cleanse_plague"), "prepared cure enables cleanse option")
	map._on_map_action_requested("resolve_cleanse_plague")
	_assert(map.map_state.stage_resolved, "crisis resolution marks stage resolved")
	_assert(map.map_state.stage_result_id == "resolve_cleanse_plague", "crisis stores result id")
	_assert(entrance_tile.has_state("blessed"), "cleanse blesses crisis tile")
	_assert(not entrance_tile.has_state("plague"), "cleanse removes plague")
	_assert(int(map.map_state.route_affinity.get("life", 0)) >= 2, "cleanse adds life route affinity")

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


func _action_enabled(actions: Array, action_id: String) -> bool:
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY and str(action.get("id", "")) == action_id:
			return bool(action.get("enabled", false))
	return false


func _preview_ready(previews: Array, action_id: String) -> bool:
	for preview in previews:
		if typeof(preview) == TYPE_DICTIONARY and str(preview.get("id", "")) == action_id:
			return bool(preview.get("ready", false))
	return false


func _has_log_prefix(messages: Array, prefix: String) -> bool:
	for message in messages:
		if str(message).begins_with(prefix):
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("HEX_MAP_SMOKE_FAIL: " + message)
	get_tree().quit(1)
