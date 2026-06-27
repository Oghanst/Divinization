extends Node2D
class_name HexCivilizationMap

signal tile_selected(tile: Variant)
signal resources_changed(resources: Dictionary)

const HexMapGeneratorScript := preload("res://game/domain/map/hex/hex_map_generator.gd")
const PlayerMapStateScript := preload("res://game/domain/map/hex/player_map_state.gd")

const PLAYER_OWNER := "隐秘教团"
const TERRAIN_FOREST := "forest"
const TERRAIN_RUIN := "ruin"
const TERRAIN_WATER := "water"
const BUILDING_DEFS_PATH := "res://data/demo/hex_map/building_defs.json"
const STATE_DEFS_PATH := "res://data/demo/hex_map/state_defs.json"
const MAP_ACTION_DEFS_PATH := "res://data/demo/hex_map/map_action_defs.json"
const ITEM_DEFS_PATH := "res://data/demo/hex_map/item_defs.json"

@export var map_radius: int = 4
@export var hex_size: float = 52.0
@export var map_seed: int = 20260625
@export var keyboard_pan_speed: float = 520.0
@export var min_zoom: float = 0.55
@export var max_zoom: float = 2.5
@export var zoom_step: float = 1.12

@onready var render_layer: Node2D = $World/HexMapRenderLayer
@onready var camera: Camera2D = $HexMapCamera
@onready var camera_controller: Node = $MapInputController
@onready var status_panel: Control = $MapUILayer/CivilizationStatusPanel
@onready var card_controller: CardRunController = $CardRunController
@onready var card_hand_layer: MapCardHandLayer = $CardUILayer/MapCardHandLayer

var tiles: Dictionary = {}
var map_state: RefCounted
var building_defs: Dictionary = {}
var state_defs: Dictionary = {}
var map_action_defs: Dictionary = {}
var item_defs: Dictionary = {}
var resource_to_item_id: Dictionary = {}
var event_log: Array[String] = []
var map_ui_scale := 1.0


func _ready() -> void:
	map_ui_scale = _calculate_ui_scale()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_load_config_defs()
	_generate_map()
	_configure_camera()
	_connect_map_ui()
	_connect_card_ui()
	_select_tile(map_state.player_coord)
	_log("你在圣址醒来。末日倒计时已经开始。")
	resources_changed.emit(map_state.global_resources.duplicate())
	_update_ui()


func end_turn() -> void:
	var faith_gain := 0
	for tile in tiles.values():
		if tile.owner == PLAYER_OWNER or tile.has_building("secret_shrine"):
			faith_gain += max(0, int(tile.get_yields().get("faith", 0)))
	if faith_gain > 0:
		map_state.change_global_resource("faith", faith_gain)
		_log("回合结算：信仰 +%s。" % str(faith_gain))
	map_state.turn += 1
	map_state.reset_action_points()
	_advance_stage_event()
	resources_changed.emit(map_state.global_resources.duplicate())
	_update_ui()


func end_card_and_map_turn() -> void:
	if card_controller != null:
		card_controller.end_turn()
	end_turn()


func apply_map_effect(effect: Dictionary) -> void:
	var scope := str(effect.get("scope", ""))
	match scope:
		"global_resource":
			map_state.change_global_resource(str(effect.get("key", "")), int(effect.get("delta", 0)))
		"tile_state":
			var state_tile := _get_effect_tile(effect)
			if state_tile != null:
				_apply_tile_state_effect(state_tile, effect)
		"tile_building":
			var building_tile := _get_effect_tile(effect)
			if building_tile != null:
				_apply_tile_building_effect(building_tile, effect)
		"tile_population":
			var population_tile := _get_effect_tile(effect)
			if population_tile != null:
				population_tile.population = max(0, population_tile.population + int(effect.get("delta", 0)))
		"inventory":
			var item_id := str(effect.get("item", ""))
			var item_delta := int(effect.get("delta", 0))
			if item_delta >= 0:
				map_state.add_item(item_id, item_delta)
			else:
				map_state.remove_item(item_id, abs(item_delta))
		"event":
			if str(effect.get("key", "")) == "countdown":
				map_state.event_countdown = max(0, map_state.event_countdown + int(effect.get("delta", 0)))
	_update_after_map_change()


func hex_to_pixel(coord: Vector2i) -> Vector2:
	return render_layer.hex_to_pixel(coord)


func pixel_to_hex(pixel: Vector2) -> Vector2i:
	return render_layer.pixel_to_hex(pixel)


