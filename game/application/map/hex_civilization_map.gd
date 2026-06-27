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
const STAGE_REWARD_DEFS_PATH := "res://data/demo/hex_map/stage_reward_defs.json"
const STAGE_NODE_DEFS_PATH := "res://data/demo/hex_map/stage_node_defs.json"
const STAGE_CRISIS_DEFS_PATH := "res://data/demo/hex_map/stage_crisis_defs.json"
const STAGE_EVENT_DEFS_PATH := "res://data/demo/hex_map/stage_event_defs.json"
const CARD_GLOBAL_RESOURCE_KEYS := ["faith", "materials", "followers"]
const CARD_ROUTE_PROGRESS_TO_AFFINITY := {
	"life_route": "life",
	"death_route": "death",
	"secret_route": "secret",
	"anchor_progress": "faith",
}
const ITEM_ACTION_PREFIX := "use_item:"
const REWARD_ACTION_PREFIX := "claim_reward:"
const NODE_ACTION_PREFIX := "choose_node:"

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
var stage_reward_defs: Dictionary = {}
var stage_node_defs: Dictionary = {}
var stage_crisis_defs: Dictionary = {}
var stage_event_defs: Dictionary = {}
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
	if map_state.crisis_active and not map_state.stage_resolved:
		_log("最终事件已经爆发，必须先选择处理方式。")
		_update_ui()
		return
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
	stage_reward_defs = _defs_by_id(_read_json_array(STAGE_REWARD_DEFS_PATH))
	stage_node_defs = _defs_by_id(_read_json_array(STAGE_NODE_DEFS_PATH))
	stage_crisis_defs = _defs_by_id(_read_json_array(STAGE_CRISIS_DEFS_PATH))
	stage_event_defs = _defs_by_id(_read_json_array(STAGE_EVENT_DEFS_PATH))
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
	if not card_controller.effects_applied.is_connected(_on_card_effects_applied):
		card_controller.effects_applied.connect(_on_card_effects_applied)
	card_controller.start_demo("sick_village", _get_stage_turn_events(map_state.event_key), map_state.event_key)
	_sync_card_global_resources_from_map()


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
	if action_id.begins_with(REWARD_ACTION_PREFIX):
		_try_claim_stage_reward(action_id.substr(REWARD_ACTION_PREFIX.length()))
		return
	if action_id.begins_with(NODE_ACTION_PREFIX):
		_try_choose_stage_node(action_id.substr(NODE_ACTION_PREFIX.length()))
		return
	if map_state.stage_node_pending:
		_log("请先选择下一个关卡节点。")
		_update_ui()
		return
	if map_state.stage_reward_pending:
		_log("请先选择阶段奖励。")
		_update_ui()
		return
	if map_state.crisis_active and not map_state.stage_resolved and not _is_crisis_action(action_id):
		_log("最终事件期间无法执行普通行动。")
		_update_ui()
		return
	if action_id.begins_with(ITEM_ACTION_PREFIX):
		_try_use_item(action_id.substr(ITEM_ACTION_PREFIX.length()))
		return
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
		"handle_pending_event":
			_try_respond_pending_event("handled", action_id)
		"convert_pending_event":
			_try_respond_pending_event("converted", action_id)
		"exploit_pending_event":
			_try_respond_pending_event("exploited", action_id)
		"ignore_pending_event":
			_try_respond_pending_event("ignored", action_id)
		"build_secret_shrine":
			_try_build_secret_shrine()
		"enter_encounter":
			_try_enter_encounter()
		"end_turn":
			end_turn()
		_:
			if _is_crisis_action(action_id):
				_try_resolve_stage_crisis(action_id)
			else:
				_log("未知行动：%s。" % action_id)
				_update_ui()


func _on_card_effects_applied(effects: Array, source: Dictionary) -> void:
	if str(source.get("type", "")) == "final_event":
		return
	var changed := false
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var kind := str(effect.get("kind", ""))
		var key := str(effect.get("key", ""))
		var value := int(effect.get("value", 0))
		match kind:
			"resource":
				if CARD_GLOBAL_RESOURCE_KEYS.has(key):
					map_state.change_global_resource(key, value)
					changed = true
				elif key == "exposure" and value != 0:
					map_state.change_secrecy_pressure(value)
					changed = true
			"progress":
				if key == "source_clues" and value > 0:
					map_state.add_item("suspicious_clue", value)
					changed = true
				elif key == "suspicion" and value != 0:
					map_state.change_secrecy_pressure(value)
					changed = true
				elif CARD_ROUTE_PROGRESS_TO_AFFINITY.has(key) and value > 0:
					map_state.change_route_affinity(str(CARD_ROUTE_PROGRESS_TO_AFFINITY[key]), value)
					changed = true
			"map_tile_state":
				var current_tile: RefCounted = tiles.get(map_state.player_coord)
				if current_tile != null:
					current_tile.explored = true
					var state_id := str(effect.get("state", ""))
					if str(effect.get("op", "add")) == "remove":
						current_tile.remove_state(state_id)
					else:
						current_tile.add_state(state_id)
					changed = true
			"log":
				_log(_format_card_effect_log_prefix(source) + str(effect.get("text", "")))
				changed = true
	_sync_sanity_status_from_cards()
	if changed:
		_update_after_map_change()


