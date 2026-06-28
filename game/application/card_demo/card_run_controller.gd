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

var phase: String = "preparation"
var boss_state: Dictionary = {}
var player_block: int = 0
var protected_followers: int = 0
var next_life_bonus: int = 0

var turn: int = 0
var countdown: int = 0
var hand_size: int = 5
var max_action_points: int = 3
var is_finished: bool = false
var final_result: Dictionary = {}
var pending_reward_cards: Array = []


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
	pending_reward_cards.clear()
	phase = "preparation"
	boss_state.clear()
	player_block = 0
	protected_followers = 0
	next_life_bonus = 0
	turn = 1
	countdown = int(current_encounter.get("turn_limit", 6))
	hand_size = int(current_encounter.get("hand_size", 5))
	max_action_points = int(current_encounter.get("action_points", 3))
	resources["action_points"] = max_action_points
	if resources.has("max_life") and not resources.has("life"):
		resources["life"] = int(resources.get("max_life", 0))
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
	var cost := _current_card_cost(hand_index)
	resources["action_points"] = int(resources.get("action_points", 0)) - cost
	hand.remove_at(hand_index)
	_log("打出卡牌：" + str(card.get("name", card_id)))
	var bonus := 0
	if next_life_bonus > 0 and card.get("tags", []).has("生命"):
		bonus = next_life_bonus
		next_life_bonus = 0
	_apply_effects(card.get("effects", []), {
		"type": "card",
		"id": card_id,
		"name": str(card.get("name", card_id)),
		"life_bonus": bonus,
	})
	if not bool(card.get("exhaust", false)):
		discard.append(card_id)
	_maybe_start_boss_from_preparation("主动挑战")
	_emit_state()
	return true


func can_play_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card = get_card_def(str(hand[hand_index]))
	if int(resources.get("action_points", 0)) < _current_card_cost(hand_index):
		return false
	return _requirements_met(card.get("requirements", []))


func end_turn() -> void:
	if is_finished:
		return
	_apply_unplayed_status_cards()
	for card_id in hand:
		discard.append(card_id)
	hand.clear()
	if phase == "boss":
		_resolve_boss_intent()
		if is_finished:
			_emit_state()
			return
		turn += 1
		resources["action_points"] = max_action_points
		player_block = 0
		protected_followers = 0
		_set_next_boss_intent()
		_draw_new_hand()
		_emit_state()
		return
	resolve_pending_event("ignored")
	if _maybe_start_boss_from_preparation("主动挑战"):
		_emit_state()
		return
	countdown -= 1
	if countdown <= 0:
		if current_encounter.has("boss"):
			_start_boss("倒计时结束")
			_emit_state()
			return
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
		card["cost"] = _current_card_cost(i)
		card["can_play"] = can_play_card(i)
		hand_cards.append(card)
	return {
		"encounter": current_encounter.duplicate(true),
		"event_pool_id": current_event_pool_id,
		"phase": phase,
		"turn": turn,
		"countdown": countdown,
		"resources": resources.duplicate(true),
		"progress": progress.duplicate(true),
		"player_block": player_block,
		"protected_followers": protected_followers,
		"next_life_bonus": next_life_bonus,
		"boss": boss_state.duplicate(true),
			"deck_count": deck.size(),
			"discard_count": discard.size(),
			"pending_event": pending_event.duplicate(true),
			"pending_reward_cards": _build_pending_reward_card_snapshot(),
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


func _build_pending_reward_card_snapshot() -> Array:
	var entries: Array = []
	for i in range(pending_reward_cards.size()):
		var card_id := str(pending_reward_cards[i])
		if not card_defs.has(card_id):
			continue
		var card := get_card_def(card_id).duplicate(true)
		card["reward_index"] = i
		card["can_choose"] = true
		card["cost"] = int(card.get("cost", 0))
		entries.append(card)
	return entries


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
		_maybe_start_boss_from_preparation("主动挑战")
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


func choose_reward_card(choice_index: int) -> bool:
	if choice_index < 0 or choice_index >= pending_reward_cards.size():
		return false
	var card_id := str(pending_reward_cards[choice_index])
	if card_id.is_empty() or not card_defs.has(card_id):
		return false
	pending_reward_cards.clear()
	persistent_deck.append(card_id)
	discard.append(card_id)
	_log("选择奖励牌：" + str(get_card_def(card_id).get("name", card_id)))
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
	if phase != "preparation":
		pending_event.clear()
		return
	if current_encounter.has("intent_sequence"):
		var sequence_event := _event_from_sequence()
		if not sequence_event.is_empty():
			pending_event = sequence_event.duplicate(true)
			_log("敌方意图：" + str(sequence_event.get("name", "")) + " - " + str(sequence_event.get("text", "")))
			return
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


func _event_from_sequence() -> Dictionary:
	var sequence: Array = current_encounter.get("intent_sequence", [])
	var events: Array = current_encounter.get("turn_events", [])
	if sequence.is_empty() or events.is_empty():
		return {}
	var index: int = clamp(turn - 1, 0, sequence.size() - 1)
	var wanted_id := str(sequence[index])
	if turn > sequence.size():
		wanted_id = str(sequence[sequence.size() - 1])
	wanted_id = _adjust_sequence_intent(wanted_id)
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("id", "")) == wanted_id:
			return event
	return {}


