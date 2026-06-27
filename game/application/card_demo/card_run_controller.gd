extends Node
class_name CardRunController

signal state_changed(snapshot: Dictionary)
signal log_added(message: String)
signal encounter_finished(result: Dictionary)
signal effects_applied(effects: Array, source: Dictionary)

const CARDS_PATH := "res://data/demo/card_demo/cards.json"
const ENCOUNTERS_PATH := "res://data/demo/card_demo/encounters.json"

var card_defs: Dictionary = {}
var encounter_defs: Dictionary = {}

var current_encounter: Dictionary = {}
var current_event_pool_id: String = ""
var resources: Dictionary = {}
var progress: Dictionary = {}
var persistent_deck: Array = []
var deck: Array = []
var hand: Array = []
var discard: Array = []
var pending_event: Dictionary = {}
var log_messages: Array[String] = []
var rng := RandomNumberGenerator.new()

var turn: int = 0
var countdown: int = 0
var hand_size: int = 5
var max_action_points: int = 3
var is_finished: bool = false
var final_result: Dictionary = {}


func start_demo(encounter_id: String = "sick_village", turn_events_override: Array = [], event_pool_id: String = "") -> void:
	rng.randomize()
	_load_data()
	assert(encounter_defs.has(encounter_id), "Encounter not found: " + encounter_id)
	current_encounter = encounter_defs[encounter_id].duplicate(true)
	current_event_pool_id = event_pool_id
	if not turn_events_override.is_empty():
		current_encounter["turn_events"] = turn_events_override.duplicate(true)
		current_encounter["event_pool_id"] = event_pool_id
	resources = current_encounter.get("initial_resources", {}).duplicate(true)
	progress = current_encounter.get("initial_progress", {}).duplicate(true)
	if persistent_deck.is_empty():
		persistent_deck = current_encounter.get("starting_deck", []).duplicate(true)
	deck = persistent_deck.duplicate(true)
	hand.clear()
	discard.clear()
	pending_event.clear()
	log_messages.clear()
	final_result.clear()
	turn = 1
	countdown = int(current_encounter.get("turn_limit", 6))
	hand_size = int(current_encounter.get("hand_size", 5))
	max_action_points = int(current_encounter.get("action_points", 3))
	resources["action_points"] = max_action_points
	is_finished = false
	deck.shuffle()
	_log("关卡开始：" + str(current_encounter.get("name", encounter_id)))
	_log(str(current_encounter.get("description", "")))
	_queue_turn_event()
	_draw_new_hand()
	_emit_state()


func play_card(hand_index: int) -> bool:
	if is_finished:
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id = str(hand[hand_index])
	var card = get_card_def(card_id)
	if not can_play_card(hand_index):
		_log("无法打出：" + str(card.get("name", card_id)))
		_emit_state()
		return false
	resources["action_points"] = int(resources.get("action_points", 0)) - int(card.get("cost", 0))
	hand.remove_at(hand_index)
	_log("打出卡牌：" + str(card.get("name", card_id)))
	_apply_effects(card.get("effects", []), {
		"type": "card",
		"id": card_id,
		"name": str(card.get("name", card_id)),
	})
	if not bool(card.get("exhaust", false)):
		discard.append(card_id)
	_emit_state()
	return true


func can_play_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card = get_card_def(str(hand[hand_index]))
	if int(resources.get("action_points", 0)) < int(card.get("cost", 0)):
		return false
	return _requirements_met(card.get("requirements", []))


func end_turn() -> void:
	if is_finished:
		return
	_apply_unplayed_status_cards()
	for card_id in hand:
		discard.append(card_id)
	hand.clear()
	resolve_pending_event("ignored")
	countdown -= 1
	if countdown <= 0:
		resolve_final_event()
		return
	turn += 1
	resources["action_points"] = max_action_points
	_queue_turn_event()
	_draw_new_hand()
	_emit_state()


func resolve_final_event() -> Dictionary:
	if is_finished:
		return final_result
	is_finished = true
	for outcome in current_encounter.get("outcomes", []):
		if _requirements_met(outcome.get("requirements", [])):
			final_result = outcome.duplicate(true)
			break
	if final_result.is_empty():
		final_result = {
			"id": "unknown",
			"name": "未知结局",
			"text": "关卡结束，但没有匹配到任何结局。"
		}
	_log("最终事件：" + str(current_encounter.get("final_event", "最终事件")))
	_log(str(final_result.get("name", "结局")) + "：" + str(final_result.get("text", "")))
	_apply_effects(final_result.get("rewards", []), {
		"type": "final_event",
		"id": str(final_result.get("id", "")),
		"name": str(final_result.get("name", "")),
	})
	_emit_state()
	encounter_finished.emit(final_result)
	return final_result