func _sync_sanity_status_from_cards() -> void:
	if card_controller == null:
		return
	var sanity := int(card_controller.resources.get("sanity", 5))
	if sanity >= 5:
		map_state.sanity_status = "稳定"
	elif sanity >= 3:
		map_state.sanity_status = "临界"
	elif sanity >= 2:
		map_state.sanity_status = "洞见"
	elif sanity >= 1:
		map_state.sanity_status = "深视"
	else:
		map_state.sanity_status = "失真"


func _format_card_effect_log_prefix(source: Dictionary) -> String:
	match str(source.get("type", "")):
		"turn_event", "turn_event_handled", "turn_event_converted", "turn_event_exploited":
			return "事件："
		"turn_event_route_bonus":
			return "路线加成："
		"final_event":
			return "结局："
		_:
			return "神力："


func _sync_card_global_resources_from_map() -> void:
	if card_controller == null:
		return
	var values := {}
	for key in CARD_GLOBAL_RESOURCE_KEYS:
		values[key] = int(map_state.global_resources.get(key, 0))
	card_controller.sync_resources(values)


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


func _try_respond_pending_event(mode: String, action_id: String) -> void:
	var result := _evaluate_action(action_id)
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法回应预兆。")))
		_update_ui()
		return
	map_state.spend_action_points(int(result.get("cost", 1)))
	var pending_event: Dictionary = card_controller.pending_event.duplicate(true) if card_controller != null else {}
	var route_bonus_effects: Array = _pending_event_route_bonus_effects(pending_event, mode)
	if card_controller != null and card_controller.resolve_pending_event(mode):
		if not route_bonus_effects.is_empty():
			card_controller.apply_external_effects(route_bonus_effects, {
				"type": "turn_event_route_bonus",
				"id": str(pending_event.get("id", "")),
				"name": str(pending_event.get("name", "")),
				"mode": mode,
			})
		_log(_pending_event_response_log(mode))
	else:
		_log("没有可处理的事件预兆。")
	_update_after_map_change()


func _pending_event_response_log(mode: String) -> String:
	match mode:
		"handled":
			return "你主动处理了本回合的事件预兆。"
		"converted":
			return "你把本回合的事件预兆转化成自己的道路。"
		"exploited":
			return "你利用了本回合的事件预兆。"
		_:
			return "你放任了本回合的事件预兆。"


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


func _try_use_item(item_id: String) -> void:
	var result := _evaluate_item_use(item_id)
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法使用物品。")))
		_update_ui()
		return
	if not map_state.remove_item(item_id, 1):
		_log("背包中没有可用的%s。" % _get_item_name(item_id))
		_update_ui()
		return
	map_state.spend_action_points(int(result.get("cost", 0)))
	var item_def: Dictionary = item_defs.get(item_id, {})
	var effects: Array = item_def.get("use_effects", [])
	_apply_item_use_effects(effects)
	var summary := str(result.get("summary", ""))
	_log("使用物品：%s%s。" % [
		_get_item_name(item_id),
		"（%s）" % summary if not summary.is_empty() else "",
	])
	_update_after_map_change()


func _open_stage_rewards(result_id: String) -> void:
	map_state.stage_reward_options.clear()
	for reward_id in stage_reward_defs.keys():
		var reward_def: Dictionary = stage_reward_defs[reward_id]
		var result_ids: Array = reward_def.get("result_ids", [])
		if result_ids.is_empty() or result_ids.has(result_id):
			map_state.stage_reward_options.append(reward_def.duplicate(true))
	if map_state.stage_reward_options.is_empty():
		map_state.stage_reward_pending = false
		map_state.stage_reward_claimed = true
		return
	map_state.stage_reward_pending = true
	map_state.stage_reward_claimed = false
	_log("阶段奖励：选择一种奖励，决定病村事件留下什么成长。")


func _try_claim_stage_reward(reward_id: String) -> void:
	var result := _evaluate_reward_action(reward_id)
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法领取奖励。")))
		_update_ui()
		return
	var reward_def := _find_stage_reward_option(reward_id)
	_apply_stage_reward_effects(reward_def.get("effects", []))
	map_state.stage_reward_pending = false
	map_state.stage_reward_claimed = true
	map_state.stage_reward_options.clear()
	_log("领取奖励：%s。" % str(reward_def.get("name", reward_id)))
	_open_next_stage_nodes()
	_update_after_map_change()


func _evaluate_reward_action(reward_id: String) -> Dictionary:
	var reward_def := _find_stage_reward_option(reward_id)
	var enabled := true
	var reason := ""
	if reward_def.is_empty():
		enabled = false
		reason = "奖励不存在"
	elif not map_state.stage_reward_pending:
		enabled = false
		reason = "当前没有待领取奖励"
	return {
		"id": REWARD_ACTION_PREFIX + reward_id,
		"label": str(reward_def.get("name", reward_id)),
		"enabled": enabled,
		"reason": reason,
		"cost": 0,
		"description": str(reward_def.get("description", "")),
		"summary": _summarize_item_effects(reward_def.get("effects", [])),
	}