func _adjust_sequence_intent(intent_id: String) -> String:
	if int(progress.get("infection", 0)) >= 4 and ["kaun_infection", "kaun_charge"].has(intent_id):
		return "kaun_infection"
	if int(resources.get("followers", 0)) >= 2 and intent_id == "kaun_seek":
		return "kaun_break"
	if int(resources.get("exposure", 0)) >= 2 and intent_id == "kaun_whisper":
		return "kaun_seek"
	if int(progress.get("source_clues", 0)) >= 2 and intent_id == "kaun_break":
		return "kaun_whisper"
	return intent_id


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
		if str(card.get("type", "")) != "污染":
			continue
		status_count += 1
		match str(card_id):
			"pus_blood":
				_change_resource("life", -1)
				_log("未处理的脓血让生命 -1。")
			"high_fever":
				_change_resource("sanity", -1)
				_log("未处理的高热让理智下降。")
	if status_count > 0:
		_log("未处理的污染牌数量：" + str(status_count))


func _apply_effects(effects: Array, source: Dictionary = {}) -> void:
	var source_bonus := int(source.get("life_bonus", 0))
	for effect in effects:
		var kind = str(effect.get("kind", ""))
		var effect_value := int(effect.get("value", 0)) + source_bonus if _effect_accepts_life_bonus(kind) else int(effect.get("value", 0))
		match kind:
			"resource":
				_change_resource(str(effect.get("key", "")), effect_value)
			"progress":
				_change_progress(str(effect.get("key", "")), effect_value)
			"add_card_to_discard":
				var card_id = str(effect.get("card_id", ""))
				if card_defs.has(card_id):
					persistent_deck.append(card_id)
					discard.append(card_id)
					_log("获得卡牌：" + str(get_card_def(card_id).get("name", card_id)))
			"damage_boss":
				_deal_boss_damage(effect_value)
			"block":
				player_block += max(0, effect_value)
				_log("获得护盾：" + str(max(0, effect_value)))
			"heal":
				_heal_player(effect_value)
			"heal_or_reduce_plague":
				_heal_or_reduce_plague(effect_value)
			"protect_follower":
				protected_followers += max(1, effect_value)
				_log("本回合保护信徒：" + str(protected_followers))
			"remove_lesion":
				_remove_boss_lesion(max(1, effect_value))
			"purify_boss":
				_try_purify_boss()
			"gain_action_points":
				_change_resource("action_points", effect_value)
			"lose_life":
				_change_resource("life", -max(0, effect_value))
			"next_life_bonus":
				next_life_bonus += max(1, effect_value)
				_log("下一张生命牌效果增强：" + str(next_life_bonus))
			"remove_status_from_hand":
				_remove_status_from_hand(str(effect.get("card_id", "")))
			"break_followers_or_infect":
				_break_followers_or_infect(max(1, effect_value))
			"log":
				_log(str(effect.get("text", "")))
	if not effects.is_empty():
		effects_applied.emit(effects.duplicate(true), source.duplicate(true))


func _effect_accepts_life_bonus(kind: String) -> bool:
	return ["progress", "damage_boss", "block", "heal", "heal_or_reduce_plague", "remove_lesion"].has(kind)


func _current_card_cost(hand_index: int) -> int:
	if hand_index < 0 or hand_index >= hand.size():
		return 999
	var card_id := str(hand[hand_index])
	var card := get_card_def(card_id)
	var cost := int(card.get("cost", 0))
	if _hand_has_card("high_fever") and str(card.get("type", "")) == "技能" and card_id != "high_fever":
		cost += 1
	return max(0, cost)


func _hand_has_card(card_id: String) -> bool:
	for item in hand:
		if str(item) == card_id:
			return true
	return false


func _maybe_start_boss_from_preparation(reason: String) -> bool:
	if phase != "preparation" or not current_encounter.has("boss"):
		return false
	if int(progress.get("source_clues", 0)) >= 3:
		_start_boss(reason + "：病源线索已满")
		return true
	if int(progress.get("anchor_progress", 0)) >= 3:
		_start_boss(reason + "：初生锚点已满")
		return true
	if int(progress.get("infection", 0)) >= 6:
		_start_boss("病势失控")
		return true
	return false