func get_selected_tile() -> RefCounted:
	return tiles.get(map_state.selected_coord)


func _load_config_defs() -> void:
	building_defs = _defs_by_id(_read_json_array(BUILDING_DEFS_PATH))
	state_defs = _defs_by_id(_read_json_array(STATE_DEFS_PATH))
	map_action_defs = _defs_by_id(_read_json_array(MAP_ACTION_DEFS_PATH))
	item_defs = _defs_by_id(_read_json_array(ITEM_DEFS_PATH))
	resource_to_item_id.clear()
	for item_id in item_defs.keys():
		var item_def: Dictionary = item_defs[item_id]
		var resource_id := str(item_def.get("source_resource", ""))
		if not resource_id.is_empty():
			resource_to_item_id[resource_id] = item_id


func _generate_map() -> void:
	map_state = PlayerMapStateScript.new()
	var generator: RefCounted = HexMapGeneratorScript.new()
	var generated: Dictionary = generator.generate(map_radius, map_seed)
	tiles = generated.get("tiles", {})
	_seed_map_content()
	var origin: RefCounted = tiles[Vector2i.ZERO]
	origin.claim(PLAYER_OWNER)
	origin.population = 3
	origin.explored = true
	origin.add_state("anchor")
	render_layer.setup_map(tiles, generated, hex_size)
	render_layer.set_player_coord(map_state.player_coord)


func _seed_map_content() -> void:
	for tile in tiles.values():
		tile.explored = false
		if tile.terrain == TERRAIN_RUIN:
			tile.set_dungeon_entrance("forgotten_cellar", "废弃地下室")
			tile.hidden_states.append("enemy_attention")
		elif tile.terrain == TERRAIN_FOREST and _coord_seed(tile.coord) % 3 == 0:
			tile.hidden_states.append("anchor")
		elif _coord_seed(tile.coord) % 7 == 0 and tile.terrain != TERRAIN_WATER:
			tile.hidden_states.append("polluted")


func _configure_camera() -> void:
	camera.enabled = true
	camera.position = Vector2.ZERO
	camera_controller.keyboard_pan_speed = keyboard_pan_speed
	camera_controller.min_zoom = min_zoom
	camera_controller.max_zoom = max_zoom
	camera_controller.zoom_step = zoom_step
	camera_controller.bind_camera(camera)
	if not camera_controller.primary_map_pressed.is_connected(_on_primary_map_pressed):
		camera_controller.primary_map_pressed.connect(_on_primary_map_pressed)


func _connect_map_ui() -> void:
	status_panel.set_ui_scale(map_ui_scale)
	if not status_panel.action_requested.is_connected(_on_map_action_requested):
		status_panel.action_requested.connect(_on_map_action_requested)


func _connect_card_ui() -> void:
	card_hand_layer.bind_controller(card_controller)
	if not card_hand_layer.end_turn_requested.is_connected(end_card_and_map_turn):
		card_hand_layer.end_turn_requested.connect(end_card_and_map_turn)
	if not card_hand_layer.map_action_requested.is_connected(_on_map_action_requested):
		card_hand_layer.map_action_requested.connect(_on_map_action_requested)
	card_controller.start_demo()


func _on_primary_map_pressed(world_position: Vector2) -> void:
	var coord: Vector2i = render_layer.world_to_hex(world_position)
	if _should_click_move(coord):
		_move_to_coord(coord)
		return
	_select_tile(coord)


func _select_tile(coord: Vector2i) -> void:
	if not tiles.has(coord):
		return
	map_state.selected_coord = coord
	render_layer.set_selected_coord(coord)
	tile_selected.emit(tiles[coord])
	_update_ui()


func _should_click_move(coord: Vector2i) -> bool:
	if not tiles.has(coord):
		return false
	if coord == map_state.player_coord:
		return false
	return _are_neighbors(map_state.player_coord, coord)


func _move_to_coord(coord: Vector2i) -> void:
	if not tiles.has(coord):
		return
	map_state.selected_coord = coord
	render_layer.set_selected_coord(coord)
	var result := _evaluate_action("move")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法移动。")))
		_update_ui()
		return
	var target: RefCounted = tiles[coord]
	map_state.spend_action_points(int(result.get("cost", 1)))
	map_state.player_coord = coord
	target.revealed = true
	render_layer.set_player_coord(map_state.player_coord)
	_log("移动到 %s。" % str(map_state.player_coord))
	_update_after_map_change()