func _find_stage_reward_option(reward_id: String) -> Dictionary:
	for reward in map_state.stage_reward_options:
		if typeof(reward) == TYPE_DICTIONARY and str(reward.get("id", "")) == reward_id:
			return reward
	return {}


func _apply_stage_effects(effects: Array) -> void:
	_apply_stage_reward_effects(effects)


func _apply_stage_reward_effects(effects: Array) -> void:
	var card_resource_deltas := {}
	var card_progress_deltas := {}
	var current_tile: RefCounted = tiles.get(map_state.player_coord)
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var scope := str(effect.get("scope", ""))
		var delta := int(effect.get("delta", 0))
		match scope:
			"player_life":
				if delta >= 0:
					map_state.heal(delta)
				else:
					map_state.take_damage(abs(delta))
			"experience":
				map_state.gain_experience(delta)
			"global_resource":
				map_state.change_global_resource(str(effect.get("key", "")), delta)
			"card_resource":
				var resource_key := str(effect.get("key", ""))
				card_resource_deltas[resource_key] = int(card_resource_deltas.get(resource_key, 0)) + delta
			"card_progress":
				var progress_key := str(effect.get("key", ""))
				card_progress_deltas[progress_key] = int(card_progress_deltas.get(progress_key, 0)) + delta
			"route_affinity":
				map_state.change_route_affinity(str(effect.get("route", "")), delta)
			"route_bonus_threshold":
				map_state.change_route_bonus_threshold(str(effect.get("route", "")), delta)
			"secrecy_pressure":
				map_state.change_secrecy_pressure(delta)
			"inventory":
				var item_id := str(effect.get("item", ""))
				if delta >= 0:
					map_state.add_item(item_id, delta)
				else:
					map_state.remove_item(item_id, abs(delta))
			"tile_state":
				if current_tile != null:
					_apply_tile_state_effect(current_tile, effect)
			"tile_population":
				if current_tile != null:
					current_tile.population = max(0, current_tile.population + delta)
			"tile_claim":
				if current_tile != null:
					current_tile.claim(PLAYER_OWNER)
			"tile_building":
				if current_tile != null:
					var only_if_empty := bool(effect.get("if_empty", false))
					if not only_if_empty or not current_tile.has_core_building():
						_apply_tile_building_effect(current_tile, {
							"op": "add",
							"building": str(effect.get("building", "")),
						})
			"card_discard":
				if card_controller != null:
					card_controller.grant_card_to_discard(str(effect.get("card_id", "")))
			"sanity_status":
				map_state.sanity_status = str(effect.get("value", map_state.sanity_status))
			"event_summary":
				map_state.event_summary = str(effect.get("text", map_state.event_summary))
			"log":
				_log(str(effect.get("text", "")))
	if card_controller != null:
		card_controller.apply_external_deltas(card_resource_deltas, card_progress_deltas)
	_sync_sanity_status_from_cards()


func _open_next_stage_nodes() -> void:
	map_state.stage_node_options.clear()
	for node_id in stage_node_defs.keys():
		var node_def: Dictionary = stage_node_defs[node_id]
		map_state.stage_node_options.append(node_def.duplicate(true))
	if map_state.stage_node_options.is_empty():
		map_state.stage_node_pending = false
		return
	map_state.stage_node_pending = true
	_log("新的节点显现：选择下一处要介入的地点。")


func _try_choose_stage_node(node_id: String) -> void:
	var result := _evaluate_node_action(node_id)
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "无法选择节点。")))
		_update_ui()
		return
	var node_def := _find_stage_node_option(node_id)
	_start_stage_node(node_def)
	_update_after_map_change()


func _evaluate_node_action(node_id: String) -> Dictionary:
	var node_def := _find_stage_node_option(node_id)
	var enabled := true
	var reason := ""
	if node_def.is_empty():
		enabled = false
		reason = "节点不存在"
	elif not map_state.stage_node_pending:
		enabled = false
		reason = "当前没有待选择节点"
	return {
		"id": NODE_ACTION_PREFIX + node_id,
		"label": str(node_def.get("name", node_id)),
		"enabled": enabled,
		"reason": reason,
		"cost": 0,
		"description": str(node_def.get("description", "")),
		"summary": _summarize_item_effects(node_def.get("effects", [])),
	}


func _find_stage_node_option(node_id: String) -> Dictionary:
	for node in map_state.stage_node_options:
		if typeof(node) == TYPE_DICTIONARY and str(node.get("id", "")) == node_id:
			return node
	return {}


