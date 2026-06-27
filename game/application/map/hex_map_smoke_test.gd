extends Node

const MapScene := preload("res://scenes/map/hex_civilization_map.tscn")


func _ready() -> void:
	var map := MapScene.instantiate()
	add_child(map)
	await get_tree().process_frame

	var origin := Vector2i.ZERO
	_assert(map.map_state.player_coord == origin, "player starts at origin")
	_assert(map.map_state.action_points == 3, "action points start at 3")
	_assert(map.card_controller.current_event_pool_id == "plague_outbreak", "initial stage uses plague event pool")

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

	map.map_state.action_points = 2
	map.map_state.add_item("medicinal_herb_bundle")
	var item_snapshot: Dictionary = map._build_ui_snapshot()
	_assert(_inventory_summary_contains(item_snapshot.get("inventory", []), "medicinal_herb_bundle", "治疗 +1"), "inventory previews item use effect")
	var cure_before_item := int(map.card_controller.progress.get("cure_progress", 0))
	map._on_map_action_requested("use_item:medicinal_herb_bundle")
	_assert(int(map.map_state.inventory.get("medicinal_herb_bundle", 0)) == 0, "using item consumes backpack item")
	_assert(map.map_state.action_points == 1, "using item spends action point")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_item + 1, "using herb advances cure progress")

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
	_assert(map.map_state.stage_reward_pending, "crisis resolution opens reward choices")
	var reward_snapshot: Dictionary = map._build_ui_snapshot()
	_assert(_reward_summary_contains(reward_snapshot.get("stage_reward_options", []), "village_gratitude_followers", "信徒 +2"), "reward snapshot previews follower reward")
	var followers_before_reward := int(map.map_state.global_resources.get("followers", 0))
	map._on_map_action_requested("claim_reward:village_gratitude_followers")
	_assert(not map.map_state.stage_reward_pending, "claiming reward clears reward pending")
	_assert(map.map_state.stage_reward_claimed, "claiming reward marks reward claimed")
	_assert(int(map.map_state.global_resources.get("followers", 0)) == followers_before_reward + 2, "reward grants followers")
	_assert(int(map.card_controller.resources.get("followers", 0)) == int(map.map_state.global_resources.get("followers", 0)), "reward syncs followers to cards")
	_assert(map.map_state.stage_node_pending, "claiming reward opens next node choices")
	var node_snapshot: Dictionary = map._build_ui_snapshot()
	_assert(_node_summary_contains(node_snapshot.get("stage_node_options", []), "old_well_source", "线索 +1"), "node snapshot previews old well clue")
	var inventory_clues_before_node := int(map.map_state.inventory.get("suspicious_clue", 0))
	var pressure_before_node: int = map.map_state.secrecy_pressure
	map._on_map_action_requested("choose_node:old_well_source")
	_assert(not map.map_state.stage_node_pending, "choosing node clears node pending")
	_assert(map.map_state.stage_node_id == "old_well_source", "choosing node stores node id")
	_assert(map.map_state.stage_node_name == "旧井病源", "choosing node stores node name")
	_assert(not map.map_state.stage_resolved, "choosing node resets stage resolved")
	_assert(map.map_state.event_countdown == 4, "choosing node sets node countdown")
	_assert(map.card_controller.countdown == 4, "choosing node syncs card countdown")
	_assert(map.map_state.event_summary.contains("旧井病源将在 4 回合后扩散"), "choosing node updates event summary")
	_assert(map.card_controller.current_event_pool_id == "old_well_source_spread", "old well node uses old well event pool")
	_assert(_pending_event_from_pool(map.card_controller.pending_event, ["old_well_black_water", "old_well_name_echo"]), "old well pending event comes from old well pool")
	_assert(int(map.card_controller.progress.get("source_clues", 0)) == 1, "node start effect seeds source clue progress")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == inventory_clues_before_node + 1, "node start effect adds clue item")
	_assert(map.map_state.secrecy_pressure == pressure_before_node + 1, "node start effect adds secrecy pressure")
	map.map_state.action_points = 1
	map.card_controller.pending_event = _event_from_pool(map, "old_well_source_spread", "old_well_name_echo")
	var locked_route_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(locked_route_preview.get("pending_event_response_preview", []), "handled", "未解锁 隐秘倾向 0/1"), "locked route bonus appears in pending event preview")
	map.map_state.add_item("ancient_bark")
	map._on_map_action_requested("use_item:ancient_bark")
	_assert(int(map.map_state.inventory.get("ancient_bark", 0)) == 0, "using ancient bark consumes item")
	_assert(int(map.map_state.route_bonus_threshold_mods.get("secret", 0)) == -1, "ancient bark lowers secret route bonus threshold")
	map.map_state.action_points = 1
	map.card_controller.pending_event = _event_from_pool(map, "old_well_source_spread", "old_well_name_echo")
	var route_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_preview_contains(route_preview.get("pending_event_response_preview", []), "handled", "路线加成"), "route bonus appears in pending event preview")
	_assert(_response_bonus_status_contains(route_preview.get("pending_event_response_preview", []), "handled", "已解锁 隐秘倾向 0/0"), "threshold item unlocks route bonus preview")
	var clues_before_route_bonus := int(map.card_controller.progress.get("source_clues", 0))
	var secret_before_route_bonus := int(map.map_state.route_affinity.get("secret", 0))
	map._on_map_action_requested("handle_pending_event")
	_assert(int(map.card_controller.progress.get("source_clues", 0)) == clues_before_route_bonus + 2, "secret route bonus adds extra source clue")
	_assert(int(map.map_state.route_affinity.get("secret", 0)) == secret_before_route_bonus + 1, "secret route bonus syncs route affinity")
	map.card_controller.progress["source_clues"] = 2
	var old_well_preview: Dictionary = map._build_ui_snapshot()
	_assert(_preview_ready(old_well_preview.get("crisis_preview", []), "resolve_claim_source_name"), "old well crisis previews prepared source-name option")
	map.map_state.event_countdown = 1
	map._advance_stage_event()
	_assert(map.map_state.crisis_active, "old well countdown opens crisis")
	var old_well_actions: Array = map._build_actions()
	_assert(_action_enabled(old_well_actions, "resolve_claim_source_name"), "old well source-name option is enabled")
	_assert(not _action_exists(old_well_actions, "resolve_cleanse_plague"), "old well crisis does not show plague cleanse action")
	var secret_before_well := int(map.map_state.route_affinity.get("secret", 0))
	map._on_map_action_requested("resolve_claim_source_name")
	_assert(map.map_state.stage_resolved, "old well crisis resolution marks stage resolved")
	_assert(map.map_state.stage_result_id == "resolve_claim_source_name", "old well crisis stores result id")
	_assert(int(map.map_state.route_affinity.get("secret", 0)) == secret_before_well + 3, "old well source-name result adds secret route")
	_assert(map.map_state.stage_reward_pending, "old well crisis opens reward choices")

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