func _on_map_action_requested(action_id: String) -> void:
	match action_id:
		"move":
			_try_move_to_selected_tile()
		"investigate":
			_try_investigate_current_tile()
		"gather":
			_try_gather_current_tile()
		"rest":
			_try_rest()
		"hide":
			_try_hide()
		"build_secret_shrine":
			_try_build_secret_shrine()
		"enter_encounter":
			_try_enter_encounter()
		"end_turn":
			end_turn()


func _try_move_to_selected_tile() -> void:
	var result := _evaluate_action("move")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法移动。")))
		_update_ui()
		return
	_move_to_coord(map_state.selected_coord)


func _try_investigate_current_tile() -> void:
	var result := _evaluate_action("investigate")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法调查。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	map_state.spend_action_points(int(result.get("cost", 1)))
	var revealed: Dictionary = tile.reveal_details()
	if not tile.has_state("investigated"):
		tile.add_state("investigated")
	var pieces: Array[String] = []
	if not revealed.get("states", []).is_empty():
		pieces.append("发现状态：" + _names_from_ids(revealed.get("states", []), state_defs))
	if str(revealed.get("entrance", "")) != "":
		pieces.append("发现入口：" + str(revealed.get("entrance", "")))
	if not pieces.is_empty():
		map_state.add_item("suspicious_clue")
		pieces.append("获得：" + _get_item_name("suspicious_clue"))
	_log("调查完成。" if pieces.is_empty() else "调查完成，" + "；".join(pieces) + "。")
	_update_after_map_change()


func _try_gather_current_tile() -> void:
	var result := _evaluate_action("gather")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法采集。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	map_state.spend_action_points(int(result.get("cost", 1)))
	map_state.change_global_resource("materials", 1)
	var gained_items: Array[String] = []
	for resource_id in tile.resource_ids:
		var item_id := str(resource_to_item_id.get(str(resource_id), ""))
		if item_id.is_empty():
			continue
		map_state.add_item(item_id)
		gained_items.append(_get_item_name(item_id))
	tile.add_state("depleted")
	_log("采集完成：材料 +1。" if gained_items.is_empty() else "采集完成：材料 +1，获得 %s。" % "、".join(gained_items))
	_update_after_map_change()


func _try_rest() -> void:
	var result := _evaluate_action("rest")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法休息。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	map_state.spend_action_points(int(result.get("cost", 1)))
	var heal_amount := 2
	if tile.has_state("polluted") or tile.has_state("plague") or tile.has_state("enemy_attention"):
		heal_amount = 1
	if tile.terrain == "holy_site" or tile.has_building("secret_shrine"):
		heal_amount += 1
	var healed: int = map_state.heal(heal_amount)
	_log("休息完成：生命 +%s。" % str(healed))
	_update_after_map_change()


func _try_hide() -> void:
	var result := _evaluate_action("hide")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法隐藏。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	map_state.spend_action_points(int(result.get("cost", 1)))
	var pressure_delta := -1
	if tile.terrain == TERRAIN_FOREST or tile.terrain == TERRAIN_RUIN:
		pressure_delta = -2
	if tile.population >= 3:
		pressure_delta = max(pressure_delta, -1)
	map_state.change_secrecy_pressure(pressure_delta)
	tile.add_state("concealed_tracks")
	_log("隐藏行动完成：追踪压力 %s。" % str(pressure_delta))
	_update_after_map_change()


func _try_build_secret_shrine() -> void:
	var result := _evaluate_action("build_secret_shrine")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法建设。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	var building_def: Dictionary = building_defs.get("secret_shrine", {})
	map_state.spend_action_points(int(result.get("cost", 1)))
	map_state.change_global_resource("materials", -int(building_def.get("material_cost", 0)))
	tile.claim(PLAYER_OWNER)
	tile.add_building("secret_shrine", building_def.get("yield_bonus", {}))
	_log("秘密祭坛建成：此地信仰产出提高。")
	_update_after_map_change()


func _try_enter_encounter() -> void:
	var result := _evaluate_action("enter_encounter")
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法进入。")))
		_update_ui()
		return
	var tile: RefCounted = tiles[map_state.player_coord]
	tile.add_state("encounter_active")
	_log("进入占位遭遇：%s。完整副本战斗会在后续接入。" % tile.dungeon_entrance_name)
	_update_after_map_change()