func _start_boss(reason: String) -> void:
	var boss_def: Dictionary = current_encounter.get("boss", {})
	phase = "boss"
	pending_event.clear()
	player_block = 0
	protected_followers = 0
	var infection := int(progress.get("infection", 0))
	var source_clues := int(progress.get("source_clues", 0))
	var charge := int(progress.get("enemy_charge", 0))
	var base_life := int(boss_def.get("life", 28))
	var boss_life: int = base_life + max(0, infection - 3) * 2 + charge * 4
	var lesion: int = max(0, int(boss_def.get("lesion_shield", 2)) - source_clues)
	boss_state = {
		"id": str(boss_def.get("id", "ulcer_apostle")),
		"name": str(boss_def.get("name", "溃疡使徒")),
		"life": boss_life,
		"max_life": boss_life,
		"lesion_shield": lesion,
		"charge": charge,
		"turn": 1,
		"intent": {},
		"damage_this_turn": 0,
		"lesion_removed_this_turn": false,
		"lesion_absorbed": false,
		"next_attack_bonus": 0,
		"purify_unlocked": int(progress.get("anchor_progress", 0)) >= 3,
	}
	countdown = 0
	resources["action_points"] = max_action_points
	_log("关底战开始：%s。%s抵达病村。" % [reason, str(boss_state.get("name", ""))])
	_set_next_boss_intent()
	_draw_new_hand()


func _set_next_boss_intent() -> void:
	if phase != "boss" or boss_state.is_empty():
		return
	var intents: Array = current_encounter.get("boss", {}).get("intents", [])
	if intents.is_empty():
		return
	var boss_turn := int(boss_state.get("turn", 1))
	var intent_id := ""
	if boss_turn == 1 and int(resources.get("exposure", 0)) >= 2:
		intent_id = "name_scent"
	elif int(boss_state.get("life", 0)) < 10 and _purify_conditions_met():
		intent_id = "burst_sore"
	else:
		var loop: Array = current_encounter.get("boss", {}).get("intent_loop", [])
		if loop.is_empty():
			intent_id = str(intents[0].get("id", ""))
		else:
			intent_id = str(loop[(boss_turn - 1) % loop.size()])
	for intent in intents:
		if typeof(intent) == TYPE_DICTIONARY and str(intent.get("id", "")) == intent_id:
			boss_state["intent"] = intent.duplicate(true)
			_log("使徒意图：%s - %s" % [str(intent.get("name", "")), str(intent.get("text", ""))])
			return


func _resolve_boss_intent() -> void:
	if phase != "boss" or boss_state.is_empty():
		return
	var intent: Dictionary = boss_state.get("intent", {})
	var intent_id := str(intent.get("id", ""))
	match intent_id:
		"scratch":
			_take_boss_damage(6 + int(boss_state.get("next_attack_bonus", 0)))
			boss_state["next_attack_bonus"] = 0
		"poison_spray":
			_take_boss_damage(3)
			_add_status_card("pus_blood")
		"name_scent":
			_change_resource("exposure", 1)
			boss_state["next_attack_bonus"] = int(boss_state.get("next_attack_bonus", 0)) + 3
			_log("闻名：隐秘恶化，下一次抓挠伤害 +3。")
		"foul_well":
			_change_progress("infection", 1)
			_log("污井：病势 +1。")
		"burst_sore":
			if int(boss_state.get("damage_this_turn", 0)) >= 6 or bool(boss_state.get("lesion_removed_this_turn", false)):
				_log("爆疮被打断：病灶没能压垮锚点。")
			else:
				_take_boss_damage(10)
	boss_state["turn"] = int(boss_state.get("turn", 1)) + 1
	boss_state["damage_this_turn"] = 0
	boss_state["lesion_removed_this_turn"] = false


func _deal_boss_damage(amount: int) -> void:
	if phase != "boss" or boss_state.is_empty():
		_log("神力伤害没有目标。")
		return
	var damage: int = max(0, amount)
	if int(boss_state.get("lesion_shield", 0)) > 0 and not bool(boss_state.get("lesion_absorbed", false)):
		damage = max(0, damage - 2)
		boss_state["lesion_absorbed"] = true
		_log("病灶护层吸收了 2 点伤害。")
	if damage <= 0:
		return
	boss_state["life"] = max(0, int(boss_state.get("life", 0)) - damage)
	boss_state["damage_this_turn"] = int(boss_state.get("damage_this_turn", 0)) + damage
	_log("对%s造成 %s 点伤害。" % [str(boss_state.get("name", "敌人")), str(damage)])
	if int(boss_state.get("life", 0)) <= 0:
		_finish_boss("kill")


func _take_boss_damage(amount: int) -> void:
	var incoming: int = max(0, amount)
	var blocked: int = min(player_block, incoming)
	player_block -= blocked
	incoming -= blocked
	if blocked > 0:
		_log("护盾抵消伤害：" + str(blocked))
	if incoming > 0:
		_change_resource("life", -incoming)
		_log("受到伤害：" + str(incoming))
	if int(resources.get("life", 0)) <= 0:
		_finish_boss("failure")