func _action_exists(actions: Array, action_id: String) -> bool:
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY and str(action.get("id", "")) == action_id:
			return true
	return false


func _preview_ready(previews: Array, action_id: String) -> bool:
	for preview in previews:
		if typeof(preview) == TYPE_DICTIONARY and str(preview.get("id", "")) == action_id:
			return bool(preview.get("ready", false))
	return false


func _inventory_summary_contains(entries: Array, item_id: String, text: String) -> bool:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("id", "")) == item_id and str(entry.get("use_effect_summary", "")).contains(text):
			return true
	return false


func _reward_summary_contains(entries: Array, reward_id: String, text: String) -> bool:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("id", "")) == reward_id and str(entry.get("effect_summary", "")).contains(text):
			return true
	return false


func _node_summary_contains(entries: Array, node_id: String, text: String) -> bool:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("id", "")) == node_id and str(entry.get("effect_summary", "")).contains(text):
			return true
	return false


func _pending_event_from_pool(event: Dictionary, event_ids: Array) -> bool:
	return event_ids.has(str(event.get("id", "")))


func _event_from_pool(map: Node, event_key: String, event_id: String) -> Dictionary:
	var pool: Dictionary = map.stage_event_defs.get(event_key, {})
	for event in pool.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("id", "")) == event_id:
			return event.duplicate(true)
	return {}


func _response_preview_contains(previews: Array, mode: String, text: String) -> bool:
	for preview in previews:
		if typeof(preview) != TYPE_DICTIONARY:
			continue
		if str(preview.get("mode", "")) == mode and str(preview.get("summary", "")).contains(text):
			return true
	return false


func _response_bonus_status_contains(previews: Array, mode: String, text: String) -> bool:
	for preview in previews:
		if typeof(preview) != TYPE_DICTIONARY:
			continue
		if str(preview.get("mode", "")) == mode and str(preview.get("route_bonus_status", "")).contains(text):
			return true
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