func _start_stage_node(node_def: Dictionary) -> void:
	var node_id := str(node_def.get("id", ""))
	map_state.stage_node_pending = false
	map_state.stage_node_options.clear()
	map_state.stage_node_id = node_id
	map_state.stage_node_name = str(node_def.get("name", node_id))
	map_state.crisis_active = false
	map_state.stage_resolved = false
	map_state.stage_result_id = ""
	map_state.stage_reward_pending = false
	map_state.stage_reward_claimed = false
	map_state.stage_reward_options.clear()
	map_state.event_key = str(node_def.get("event_key", "plague_outbreak"))
	map_state.event_countdown = int(node_def.get("turn_limit", 6))
	map_state.event_countdown_template = str(node_def.get("summary_template", "阶段危机将在 {countdown} 回合后爆发"))
	map_state.event_crisis_summary = str(node_def.get("crisis_summary", "最终事件爆发，选择处理方式"))
	map_state.event_crisis_log = str(node_def.get("crisis_log", "阶段事件爆发。前期准备将决定你能选择哪种结局。"))
	map_state.event_summary = _format_stage_countdown_summary()
	map_state.reset_action_points()
	if card_controller != null:
		card_controller.start_demo(
			str(node_def.get("encounter_id", "sick_village")),
			_get_stage_turn_events(map_state.event_key),
			map_state.event_key
		)
		card_controller.countdown = map_state.event_countdown
		card_controller._emit_state()
	_apply_stage_transition_effects(node_def.get("effects", []))
	_sync_card_global_resources_from_map()
	_select_tile(map_state.player_coord)
	_log("进入节点：%s。" % map_state.stage_node_name)


func _apply_stage_transition_effects(effects: Array) -> void:
	_apply_stage_reward_effects(effects)


func _evaluate_item_use(item_id: String) -> Dictionary:
	var item_def: Dictionary = item_defs.get(item_id, {})
	var effects: Array = item_def.get("use_effects", [])
	var label := str(item_def.get("use_label", "使用"))
	var cost := int(item_def.get("use_action_point_cost", 1))
	var quantity := int(map_state.inventory.get(item_id, 0))
	var enabled := true
	var reason := ""
	if item_def.is_empty() or effects.is_empty():
		enabled = false
		reason = "暂不可使用"
	elif map_state.stage_node_pending:
		enabled = false
		reason = "先选节点"
	elif map_state.stage_reward_pending:
		enabled = false
		reason = "先选奖励"
	elif map_state.crisis_active and not map_state.stage_resolved:
		enabled = false
		reason = "最终事件期间不可使用"
	elif quantity <= 0:
		enabled = false
		reason = "背包中没有该物品"
	elif cost > 0 and not map_state.can_spend_action_points(cost):
		enabled = false
		reason = "行动点不足"
	return {
		"id": ITEM_ACTION_PREFIX + item_id,
		"label": label,
		"enabled": enabled,
		"reason": reason,
		"cost": cost,
		"summary": _summarize_item_effects(effects),
	}


func _apply_item_use_effects(effects: Array) -> void:
	var card_resource_deltas := {}
	var card_progress_deltas := {}
	var current_tile: RefCounted = tiles.get(map_state.player_coord)
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var scope := str(effect.get("scope", ""))
		var delta := int(effect.get("delta", 0))
		match scope:
			"player_life":
				if delta >= 0:
					map_state.heal(delta)
				else:
					map_state.take_damage(abs(delta))
			"global_resource":
				map_state.change_global_resource(str(effect.get("key", "")), delta)
			"card_resource":
				var resource_key := str(effect.get("key", ""))
				card_resource_deltas[resource_key] = int(card_resource_deltas.get(resource_key, 0)) + delta
			"card_progress":
				var progress_key := str(effect.get("key", ""))
				card_progress_deltas[progress_key] = int(card_progress_deltas.get(progress_key, 0)) + delta
			"route_affinity":
				map_state.change_route_affinity(str(effect.get("route", "")), delta)
			"route_bonus_threshold":
				map_state.change_route_bonus_threshold(str(effect.get("route", "")), delta)
			"secrecy_pressure":
				map_state.change_secrecy_pressure(delta)
			"tile_state":
				if current_tile != null:
					_apply_tile_state_effect(current_tile, effect)
			"inventory":
				var item_id := str(effect.get("item", ""))
				if delta >= 0:
					map_state.add_item(item_id, delta)
				else:
					map_state.remove_item(item_id, abs(delta))
			"log":
				_log(str(effect.get("text", "")))
	if card_controller != null:
		card_controller.apply_external_deltas(card_resource_deltas, card_progress_deltas)
	_sync_sanity_status_from_cards()


