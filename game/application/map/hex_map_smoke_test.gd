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

	map.card_controller.pending_event = _event_from_pool(map, "plague_outbreak", "patient_worsens")
	var locked_life_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(locked_life_preview.get("pending_event_response_preview", []), "handled", "未解锁 生命倾向 0/2"), "life route bonus starts locked")
	map.card_controller.hand = ["weak_heal"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.resources["will"] = 1
	map.card_controller.play_card(0)
	_assert(int(map.map_state.route_bonus_threshold_mods.get("life", 0)) == -1, "weak heal lowers life route bonus threshold")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == 1, "weak heal adds life route affinity")
	map.card_controller.pending_event = _event_from_pool(map, "plague_outbreak", "patient_worsens")
	var life_route_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(life_route_preview.get("pending_event_response_preview", []), "handled", "已解锁 生命倾向 1/1"), "weak heal unlocks life route bonus preview")
	_assert(_response_bonus_status_contains(life_route_preview.get("pending_event_response_preview", []), "handled", "阈值 -1"), "life route bonus preview shows card threshold modifier")
	var cure_before_life_bonus := int(map.card_controller.progress.get("cure_progress", 0))
	map._on_map_action_requested("handle_pending_event")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_life_bonus + 2, "life route bonus adds extra cure progress")
	map.map_state.action_points = 2

	map.card_controller.pending_event = _event_from_pool(map, "shrine_anchor_loss", "shrine_lamp_flickers")
	var locked_faith_preview: Dictionary = map._build_ui_snapshot()
	_assert(_inventory_summary_contains(locked_faith_preview.get("inventory", []), "relic_fragment", "信仰倾向加成阈值 -1"), "relic previews faith threshold modifier")
	_assert(_response_bonus_status_contains(locked_faith_preview.get("pending_event_response_preview", []), "handled", "未解锁 信仰倾向 0/2"), "faith route bonus starts locked")
	var anchor_before_relic := int(map.card_controller.progress.get("anchor_progress", 0))
	map._on_map_action_requested("use_item:relic_fragment")
	_assert(int(map.map_state.inventory.get("relic_fragment", 0)) == 0, "using relic consumes backpack item")
	_assert(int(map.map_state.route_bonus_threshold_mods.get("faith", 0)) == -1, "relic lowers faith route bonus threshold")
	_assert(int(map.map_state.route_affinity.get("faith", 0)) == 1, "relic adds faith route affinity")
	map.map_state.action_points = 1
	map.card_controller.pending_event = _event_from_pool(map, "shrine_anchor_loss", "shrine_lamp_flickers")
	var faith_route_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(faith_route_preview.get("pending_event_response_preview", []), "handled", "已解锁 信仰倾向 1/1"), "relic unlocks faith route bonus preview")
	_assert(_response_bonus_status_contains(faith_route_preview.get("pending_event_response_preview", []), "handled", "阈值 -1"), "route bonus preview shows threshold modifier")
	map._on_map_action_requested("handle_pending_event")
	_assert(int(map.card_controller.progress.get("anchor_progress", 0)) == anchor_before_relic + 3, "faith route bonus adds extra anchor progress")
	var faith_threshold_before_card := int(map.map_state.route_bonus_threshold_mods.get("faith", 0))
	map.card_controller.hand = ["small_ritual"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.resources["materials"] = 1
	map.card_controller.resources["faith"] = 1
	map.card_controller.play_card(0)
	_assert(int(map.map_state.route_bonus_threshold_mods.get("faith", 0)) == faith_threshold_before_card - 1, "small ritual lowers faith route bonus threshold")
	map.card_controller.pending_event = _event_from_pool(map, "shrine_anchor_loss", "shrine_lamp_flickers")
	var card_threshold_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(card_threshold_preview.get("pending_event_response_preview", []), "handled", "阈值 -2"), "card route threshold modifier appears in preview")
	map.card_controller.hand = ["death_transfer"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.resources["materials"] = 1
	map.card_controller.resources["sanity"] = 5
	map.card_controller.progress["source_clues"] = max(1, int(map.card_controller.progress.get("source_clues", 0)))
	map.card_controller.play_card(0)
	_assert(int(map.map_state.route_bonus_threshold_mods.get("death", 0)) == -1, "death transfer lowers death route bonus threshold")
	_assert(int(map.map_state.route_affinity.get("death", 0)) >= 2, "death transfer adds death route affinity")
	map.card_controller.pending_event = _event_from_pool(map, "graveyard_dead_tide", "grave_bell_rings")
	var death_route_preview: Dictionary = map._build_ui_snapshot()
	_assert(_response_bonus_status_contains(death_route_preview.get("pending_event_response_preview", []), "converted", "已解锁 死亡倾向"), "death transfer unlocks death route bonus preview")
	_assert(_response_bonus_status_contains(death_route_preview.get("pending_event_response_preview", []), "converted", "阈值 -1"), "death route bonus preview shows card threshold modifier")

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
	var reward_options: Array = reward_snapshot.get("stage_reward_options", [])
	_assert(reward_options.size() == 3, "reward choices are capped at three")
	_assert(_reward_summary_contains(reward_snapshot.get("stage_reward_options", []), "village_gratitude_followers", "信徒 +2"), "reward snapshot previews follower reward")
	_assert(_reward_summary_contains(reward_options, "village_medicine_cache", "药草束 +1"), "route-weighted reward includes life medicine cache")
	_assert(not _reward_exists(reward_options, "source_name_fragment"), "off-route reward is filtered out by three-choice cap")
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
	_assert(_response_bonus_status_contains(route_preview.get("pending_event_response_preview", []), "handled", "阈值 -1"), "secret route bonus preview shows threshold modifier")
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
	var old_well_reward_snapshot: Dictionary = map._build_ui_snapshot()
	var old_well_reward_options: Array = old_well_reward_snapshot.get("stage_reward_options", [])
	_assert(old_well_reward_options.size() == 3, "old well reward choices are capped at three")
	_assert(_reward_summary_contains(old_well_reward_options, "forbidden_name_insight", "污染牌：热病噩梦"), "forbidden reward previews pollution card cost")
	_assert(_reward_summary_contains(old_well_reward_options, "forbidden_name_insight", "隐秘倾向加成阈值 -1"), "forbidden reward previews secret threshold bonus")
	var fever_deck_before: int = map.card_controller.persistent_deck.count("fever_dream")
	var fever_discard_before: int = map.card_controller.discard.count("fever_dream")
	var secret_threshold_before_reward := int(map.map_state.route_bonus_threshold_mods.get("secret", 0))
	map._on_map_action_requested("claim_reward:forbidden_name_insight")
	_assert(map.card_controller.persistent_deck.count("fever_dream") == fever_deck_before + 1, "forbidden reward adds pollution card to persistent deck")
	_assert(map.card_controller.discard.count("fever_dream") == fever_discard_before + 1, "forbidden reward adds pollution card to discard")
	_assert(int(map.map_state.route_bonus_threshold_mods.get("secret", 0)) == secret_threshold_before_reward - 1, "forbidden reward lowers secret route threshold")
	_assert(map.map_state.stage_node_pending, "claiming forbidden reward opens next node choices")
	map._on_map_action_requested("choose_node:ruined_shrine_anchor")
	_assert(not map.map_state.stage_node_pending, "choosing node clears pending before ascension")
	map.map_state.global_resources["faith"] = max(6, int(map.map_state.global_resources.get("faith", 0)))
	map.map_state.global_resources["followers"] = max(4, int(map.map_state.global_resources.get("followers", 0)))
	map.map_state.global_resources["materials"] = max(2, int(map.map_state.global_resources.get("materials", 0)))
	map.map_state.action_points = 2
	var stored_clues_before_ascension := int(map.map_state.inventory.get("suspicious_clue", 0))
	map.map_state.inventory["suspicious_clue"] = 0
	var blocked_ascension_snapshot: Dictionary = map._build_ui_snapshot()
	var blocked_ascension: Dictionary = blocked_ascension_snapshot.get("ascension", {})
	_assert(not bool(blocked_ascension.get("ready", false)), "secret ascension requires route-specific clues")
	_assert(str(blocked_ascension.get("status", "")).contains("异常线索 0/2"), "secret ascension status shows clue requirement")
	map.map_state.inventory["suspicious_clue"] = max(2, stored_clues_before_ascension)
	var ascension_snapshot: Dictionary = map._build_ui_snapshot()
	var ascension: Dictionary = ascension_snapshot.get("ascension", {})
	_assert(bool(ascension.get("ready", false)), "first ascension is ready after route and resources")
	_assert(str(ascension.get("route", "")) == "secret", "first ascension chooses dominant secret route")
	_assert(str(ascension.get("unlock_card_id", "")) == "ascend_secret_veil", "first ascension previews route power card")
	_assert(_action_enabled(map._build_actions(), "perform_first_ascension"), "first ascension action is enabled")
	var max_life_before_ascension: int = map.map_state.max_life
	var faith_before_ascension := int(map.map_state.global_resources.get("faith", 0))
	var materials_before_ascension := int(map.map_state.global_resources.get("materials", 0))
	var clues_before_ascension := int(map.map_state.inventory.get("suspicious_clue", 0))
	var pressure_before_ascension: int = map.map_state.secrecy_pressure
	var secret_threshold_before_ascension := int(map.map_state.route_bonus_threshold_mods.get("secret", 0))
	var veil_deck_before: int = map.card_controller.persistent_deck.count("ascend_secret_veil")
	var veil_discard_before: int = map.card_controller.discard.count("ascend_secret_veil")
	map._on_map_action_requested("perform_first_ascension")
	_assert(map.map_state.ascension_tier == 1, "first ascension stores ascension tier")
	_assert(map.map_state.ascension_route == "secret", "first ascension stores route")
	_assert(map.map_state.max_life == max_life_before_ascension + 2, "first ascension increases max life")
	_assert(int(map.map_state.global_resources.get("faith", 0)) == faith_before_ascension - 6, "first ascension spends faith")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == materials_before_ascension - 2, "first ascension spends materials")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == clues_before_ascension - 1, "secret ascension spends one clue")
	_assert(map.map_state.secrecy_pressure == max(0, pressure_before_ascension - 2), "secret ascension lowers secrecy pressure")
	_assert(int(map.map_state.route_bonus_threshold_mods.get("secret", 0)) == secret_threshold_before_ascension - 1, "secret ascension lowers secret route threshold")
	_assert(map.card_controller.persistent_deck.count("ascend_secret_veil") == veil_deck_before + 1, "first ascension adds route power card to persistent deck")
	_assert(map.card_controller.discard.count("ascend_secret_veil") == veil_discard_before + 1, "first ascension adds route power card to discard")
	var ascended_snapshot: Dictionary = map._build_ui_snapshot()
	var ascended: Dictionary = ascended_snapshot.get("ascension", {})
	_assert(bool(ascended.get("complete", false)), "ascension snapshot marks completion")
	_assert(str(ascended.get("unlock_card_name", "")) == "无名帷幕", "ascension snapshot keeps unlocked card name")
	_assert(not _action_enabled(map._build_actions(), "perform_first_ascension"), "first ascension cannot be repeated")
	var power_upgrade: Dictionary = ascended.get("power_upgrade", {})
	_assert(not bool(power_upgrade.get("ready", false)), "route power upgrade needs post-ascension resources")
	_assert(str(power_upgrade.get("to_card_name", "")) == "无名帷幕·匿名", "route power upgrade previews upgraded card")
	map.map_state.global_resources["faith"] = 2
	map.map_state.global_resources["materials"] = 1
	map.map_state.action_points = 1
	var upgrade_ready_snapshot: Dictionary = map._build_ui_snapshot()
	var upgrade_ready: Dictionary = upgrade_ready_snapshot.get("ascension", {}).get("power_upgrade", {})
	_assert(bool(upgrade_ready.get("ready", false)), "route power upgrade is ready after resources")
	_assert(_action_enabled(map._build_actions(), "upgrade_route_power"), "route power upgrade action is enabled")
	var base_power_deck_before: int = map.card_controller.persistent_deck.count("ascend_secret_veil")
	var base_power_discard_before: int = map.card_controller.discard.count("ascend_secret_veil")
	var upgraded_power_deck_before: int = map.card_controller.persistent_deck.count("ascend_secret_veil_II")
	var upgraded_power_discard_before: int = map.card_controller.discard.count("ascend_secret_veil_II")
	map._on_map_action_requested("upgrade_route_power")
	_assert(map.map_state.power_card_upgraded, "route power upgrade marks state")
	_assert(map.map_state.action_points == 0, "route power upgrade spends action point")
	_assert(int(map.map_state.global_resources.get("faith", 0)) == 0, "route power upgrade spends faith")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == 0, "route power upgrade spends materials")
	_assert(map.card_controller.persistent_deck.count("ascend_secret_veil") == base_power_deck_before - 1, "route power upgrade removes base card from persistent deck")
	_assert(map.card_controller.discard.count("ascend_secret_veil") == base_power_discard_before - 1, "route power upgrade removes base card from discard")
	_assert(map.card_controller.persistent_deck.count("ascend_secret_veil_II") == upgraded_power_deck_before + 1, "route power upgrade adds upgraded card to persistent deck")
	_assert(map.card_controller.discard.count("ascend_secret_veil_II") == upgraded_power_discard_before + 1, "route power upgrade adds upgraded card to discard")
	_assert(not _action_enabled(map._build_actions(), "upgrade_route_power"), "route power upgrade cannot repeat")
	map.map_state.global_resources["faith"] = 2
	map.map_state.global_resources["materials"] = 1
	map.map_state.global_resources["followers"] = max(2, int(map.map_state.global_resources.get("followers", 0)))
	map.map_state.action_points = 2
	var cult_tile: RefCounted = map.tiles[map.map_state.player_coord]
	var cult_cells_before := int(map.map_state.global_resources.get("cult_cells", 0))
	var followers_before_cult := int(map.map_state.global_resources.get("followers", 0))
	var secret_before_cult := int(map.map_state.route_affinity.get("secret", 0))
	_assert(_action_enabled(map._build_actions(), "establish_cult_cell"), "cult cell action is enabled after ascension")
	map._on_map_action_requested("establish_cult_cell")
	_assert(map.map_state.action_points == 0, "cult cell spends action points")
	_assert(int(map.map_state.global_resources.get("faith", 0)) == 0, "cult cell spends faith")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == 0, "cult cell spends materials")
	_assert(int(map.map_state.global_resources.get("followers", 0)) == followers_before_cult - 2, "cult cell assigns followers")
	_assert(int(map.map_state.global_resources.get("cult_cells", 0)) == cult_cells_before + 1, "cult cell increases organization count")
	_assert(int(map.map_state.route_affinity.get("secret", 0)) == secret_before_cult + 1, "cult cell strengthens ascension route")
	_assert(cult_tile.has_building("cult_cell"), "cult cell adds building to current tile")
	_assert(cult_tile.owner == "隐秘教团", "cult cell claims current tile")
	var faith_before_cult_turn := int(map.map_state.global_resources.get("faith", 0))
	map._on_map_action_requested("end_turn")
	_assert(int(map.map_state.global_resources.get("faith", 0)) >= faith_before_cult_turn + 2, "cult cell produces faith on end turn")
	map.map_state.global_resources["followers"] = max(1, int(map.map_state.global_resources.get("followers", 0)))
	map.map_state.global_resources["faith"] = max(2, int(map.map_state.global_resources.get("faith", 0)))
	var apostles_before := int(map.map_state.global_resources.get("apostles", 0))
	var followers_before_apostle := int(map.map_state.global_resources.get("followers", 0))
	var faith_before_apostle := int(map.map_state.global_resources.get("faith", 0))
	var secret_before_apostle := int(map.map_state.route_affinity.get("secret", 0))
	_assert(_action_enabled(map._build_actions(), "appoint_apostle"), "appoint apostle is enabled with cult cell")
	map._on_map_action_requested("appoint_apostle")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before + 1, "appoint apostle increases apostles")
	_assert(int(map.map_state.global_resources.get("followers", 0)) == followers_before_apostle - 1, "appoint apostle consumes follower")
	_assert(int(map.map_state.global_resources.get("faith", 0)) == faith_before_apostle - 2, "appoint apostle spends faith")
	_assert(int(map.map_state.route_affinity.get("secret", 0)) == secret_before_apostle + 1, "appoint apostle strengthens ascension route")
	var materials_before_dispatch := int(map.map_state.global_resources.get("materials", 0))
	var clues_before_dispatch := int(map.map_state.inventory.get("suspicious_clue", 0))
	var card_clues_before_dispatch := int(map.card_controller.progress.get("source_clues", 0))
	var pressure_before_dispatch: int = map.map_state.secrecy_pressure
	var secret_before_dispatch := int(map.map_state.route_affinity.get("secret", 0))
	_assert(_action_enabled(map._build_actions(), "dispatch_apostle"), "dispatch apostle is enabled after appointment")
	map._on_map_action_requested("dispatch_apostle")
	_assert(int(map.map_state.global_resources.get("materials", 0)) == materials_before_dispatch + 1, "dispatch apostle gains material")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == clues_before_dispatch + 1, "dispatch apostle gains clue item")
	_assert(int(map.card_controller.progress.get("source_clues", 0)) == card_clues_before_dispatch + 1, "dispatch apostle advances card clue progress")
	_assert(map.map_state.secrecy_pressure == pressure_before_dispatch + 1, "dispatch apostle increases secrecy pressure")
	_assert(int(map.map_state.route_affinity.get("secret", 0)) == secret_before_dispatch + 1, "dispatch apostle strengthens route")
	map.map_state.ascension_route = "life"
	map.map_state.action_points = 1
	var herbs_before_life_dispatch := int(map.map_state.inventory.get("medicinal_herb_bundle", 0))
	var cure_before_life_dispatch := int(map.card_controller.progress.get("cure_progress", 0))
	var life_before_dispatch := int(map.map_state.route_affinity.get("life", 0))
	_assert(_action_enabled(map._build_actions(), "dispatch_apostle"), "life route apostle dispatch is enabled")
	map._on_map_action_requested("dispatch_apostle")
	_assert(int(map.map_state.inventory.get("medicinal_herb_bundle", 0)) == herbs_before_life_dispatch + 1, "life apostle brings herb")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_life_dispatch + 1, "life apostle advances cure progress")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == life_before_dispatch + 1, "life apostle strengthens life route")
	map.map_state.secrecy_pressure = 4
	map.map_state.action_points = 1
	var cure_before_conceal := int(map.card_controller.progress.get("cure_progress", 0))
	var life_before_conceal := int(map.map_state.route_affinity.get("life", 0))
	_assert(_action_enabled(map._build_actions(), "conceal_organization"), "conceal organization is enabled before hunt")
	map._on_map_action_requested("conceal_organization")
	_assert(map.map_state.secrecy_pressure == 2, "life organization conceal lowers pressure")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_conceal + 1, "life organization conceal advances cure")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == life_before_conceal + 1, "life organization conceal strengthens life route")
	map.map_state.crisis_active = false
	map.map_state.stage_resolved = false
	map.map_state.event_countdown = 8
	map.map_state.event_summary = map._format_stage_countdown_summary()
	map.map_state.secrecy_pressure = 5
	map.map_state.organization_hunt_pending = false
	var apostles_before_hunt := int(map.map_state.global_resources.get("apostles", 0))
	var hunt_tile: RefCounted = map.tiles[map.map_state.player_coord]
	map._on_map_action_requested("end_turn")
	_assert(map.map_state.organization_hunt_pending, "organization hunt creates a warning before raid")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before_hunt, "organization hunt warning does not remove an apostle immediately")
	map.card_controller.hand = ["hide_tracks"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.play_card(0)
	_assert(not map.map_state.organization_hunt_pending, "secrecy card clears hunt warning when pressure drops below threshold")
	_assert(map.map_state.secrecy_pressure < 5, "secrecy card lowers pressure below hunt threshold")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before_hunt, "secrecy card keeps apostles safe from hunt")
	map.map_state.secrecy_pressure = 5
	map.map_state.organization_hunt_pending = false
	var pressure_before_hunt: int = map.map_state.secrecy_pressure
	var cure_before_hunt_conceal := int(map.card_controller.progress.get("cure_progress", 0))
	var life_before_hunt_conceal := int(map.map_state.route_affinity.get("life", 0))
	map._on_map_action_requested("end_turn")
	_assert(_action_enabled(map._build_actions(), "resolve_organization_hunt_conceal"), "hunt warning enables conceal response")
	map._on_map_action_requested("resolve_organization_hunt_conceal")
	_assert(not map.map_state.organization_hunt_pending, "conceal response clears hunt warning")
	_assert(map.map_state.secrecy_pressure == max(0, pressure_before_hunt - 2), "conceal response lowers pressure")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before_hunt, "conceal response keeps apostles safe")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_hunt_conceal + 1, "hunt conceal uses route response effects")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == life_before_hunt_conceal + 1, "hunt conceal strengthens route")
	map.map_state.secrecy_pressure = 5
	map.map_state.organization_hunt_pending = false
	map.map_state.global_resources["apostles"] = max(1, int(map.map_state.global_resources.get("apostles", 0)))
	var apostles_before_divert := int(map.map_state.global_resources.get("apostles", 0))
	var clues_before_divert := int(map.map_state.inventory.get("suspicious_clue", 0))
	map._on_map_action_requested("end_turn")
	_assert(map.map_state.organization_hunt_pending, "organization hunt can warn again")
	_assert(_action_enabled(map._build_actions(), "resolve_organization_hunt_divert"), "hunt warning enables divert response with apostle")
	map._on_map_action_requested("resolve_organization_hunt_divert")
	_assert(not map.map_state.organization_hunt_pending, "divert response clears hunt warning")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before_divert - 1, "divert response spends an apostle")
	_assert(map.map_state.secrecy_pressure == 1, "divert response greatly lowers pressure")
	_assert(int(map.map_state.inventory.get("suspicious_clue", 0)) == clues_before_divert + 1, "divert response gains reverse clue")
	map.map_state.secrecy_pressure = 5
	map.map_state.organization_hunt_pending = false
	map.map_state.global_resources["apostles"] = max(1, int(map.map_state.global_resources.get("apostles", 0)))
	var apostles_before_ignore := int(map.map_state.global_resources.get("apostles", 0))
	map._on_map_action_requested("end_turn")
	_assert(_action_enabled(map._build_actions(), "resolve_organization_hunt_ignore"), "hunt warning enables ignore response")
	map._on_map_action_requested("resolve_organization_hunt_ignore")
	_assert(not map.map_state.organization_hunt_pending, "ignore response clears hunt warning")
	_assert(int(map.map_state.global_resources.get("apostles", 0)) == apostles_before_ignore - 1, "ignore response applies raid loss")
	_assert(map.map_state.secrecy_pressure == 3, "ignore response applies raid pressure relief")
	_assert(hunt_tile.has_state("enemy_attention"), "ignore response marks enemy attention")
	var pressure_before_card_attention_cleanup: int = map.map_state.secrecy_pressure
	map.card_controller.hand = ["hide_tracks"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.play_card(0)
	_assert(not hunt_tile.has_state("enemy_attention"), "secrecy card removes enemy attention from current tile")
	_assert(map.map_state.secrecy_pressure < pressure_before_card_attention_cleanup, "secrecy card lowers pressure while cleaning attention")
	hunt_tile.add_state("enemy_attention")
	var cure_before_life_attention_card := int(map.card_controller.progress.get("cure_progress", 0))
	var life_before_attention_card := int(map.map_state.route_affinity.get("life", 0))
	map.card_controller.hand = ["ascend_life_benediction"]
	map.card_controller.resources["action_points"] = 3
	map.card_controller.resources["will"] = 1
	map.card_controller.play_card(0)
	_assert(not hunt_tile.has_state("enemy_attention"), "life route power also removes enemy attention")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_life_attention_card + 2, "life route power still advances cure")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == life_before_attention_card + 1, "life route power still strengthens route")
	hunt_tile.add_state("enemy_attention")
	var attention_escape_coord := _find_passable_neighbor(map, map.map_state.player_coord)
	map._select_tile(attention_escape_coord)
	map.map_state.action_points = 1
	var watched_move: Dictionary = map._evaluate_action("move")
	_assert(int(watched_move.get("cost", 0)) == 2, "enemy attention makes leaving cost 2")
	_assert(not bool(watched_move.get("enabled", true)), "enemy attention blocks leaving with only 1 action point")
	map.map_state.action_points = 3
	map._select_tile(map.map_state.player_coord)
	var pressure_before_attention_turn: int = map.map_state.secrecy_pressure
	map._on_map_action_requested("end_turn")
	_assert(map.map_state.secrecy_pressure == pressure_before_attention_turn + 1, "enemy attention raises pressure when ending turn there")
	_assert(_action_enabled(map._build_actions(), "clear_enemy_attention"), "enemy attention enables cleanup action")
	_assert(_action_summary_contains(map._build_actions(), "clear_enemy_attention", "治疗 +1"), "cleanup preview shows life route reward")
	_assert(_action_summary_contains(map._build_actions(), "clear_enemy_attention", "生命倾向 +1"), "cleanup preview shows route affinity reward")
	var cure_before_attention_cleanup := int(map.card_controller.progress.get("cure_progress", 0))
	var life_before_attention_cleanup := int(map.map_state.route_affinity.get("life", 0))
	map._on_map_action_requested("clear_enemy_attention")
	_assert(not hunt_tile.has_state("enemy_attention"), "cleanup removes enemy attention")
	_assert(map.map_state.secrecy_pressure == pressure_before_attention_turn, "cleanup lowers pressure after attention turn")
	_assert(int(map.card_controller.progress.get("cure_progress", 0)) == cure_before_attention_cleanup + 1, "life cleanup advances cure")
	_assert(int(map.map_state.route_affinity.get("life", 0)) == life_before_attention_cleanup + 1, "life cleanup strengthens route")

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


func _action_summary_contains(actions: Array, action_id: String, text: String) -> bool:
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY and str(action.get("id", "")) == action_id:
			return str(action.get("summary", "")).contains(text)
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


func _reward_exists(entries: Array, reward_id: String) -> bool:
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == reward_id:
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