func get_snapshot() -> Dictionary:
	var hand_cards: Array = []
	for i in range(hand.size()):
		var card = get_card_def(str(hand[i])).duplicate(true)
		card["hand_index"] = i
		card["can_play"] = can_play_card(i)
		hand_cards.append(card)
	return {
		"encounter": current_encounter.duplicate(true),
		"event_pool_id": current_event_pool_id,
		"turn": turn,
		"countdown": countdown,
		"resources": resources.duplicate(true),
		"progress": progress.duplicate(true),
		"deck_count": deck.size(),
		"discard_count": discard.size(),
		"pending_event": pending_event.duplicate(true),
		"hand": hand_cards,
		"log": log_messages.duplicate(),
		"is_finished": is_finished,
		"final_result": final_result.duplicate(true)
	}


func get_card_def(card_id: String) -> Dictionary:
	return card_defs.get(card_id, {
		"id": card_id,
		"name": card_id,
		"type": "未知",
		"cost": 0,
		"text": "Missing card definition."
	})


func sync_resources(values: Dictionary) -> void:
	var changed := false
	for key in values.keys():
		var resource_key := str(key)
		var next_value: int = max(0, int(values.get(key, 0)))
		if int(resources.get(resource_key, 0)) == next_value:
			continue
		resources[resource_key] = next_value
		changed = true
	if changed:
		_emit_state()


func apply_external_deltas(resource_deltas: Dictionary, progress_deltas: Dictionary) -> void:
	var changed := false
	for key in resource_deltas.keys():
		var resource_key := str(key)
		var before_resource := int(resources.get(resource_key, 0))
		_change_resource(resource_key, int(resource_deltas.get(key, 0)))
		changed = changed or int(resources.get(resource_key, 0)) != before_resource
	for key in progress_deltas.keys():
		var progress_key := str(key)
		var before_progress := int(progress.get(progress_key, 0))
		_change_progress(progress_key, int(progress_deltas.get(key, 0)))
		changed = changed or int(progress.get(progress_key, 0)) != before_progress
	if changed:
		_emit_state()


func apply_external_effects(effects: Array, source: Dictionary = {}) -> void:
	if effects.is_empty():
		return
	_apply_effects(effects, source)
	_emit_state()


func grant_card_to_discard(card_id: String) -> bool:
	if card_id.is_empty() or not card_defs.has(card_id):
		return false
	persistent_deck.append(card_id)
	discard.append(card_id)
	_log("获得卡牌：" + str(get_card_def(card_id).get("name", card_id)))
	_emit_state()
	return true


func replace_card_everywhere(from_card_id: String, to_card_id: String) -> bool:
	if from_card_id.is_empty() or to_card_id.is_empty() or not card_defs.has(to_card_id):
		return false
	var changed := false
	changed = _replace_card_ids(persistent_deck, from_card_id, to_card_id) or changed
	changed = _replace_card_ids(deck, from_card_id, to_card_id) or changed
	changed = _replace_card_ids(hand, from_card_id, to_card_id) or changed
	changed = _replace_card_ids(discard, from_card_id, to_card_id) or changed
	if changed:
		_log("升级卡牌：%s -> %s" % [
			str(get_card_def(from_card_id).get("name", from_card_id)),
			str(get_card_def(to_card_id).get("name", to_card_id)),
		])
		_emit_state()
	return changed