func _evaluate_action(action_id: String) -> Dictionary:
	if _is_crisis_action(action_id):
		return _evaluate_crisis_action(action_id)
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
		"handle_pending_event":
			if card_controller == null or not card_controller.has_pending_event():
				enabled = false
				reason = "没有预兆事件"
			elif not card_controller.pending_event_has_response("handled"):
				enabled = false
				reason = "没有处理分支"
		"convert_pending_event":
			if card_controller == null or not card_controller.has_pending_event():
				enabled = false
				reason = "没有预兆事件"
			elif not card_controller.pending_event_has_response("converted"):
				enabled = false
				reason = "没有转化分支"
		"exploit_pending_event":
			if card_controller == null or not card_controller.has_pending_event():
				enabled = false
				reason = "没有预兆事件"
			elif not card_controller.pending_event_has_response("exploited"):
				enabled = false
				reason = "没有利用分支"
		"ignore_pending_event":
			if card_controller == null or not card_controller.has_pending_event():
				enabled = false
				reason = "没有预兆事件"
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
	if map_state.stage_node_pending:
		var node_actions: Array = []
		for node in map_state.stage_node_options:
			if typeof(node) == TYPE_DICTIONARY:
				node_actions.append(_evaluate_node_action(str(node.get("id", ""))))
		return node_actions
	if map_state.stage_reward_pending:
		var reward_actions: Array = []
		for reward in map_state.stage_reward_options:
			if typeof(reward) == TYPE_DICTIONARY:
				reward_actions.append(_evaluate_reward_action(str(reward.get("id", ""))))
		return reward_actions
	if map_state.crisis_active and not map_state.stage_resolved:
		var crisis_actions: Array = []
		for action in _get_current_crisis_actions():
			if typeof(action) == TYPE_DICTIONARY:
				crisis_actions.append(_evaluate_crisis_action(str(action.get("id", ""))))
		return crisis_actions
	return [
		_evaluate_action("move"),
		_evaluate_action("investigate"),
		_evaluate_action("gather"),
		_evaluate_action("rest"),
		_evaluate_action("hide"),
		_evaluate_action("handle_pending_event"),
		_evaluate_action("convert_pending_event"),
		_evaluate_action("exploit_pending_event"),
		_evaluate_action("ignore_pending_event"),
		_evaluate_action("build_secret_shrine"),
		_evaluate_action("enter_encounter"),
		_evaluate_action("end_turn"),
	]


func _update_after_map_change() -> void:
	_sync_card_global_resources_from_map()
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
		"stage_node_id": map_state.stage_node_id,
		"stage_node_name": map_state.stage_node_name,
		"stage_node_pending": map_state.stage_node_pending,
		"stage_node_options": _build_stage_node_snapshot(),
		"crisis_active": map_state.crisis_active,
		"stage_resolved": map_state.stage_resolved,
		"stage_result_id": map_state.stage_result_id,
		"stage_reward_pending": map_state.stage_reward_pending,
		"stage_reward_claimed": map_state.stage_reward_claimed,
		"stage_reward_options": _build_stage_reward_snapshot(),
		"route_affinity": map_state.route_affinity.duplicate(),
		"route_bonus_threshold_mods": map_state.route_bonus_threshold_mods.duplicate(),
		"crisis_preview": _build_crisis_preview(),
		"pending_event": card_controller.pending_event.duplicate(true) if card_controller != null else {},
		"pending_event_response_preview": _build_pending_event_response_preview(),
		"current_tile": _build_tile_snapshot(tiles.get(map_state.player_coord)),
		"selected_tile": _build_tile_snapshot(get_selected_tile()),
		"actions": _build_actions(),
		"log": event_log.duplicate(),
	}