func _heal_player(amount: int) -> void:
	var max_life := int(resources.get("max_life", resources.get("life", 0)))
	var before := int(resources.get("life", 0))
	resources["life"] = min(max_life, before + max(0, amount))
	_log("恢复生命：" + str(int(resources.get("life", 0)) - before))


func _heal_or_reduce_plague(amount: int) -> void:
	if phase == "preparation" and int(progress.get("infection", 0)) > 0:
		_change_progress("infection", -max(0, amount))
		_log("病势 %s。" % str(-max(0, amount)))
	else:
		_heal_player(amount)


func _remove_boss_lesion(amount: int) -> void:
	if phase != "boss" or boss_state.is_empty():
		return
	var before := int(boss_state.get("lesion_shield", 0))
	boss_state["lesion_shield"] = max(0, before - max(0, amount))
	if int(boss_state.get("lesion_shield", 0)) < before:
		boss_state["lesion_removed_this_turn"] = true
		_log("移除病灶护层：" + str(before - int(boss_state.get("lesion_shield", 0))))


func _try_purify_boss() -> void:
	if phase != "boss":
		return
	if _purify_conditions_met():
		_finish_boss("purify")
		return
	_heal_player(3)
	_log("萌芽祭尚未满足净化条件，转为恢复生命。")


func _purify_conditions_met() -> bool:
	return phase == "boss" \
		and int(progress.get("anchor_progress", 0)) >= 3 \
		and int(progress.get("source_clues", 0)) >= 3 \
		and int(boss_state.get("life", 999)) < 10


func _finish_boss(result_id: String) -> void:
	if is_finished:
		return
	phase = "finished"
	is_finished = true
	var result: Dictionary = {}
	for candidate in current_encounter.get("boss_outcomes", []):
		if typeof(candidate) == TYPE_DICTIONARY and str(candidate.get("id", "")) == result_id:
			result = candidate.duplicate(true)
			break
	if result.is_empty():
		result = {
			"id": result_id,
			"name": "战斗结束",
			"text": "病村的关底战结束了。"
		}
	final_result = result
	_log(str(result.get("name", "战斗结束")) + "：" + str(result.get("text", "")))
	var rewards: Array = result.get("rewards", [])
	_apply_effects(_split_boss_immediate_rewards(rewards), {
		"type": "boss_result",
		"id": str(result.get("id", "")),
		"name": str(result.get("name", "")),
	})
	_open_reward_card_choices(result.get("card_reward_choices", []), rewards)
	encounter_finished.emit(final_result)


func _split_boss_immediate_rewards(rewards: Array) -> Array:
	var immediate: Array = []
	for effect in rewards:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("kind", "")) == "add_card_to_discard":
			continue
		immediate.append(effect)
	return immediate


func _open_reward_card_choices(explicit_choices: Array, rewards: Array) -> void:
	pending_reward_cards.clear()
	var choices: Array = explicit_choices.duplicate()
	if choices.is_empty():
		for effect in rewards:
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("kind", "")) == "add_card_to_discard":
				choices.append(str(effect.get("card_id", "")))
	for card_id_value in choices:
		var card_id := str(card_id_value)
		if card_defs.has(card_id) and not pending_reward_cards.has(card_id):
			pending_reward_cards.append(card_id)
	if pending_reward_cards.is_empty():
		return
	_log("关卡奖励：选择 1 张新牌加入牌组。")


func _add_status_card(card_id: String) -> void:
	if card_defs.has(card_id):
		discard.append(card_id)
		_log("污染牌加入弃牌堆：" + str(get_card_def(card_id).get("name", card_id)))


func _remove_status_from_hand(card_id: String) -> void:
	if card_id.is_empty():
		return
	var index := hand.find(card_id)
	if index >= 0:
		hand.remove_at(index)
		_log("移除状态牌：" + str(get_card_def(card_id).get("name", card_id)))


func _break_followers_or_infect(amount: int) -> void:
	var loss: int = max(1, amount)
	if protected_followers > 0:
		protected_followers = max(0, protected_followers - loss)
		_log("护身与安置抵消了破坏。")
		return
	if int(resources.get("followers", 0)) > 0:
		_change_resource("followers", -loss)
		_log("破坏夺走信徒：" + str(loss))
	else:
		_change_progress("infection", loss)
		_log("无人可夺，病势 +" + str(loss))


func _change_resource(key: String, value: int) -> void:
	if key.is_empty():
		return
	var current = int(resources.get(key, 0))
	if key == "life":
		resources[key] = clamp(current + value, 0, int(resources.get("max_life", max(current, 1))))
	else:
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