func _evaluate_action(action_id: String) -> Dictionary:
	var def: Dictionary = map_action_defs.get(action_id, {})
	var cost := int(def.get("action_point_cost", 1))
	var label := str(def.get("name", action_id))
	var selected_tile: RefCounted = get_selected_tile()
	var current_tile: RefCounted = tiles.get(map_state.player_coord)
	var reason := ""
	var enabled := true
	if cost > 0 and not map_state.can_spend_action_points(cost):
		enabled = false
		reason = "行动点不足"
	match action_id:
		"move":
			if selected_tile == null:
				enabled = false
				reason = "未选择地块"
			elif map_state.selected_coord == map_state.player_coord:
				enabled = false
				reason = "已经在该地块"
			elif not _are_neighbors(map_state.player_coord, map_state.selected_coord):
				enabled = false
				reason = "非相邻地块"
			elif not selected_tile.is_passable():
				enabled = false
				reason = "水域不可进入"
		"investigate":
			if current_tile == null:
				enabled = false
				reason = "当前位置无效"
			elif current_tile.explored and current_tile.hidden_states.is_empty() and not (current_tile.dungeon_entrance_id != "" and not current_tile.entrance_revealed):
				enabled = false
				reason = "已经调查过"
		"gather":
			if current_tile == null:
				enabled = false
				reason = "当前位置无效"
			elif not current_tile.explored:
				enabled = false
				reason = "地块未调查"
			elif current_tile.resource_ids.is_empty():
				enabled = false
				reason = "没有可采集资源"
			elif current_tile.has_state("depleted"):
				enabled = false
				reason = "已经采集过"
		"rest":
			if map_state.life >= map_state.max_life:
				enabled = false
				reason = "生命已满"
		"hide":
			if map_state.secrecy_pressure <= 0:
				enabled = false
				reason = "暂未被追踪"
		"build_secret_shrine":
			var building_def: Dictionary = building_defs.get("secret_shrine", {})
			var material_cost := int(building_def.get("material_cost", 0))
			if current_tile == null:
				enabled = false
				reason = "当前位置无效"
			elif not current_tile.explored:
				enabled = false
				reason = "地块未调查"
			elif building_def.get("terrain_blocklist", []).has(current_tile.terrain):
				enabled = false
				reason = "该地形不可建设"
			elif current_tile.has_core_building():
				enabled = false
				reason = "已有建筑"
			elif int(map_state.global_resources.get("materials", 0)) < material_cost:
				enabled = false
				reason = "缺少材料"
		"enter_encounter":
			if current_tile == null:
				enabled = false
				reason = "当前位置无效"
			elif not current_tile.has_visible_entrance():
				enabled = false
				reason = "没有已发现入口"
		"end_turn":
			enabled = true
			reason = ""
	return {
		"id": action_id,
		"label": label,
		"enabled": enabled,
		"reason": reason,
		"cost": cost,
	}


func _build_actions() -> Array:
	return [
		_evaluate_action("move"),
		_evaluate_action("investigate"),
		_evaluate_action("gather"),
		_evaluate_action("rest"),
		_evaluate_action("hide"),
		_evaluate_action("build_secret_shrine"),
		_evaluate_action("enter_encounter"),
		_evaluate_action("end_turn"),
	]


func _update_after_map_change() -> void:
	render_layer.queue_redraw()
	resources_changed.emit(map_state.global_resources.duplicate())
	_update_ui()


func _update_ui() -> void:
	var snapshot := _build_ui_snapshot()
	status_panel.update_view(snapshot)
	card_hand_layer.update_map_snapshot(snapshot)


func _build_ui_snapshot() -> Dictionary:
	return {
		"turn": map_state.turn,
		"action_points": map_state.action_points,
		"max_action_points": map_state.max_action_points,
		"life": map_state.life,
		"max_life": map_state.max_life,
		"level": map_state.level,
		"experience": map_state.experience,
		"sanity_status": map_state.sanity_status,
			"secrecy_status": "%s（压力 %s）" % [map_state.secrecy_status, str(map_state.secrecy_pressure)],
			"player_coord": map_state.player_coord,
			"global_resources": map_state.global_resources.duplicate(),
			"inventory": _build_inventory_snapshot(),
			"event_countdown": map_state.event_countdown,
		"event_summary": map_state.event_summary,
		"current_tile": _build_tile_snapshot(tiles.get(map_state.player_coord)),
		"selected_tile": _build_tile_snapshot(get_selected_tile()),
		"actions": _build_actions(),
		"log": event_log.duplicate(),
	}