func _build_inventory_snapshot() -> Array:
	var entries: Array = []
	for item_id in map_state.inventory.keys():
		var key := str(item_id)
		var use_state := _evaluate_item_use(key)
		entries.append({
			"id": key,
			"name": _get_item_name(key),
			"quantity": int(map_state.inventory[item_id]),
			"description": str(item_defs.get(key, {}).get("description", "")),
			"use_action_id": str(use_state.get("id", "")),
			"use_label": str(use_state.get("label", "使用")),
			"use_enabled": bool(use_state.get("enabled", false)),
			"use_reason": str(use_state.get("reason", "")),
			"use_effect_summary": str(use_state.get("summary", "")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	return entries


func _build_stage_reward_snapshot() -> Array:
	var entries: Array = []
	for reward in map_state.stage_reward_options:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		var reward_id := str(reward.get("id", ""))
		var action := _evaluate_reward_action(reward_id)
		entries.append({
			"id": reward_id,
			"name": str(reward.get("name", reward_id)),
			"description": str(reward.get("description", "")),
			"effect_summary": str(action.get("summary", "")),
			"action_id": str(action.get("id", "")),
			"enabled": bool(action.get("enabled", false)),
		})
	return entries


func _build_stage_node_snapshot() -> Array:
	var entries: Array = []
	for node in map_state.stage_node_options:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var node_id := str(node.get("id", ""))
		var action := _evaluate_node_action(node_id)
		entries.append({
			"id": node_id,
			"name": str(node.get("name", node_id)),
			"description": str(node.get("description", "")),
			"effect_summary": str(action.get("summary", "")),
			"action_id": str(action.get("id", "")),
			"enabled": bool(action.get("enabled", false)),
			"turn_limit": int(node.get("turn_limit", 0)),
		})
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
	if map_state.event_countdown <= 0 or map_state.stage_resolved:
		return
	map_state.event_countdown -= 1
	map_state.event_summary = _format_stage_countdown_summary()
	if map_state.event_countdown == 0:
		_open_stage_crisis()


func _open_stage_crisis() -> void:
	if map_state.crisis_active or map_state.stage_resolved:
		return
	var current_tile: RefCounted = tiles.get(map_state.player_coord)
	if current_tile != null:
		current_tile.explored = true
	map_state.crisis_active = true
	_apply_stage_effects(_get_current_crisis_def().get("open_effects", []))
	map_state.event_summary = map_state.event_crisis_summary
	map_state.sanity_status = "临界"
	_log(map_state.event_crisis_log)


func _try_resolve_stage_crisis(action_id: String) -> void:
	var result := _evaluate_crisis_action(action_id)
	if not bool(result.get("enabled", false)):
		_log(str(result.get("reason", "条件不足。")))
		_update_ui()
		return
	_resolve_stage_crisis(action_id)


func _evaluate_crisis_action(action_id: String) -> Dictionary:
	var action_def := _find_current_crisis_action(action_id)
	var label := str(action_def.get("name", action_id))
	var enabled: bool = map_state.crisis_active and not map_state.stage_resolved
	var reason := ""
	if action_def.is_empty():
		enabled = false
		reason = "未知结局"
	if enabled:
		var requirement_result := _crisis_requirements_result(action_def.get("requirements", []))
		enabled = bool(requirement_result.get("met", true))
		reason = str(requirement_result.get("reason", ""))
	if not map_state.crisis_active:
		reason = "最终事件尚未爆发"
	elif map_state.stage_resolved:
		reason = "最终事件已结算"
	return {
		"id": action_id,
		"label": label,
		"enabled": enabled,
		"reason": reason,
		"cost": 0,
	}


func _get_current_crisis_def() -> Dictionary:
	return stage_crisis_defs.get(map_state.event_key, stage_crisis_defs.get("plague_outbreak", {}))


func _get_current_crisis_actions() -> Array:
	return _get_current_crisis_def().get("actions", [])


func _get_stage_turn_events(event_key: String) -> Array:
	var event_pool: Dictionary = stage_event_defs.get(event_key, {})
	return event_pool.get("events", []).duplicate(true)


func _find_current_crisis_action(action_id: String) -> Dictionary:
	for action in _get_current_crisis_actions():
		if typeof(action) == TYPE_DICTIONARY and str(action.get("id", "")) == action_id:
			return action
	return {}


func _is_crisis_action(action_id: String) -> bool:
	return not _find_current_crisis_action(action_id).is_empty()


func _crisis_requirements_result(requirements: Array) -> Dictionary:
	var context := _build_crisis_context()
	for requirement in requirements:
		if typeof(requirement) != TYPE_DICTIONARY:
			continue
		if _crisis_requirement_met(requirement, context):
			continue
		return {
			"met": false,
			"reason": str(requirement.get("reason", _format_requirement_reason(requirement, context))),
		}
	return {"met": true, "reason": ""}


func _crisis_requirement_met(requirement: Dictionary, context: Dictionary) -> bool:
	var key := str(requirement.get("key", ""))
	var op := str(requirement.get("op", ">="))
	var target := int(requirement.get("value", 0))
	var actual := int(context.get(key, 0))
	return _compare_int(actual, target, op)


func _format_requirement_reason(requirement: Dictionary, context: Dictionary) -> String:
	var key := str(requirement.get("key", ""))
	var progress_name := _effect_progress_name(key)
	var label := progress_name if progress_name != key else _effect_resource_name(key)
	return "%s 需要 %s，当前 %s" % [
		label,
		str(int(requirement.get("value", 0))),
		str(int(context.get(key, 0))),
	]


func _compare_int(actual: int, target: int, op: String) -> bool:
	match op:
		">=":
			return actual >= target
		"<=":
			return actual <= target
		">":
			return actual > target
		"<":
			return actual < target
		"==":
			return actual == target
		"!=":
			return actual != target
	return actual >= target


func _build_crisis_context() -> Dictionary:
	var card_snapshot := {}
	if card_controller != null:
		card_snapshot = card_controller.get_snapshot()
	var card_resources: Dictionary = card_snapshot.get("resources", {})
	var card_progress: Dictionary = card_snapshot.get("progress", {})
	var context := {}
	for key in card_resources.keys():
		var resource_key := str(key)
		if CARD_GLOBAL_RESOURCE_KEYS.has(resource_key):
			continue
		context[resource_key] = int(card_resources.get(key, 0))
	for key in card_progress.keys():
		context[str(key)] = int(card_progress.get(key, 0))
	for key in map_state.global_resources.keys():
		context[str(key)] = int(map_state.global_resources.get(key, 0))
	context["suspicious_clue"] = int(map_state.inventory.get("suspicious_clue", 0))
	context["usable_clues"] = max(int(context.get("source_clues", 0)), int(context.get("suspicious_clue", 0)))
	context["secrecy_pressure"] = map_state.secrecy_pressure
	return context


func _format_stage_countdown_summary() -> String:
	return map_state.event_countdown_template.replace("{countdown}", str(map_state.event_countdown))


func _build_crisis_preview() -> Array:
	var context := _build_crisis_context()
	var previews: Array = []
	for action in _get_current_crisis_actions():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var preview_items: Array = action.get("preview", [])
		if preview_items.is_empty():
			continue
		previews.append({
			"id": str(action.get("id", "")),
			"name": str(action.get("name", "")),
			"ready": bool(_crisis_requirements_result(action.get("requirements", [])).get("met", true)),
			"status": _format_crisis_preview_items(preview_items, context),
		})
	return previews


func _format_crisis_preview_items(preview_items: Array, context: Dictionary) -> String:
	var parts: Array[String] = []
	for item in preview_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var key := str(item.get("key", ""))
		var label := str(item.get("label", key))
		var op := str(item.get("op", ">="))
		var value := int(item.get("value", 0))
		var actual := int(context.get(key, 0))
		var target_text := "≤%s" % str(value) if op == "<=" else str(value)
		parts.append("%s %s/%s" % [label, str(actual), target_text])
	return "  ".join(parts)


func _build_pending_event_response_preview() -> Array:
	if card_controller == null or card_controller.pending_event.is_empty():
		return []
	var event: Dictionary = card_controller.pending_event
	var response_defs := [
		{"mode": "handled", "name": "处理", "effects_key": "handled_effects", "cost": 1},
		{"mode": "converted", "name": "转化", "effects_key": "converted_effects", "cost": 1},
		{"mode": "exploited", "name": "利用", "effects_key": "exploited_effects", "cost": 1},
		{"mode": "ignored", "name": "放任", "effects_key": "effects", "cost": 0},
	]
	var previews: Array = []
	for response in response_defs:
		var effects: Array = event.get(str(response.get("effects_key", "")), [])
		if effects.is_empty():
			continue
		var mode := str(response.get("mode", ""))
		var bonus_effects: Array = _pending_event_route_bonus_effects(event, mode)
		var bonus_previews: Array = _pending_event_route_bonus_previews(event, mode)
		var summary := _summarize_effects(effects)
		var bonus_summary := _summarize_effects(bonus_effects) if not bonus_effects.is_empty() else ""
		if not bonus_summary.is_empty():
			summary += "；路线加成：" + bonus_summary
		previews.append({
			"mode": mode,
			"name": str(response.get("name", "")),
			"cost": int(response.get("cost", 0)),
			"summary": summary,
			"bonus_summary": bonus_summary,
			"route_bonus_preview": bonus_previews,
			"route_bonus_status": _format_route_bonus_status(bonus_previews),
		})
	return previews


func _pending_event_route_bonus_effects(event: Dictionary, mode: String) -> Array:
	var effects: Array = []
	for bonus in _active_pending_event_route_bonuses(event, mode):
		var bonus_effects: Array = bonus.get("effects", [])
		for effect in bonus_effects:
			if typeof(effect) == TYPE_DICTIONARY:
				effects.append(effect.duplicate(true))
	return effects


func _pending_event_route_bonus_previews(event: Dictionary, mode: String) -> Array:
	if event.is_empty():
		return []
	var previews: Array = []
	for bonus in event.get("route_bonuses", []):
		if typeof(bonus) != TYPE_DICTIONARY:
			continue
		var bonus_mode := str(bonus.get("mode", ""))
		if not bonus_mode.is_empty() and bonus_mode != mode:
			continue
		var route := str(bonus.get("route", ""))
		var base_threshold := int(bonus.get("threshold", 1))
		var threshold := _adjusted_route_bonus_threshold(route, base_threshold)
		var current := int(map_state.route_affinity.get(route, 0))
		var bonus_effects: Array = bonus.get("effects", [])
		previews.append({
			"name": str(bonus.get("name", _effect_route_name(route))),
			"route": route,
			"route_name": _effect_route_name(route),
			"current": current,
			"threshold": threshold,
			"base_threshold": base_threshold,
			"threshold_modifier": int(map_state.route_bonus_threshold_mods.get(route, 0)),
			"active": current >= threshold,
			"summary": _summarize_effects(bonus_effects),
		})
	return previews


func _format_route_bonus_status(previews: Array) -> String:
	if previews.is_empty():
		return ""
	var parts: Array[String] = []
	for preview in previews:
		if typeof(preview) != TYPE_DICTIONARY:
			continue
		var prefix := "已解锁" if bool(preview.get("active", false)) else "未解锁"
		parts.append("%s %s %s/%s：%s" % [
			prefix,
			str(preview.get("route_name", "")),
			str(preview.get("current", 0)),
			str(preview.get("threshold", 0)),
			str(preview.get("summary", "")),
		])
	return "；".join(parts)


func _active_pending_event_route_bonuses(event: Dictionary, mode: String) -> Array:
	if event.is_empty():
		return []
	var bonuses: Array = []
	for bonus in event.get("route_bonuses", []):
		if typeof(bonus) != TYPE_DICTIONARY:
			continue
		var bonus_mode := str(bonus.get("mode", ""))
		if not bonus_mode.is_empty() and bonus_mode != mode:
			continue
		var route := str(bonus.get("route", ""))
		var threshold := _adjusted_route_bonus_threshold(route, int(bonus.get("threshold", 1)))
		if int(map_state.route_affinity.get(route, 0)) < threshold:
			continue
		bonuses.append(bonus)
	return bonuses


func _adjusted_route_bonus_threshold(route: String, base_threshold: int) -> int:
	return max(0, base_threshold + int(map_state.route_bonus_threshold_mods.get(route, 0)))


func _summarize_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var text := _summarize_effect(effect)
		if not text.is_empty():
			parts.append(text)
	return "；".join(parts) if not parts.is_empty() else "无直接后果"


func _summarize_item_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var text := _summarize_item_effect(effect)
		if not text.is_empty():
			parts.append(text)
	return "；".join(parts) if not parts.is_empty() else "无直接效果"


func _summarize_item_effect(effect: Dictionary) -> String:
	var scope := str(effect.get("scope", ""))
	var delta := int(effect.get("delta", 0))
	match scope:
		"player_life":
			return "生命 %s" % _signed_int(delta)
		"experience":
			return "经验 %s" % _signed_int(delta)
		"global_resource":
			return "%s %s" % [_effect_resource_name(str(effect.get("key", ""))), _signed_int(delta)]
		"card_resource":
			return "%s %s" % [_effect_resource_name(str(effect.get("key", ""))), _signed_int(delta)]
		"card_progress":
			return "%s %s" % [_effect_progress_name(str(effect.get("key", ""))), _signed_int(delta)]
		"route_affinity":
			return "%s %s" % [_effect_route_name(str(effect.get("route", ""))), _signed_int(delta)]
		"route_bonus_threshold":
			return "%s加成阈值 %s" % [_effect_route_name(str(effect.get("route", ""))), _signed_int(delta)]
		"secrecy_pressure":
			return "追踪压力 %s" % _signed_int(delta)
		"tile_state":
			var op := str(effect.get("op", "add"))
			var prefix := "移除状态" if op == "remove" else "地块状态"
			return "%s：%s" % [prefix, _state_name(str(effect.get("state", "")))]
		"card_discard":
			return "获得卡牌：%s" % _card_name(str(effect.get("card_id", "")))
		"inventory":
			return "%s %s" % [_get_item_name(str(effect.get("item", ""))), _signed_int(delta)]
		"log":
			return ""
	return ""


func _summarize_effect(effect: Dictionary) -> String:
	var kind := str(effect.get("kind", ""))
	match kind:
		"resource":
			return "%s %s" % [_effect_resource_name(str(effect.get("key", ""))), _signed_int(int(effect.get("value", 0)))]
		"progress":
			return "%s %s" % [_effect_progress_name(str(effect.get("key", ""))), _signed_int(int(effect.get("value", 0)))]
		"map_tile_state":
			var op := str(effect.get("op", "add"))
			var prefix := "移除状态" if op == "remove" else "地块状态"
			return "%s：%s" % [prefix, _state_name(str(effect.get("state", "")))]
		"add_card_to_discard":
			return "污染牌：%s" % _card_name(str(effect.get("card_id", "")))
		"log":
			return ""
	return ""


func _effect_resource_name(key: String) -> String:
	match key:
		"faith":
			return "信仰"
		"followers":
			return "信徒"
		"materials":
			return "材料"
		"exposure":
			return "暴露"
		"sanity":
			return "理智"
		"will":
			return "灵性"
	return key


func _effect_progress_name(key: String) -> String:
	match key:
		"cure_progress":
			return "治疗"
		"source_clues":
			return "线索"
		"usable_clues":
			return "线索"
		"anchor_progress":
			return "锚点"
		"public_trust":
			return "信任"
		"witness":
			return "见证"
		"infection":
			return "感染"
		"suspicion":
			return "怀疑"
		"life_route":
			return "生命倾向"
		"death_route":
			return "死亡倾向"
		"secret_route":
			return "隐秘倾向"
	return key


func _effect_route_name(route_id: String) -> String:
	match route_id:
		"life":
			return "生命倾向"
		"faith":
			return "信仰倾向"
		"death":
			return "死亡倾向"
		"secret":
			return "隐秘倾向"
	return route_id


func _state_name(state_id: String) -> String:
	return str(state_defs.get(state_id, {}).get("name", state_id))


func _card_name(card_id: String) -> String:
	if card_controller == null:
		return card_id
	return str(card_controller.get_card_def(card_id).get("name", card_id))


func _signed_int(value: int) -> String:
	if value > 0:
		return "+%s" % str(value)
	return str(value)


func _resolve_stage_crisis(action_id: String) -> void:
	var action_def := _find_current_crisis_action(action_id)
	if action_def.is_empty():
		_log("未知最终事件解法：%s。" % action_id)
		_update_ui()
		return
	map_state.crisis_active = false
	map_state.stage_resolved = true
	map_state.stage_result_id = action_id
	_apply_stage_effects(action_def.get("effects", []))
	_open_stage_rewards(action_id)
	_update_after_map_change()


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