func has_card_anywhere(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	return persistent_deck.has(card_id) or deck.has(card_id) or hand.has(card_id) or discard.has(card_id)


func _replace_card_ids(cards: Array, from_card_id: String, to_card_id: String) -> bool:
	var changed := false
	for i in range(cards.size()):
		if str(cards[i]) == from_card_id:
			cards[i] = to_card_id
			changed = true
	return changed


func has_pending_event() -> bool:
	return not pending_event.is_empty()


func resolve_pending_event(mode: String = "ignored") -> bool:
	if pending_event.is_empty():
		return false
	var event := pending_event.duplicate(true)
	pending_event.clear()
	var effects_key := _pending_event_effects_key(mode)
	var source_type := _pending_event_source_type(mode)
	_log(_pending_event_log_label(mode) + str(event.get("name", "")))
	_apply_effects(event.get(effects_key, []), {
		"type": source_type,
		"id": str(event.get("id", "")),
		"name": str(event.get("name", "")),
	})
	_emit_state()
	return true


func pending_event_has_response(mode: String) -> bool:
	if pending_event.is_empty():
		return false
	return not pending_event.get(_pending_event_effects_key(mode), []).is_empty()


func _load_data() -> void:
	if not card_defs.is_empty() and not encounter_defs.is_empty():
		return
	card_defs.clear()
	encounter_defs.clear()
	for card in _read_json_array(CARDS_PATH):
		card_defs[card["id"]] = card
	for encounter in _read_json_array(ENCOUNTERS_PATH):
		encounter_defs[encounter["id"]] = encounter


func _read_json_array(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON file: " + path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("JSON file must be an array: " + path)
		return []
	return parsed


func _draw_new_hand() -> void:
	while hand.size() < hand_size:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard.clear()
			deck.shuffle()
		hand.append(deck.pop_back())


func _queue_turn_event() -> void:
	var events: Array = []
	for event in current_encounter.get("turn_events", []):
		if _requirements_met(event.get("requirements", [])):
			events.append(event)
	if events.is_empty():
		pending_event.clear()
		return
	var event = events[rng.randi_range(0, events.size() - 1)]
	pending_event = event.duplicate(true)
	_log("事件预兆：" + str(event.get("name", "")) + " - " + str(event.get("text", "")))


func _pending_event_effects_key(mode: String) -> String:
	match mode:
		"handled":
			return "handled_effects"
		"converted":
			return "converted_effects"
		"exploited":
			return "exploited_effects"
		_:
			return "effects"


func _pending_event_source_type(mode: String) -> String:
	match mode:
		"handled":
			return "turn_event_handled"
		"converted":
			return "turn_event_converted"
		"exploited":
			return "turn_event_exploited"
		_:
			return "turn_event"


func _pending_event_log_label(mode: String) -> String:
	match mode:
		"handled":
			return "处理预兆："
		"converted":
			return "转化预兆："
		"exploited":
			return "利用预兆："
		_:
			return "放任预兆："


func _apply_unplayed_status_cards() -> void:
	var status_count := 0
	for card_id in hand:
		var card = get_card_def(str(card_id))
		if str(card.get("type", "")) == "污染":
			status_count += 1
	if status_count > 0:
		_change_resource("sanity", -status_count)
		_log("未处理的污染牌让理智下降：" + str(status_count))


func _apply_effects(effects: Array, source: Dictionary = {}) -> void:
	for effect in effects:
		var kind = str(effect.get("kind", ""))
		match kind:
			"resource":
				_change_resource(str(effect.get("key", "")), int(effect.get("value", 0)))
			"progress":
				_change_progress(str(effect.get("key", "")), int(effect.get("value", 0)))
			"add_card_to_discard":
				var card_id = str(effect.get("card_id", ""))
				if card_defs.has(card_id):
					discard.append(card_id)
					_log("获得卡牌：" + str(get_card_def(card_id).get("name", card_id)))
			"log":
				_log(str(effect.get("text", "")))
	if not effects.is_empty():
		effects_applied.emit(effects.duplicate(true), source.duplicate(true))


func _change_resource(key: String, value: int) -> void:
	if key.is_empty():
		return
	var current = int(resources.get(key, 0))
	resources[key] = max(0, current + value)


func _change_progress(key: String, value: int) -> void:
	if key.is_empty():
		return
	var current = int(progress.get(key, 0))
	progress[key] = max(0, current + value)


func _requirements_met(requirements: Array) -> bool:
	for requirement in requirements:
		var scope = str(requirement.get("scope", "resource"))
		var key = str(requirement.get("key", ""))
		var op = str(requirement.get("op", ">="))
		var target = int(requirement.get("value", 0))
		var actual := 0
		match scope:
			"progress":
				actual = int(progress.get(key, 0))
			_:
				actual = int(resources.get(key, 0))
		if not _compare_int(actual, target, op):
			return false
	return true


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


func _log(message: String) -> void:
	if message.is_empty():
		return
	log_messages.append(message)
	if log_messages.size() > 80:
		log_messages.pop_front()
	log_added.emit(message)


func _emit_state() -> void:
	state_changed.emit(get_snapshot())