func _build_inventory_snapshot() -> Array:
	var entries: Array = []
	for item_id in map_state.inventory.keys():
		var key := str(item_id)
		entries.append({
			"id": key,
			"name": _get_item_name(key),
			"quantity": int(map_state.inventory[item_id]),
			"description": str(item_defs.get(key, {}).get("description", "")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	return entries


func _build_tile_snapshot(tile: RefCounted) -> Dictionary:
	if tile == null:
		return {}
	var resource_text := "无"
	if tile.explored and not tile.resource_names.is_empty():
		resource_text = "、".join(tile.resource_names)
	var building_text := "无"
	if tile.explored and not tile.buildings.is_empty():
		building_text = _names_from_ids(tile.buildings, building_defs)
	var state_text := "无"
	if tile.explored and not tile.states.is_empty():
		state_text = _names_from_ids(tile.states, state_defs)
	var entrance_text := "无"
	if tile.has_visible_entrance():
		entrance_text = tile.dungeon_entrance_name
	return {
		"coord": tile.coord,
		"terrain": tile.terrain,
		"terrain_name": render_layer.get_terrain_name(tile.terrain),
		"resource_text": resource_text,
		"population": tile.population,
		"yields": tile.get_yields(),
		"building_text": building_text,
		"state_text": state_text,
		"explored": tile.explored,
		"is_player_location": tile.coord == map_state.player_coord,
		"entrance_text": entrance_text,
	}


func _advance_stage_event() -> void:
	if map_state.event_countdown <= 0:
		return
	map_state.event_countdown -= 1
	map_state.event_summary = "瘟疫将在 %s 回合后全面爆发" % str(map_state.event_countdown)
	if map_state.event_countdown == 0:
		var current_tile: RefCounted = tiles.get(map_state.player_coord)
		if current_tile != null:
			current_tile.add_state("plague")
		map_state.sanity_status = "动摇"
		_log("阶段事件：瘟疫爆发，所在地块染上疫病。")


func _get_effect_tile(effect: Dictionary) -> RefCounted:
	var coord: Variant = effect.get("coord", map_state.selected_coord)
	if typeof(coord) == TYPE_VECTOR2I and tiles.has(coord):
		return tiles[coord]
	return null


func _apply_tile_state_effect(tile: RefCounted, effect: Dictionary) -> void:
	var state_id := str(effect.get("state", ""))
	match str(effect.get("op", "add")):
		"remove":
			tile.remove_state(state_id)
		_:
			tile.add_state(state_id)


func _apply_tile_building_effect(tile: RefCounted, effect: Dictionary) -> void:
	var building_id := str(effect.get("building", ""))
	if str(effect.get("op", "add")) != "add":
		return
	var building_def: Dictionary = building_defs.get(building_id, {})
	tile.add_building(building_id, building_def.get("yield_bonus", {}))


func _are_neighbors(a: Vector2i, b: Vector2i) -> bool:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -a.x - a.y - (-b.x - b.y)
	return max(abs(dq), abs(dr), abs(ds)) == 1


func _defs_by_id(defs: Array) -> Dictionary:
	var result := {}
	for item in defs:
		if typeof(item) == TYPE_DICTIONARY:
			result[str(item.get("id", ""))] = item
	return result


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


func _names_from_ids(ids: Array, defs: Dictionary) -> String:
	var names: Array[String] = []
	for id in ids:
		var key := str(id)
		names.append(str(defs.get(key, {}).get("name", key)))
	return "、".join(names)


func _get_item_name(item_id: String) -> String:
	return str(item_defs.get(item_id, {}).get("name", item_id))


func _coord_seed(coord: Vector2i) -> int:
	return abs(coord.x * 928371 + coord.y * 364479 + map_seed)


func _log(message: String) -> void:
	if message.is_empty():
		return
	event_log.append(message)
	if event_log.size() > 40:
		event_log.remove_at(0)


func _on_viewport_size_changed() -> void:
	var next_scale := _calculate_ui_scale()
	if abs(next_scale - map_ui_scale) < 0.05:
		return
	map_ui_scale = next_scale
	status_panel.set_ui_scale(map_ui_scale)
	_update_ui()


func _calculate_ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	var scale_from_width := viewport_size.x / 1920.0
	var scale_from_height := viewport_size.y / 1080.0
	return clamp(min(scale_from_width, scale_from_height), 1.0, 1.75)
