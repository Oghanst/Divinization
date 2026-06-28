extends Node


func _ready() -> void:
	var controller = CardRunController.new()
	add_child(controller)
	controller.start_demo("life_sprout_village")
	assert(str(controller.current_encounter.get("id", "")) == "life_sprout_village", "Life sprout encounter should load.")
	assert(int(controller.resources.get("life", 0)) == 24, "Life sprout encounter should start with 24 life.")
	assert(controller.phase == "preparation", "Life sprout encounter starts in preparation.")
	controller.apply_external_deltas({}, {"source_clues": 3})
	assert(controller.phase == "boss", "Source clues should open boss phase.")
	controller.boss_state["life"] = 4
	controller.boss_state["lesion_shield"] = 0
	controller.hand = ["vine_thorn"]
	controller.resources["action_points"] = 3
	var deck_before_reward: int = controller.persistent_deck.size()
	controller.play_card(0)
	assert(controller.is_finished, "Life sprout boss should finish when boss life reaches zero.")
	assert(str(controller.final_result.get("id", "")) == "kill", "Life sprout boss kill outcome should resolve.")
	assert(controller.pending_reward_cards.size() == 3, "Life sprout boss should offer three reward cards.")
	assert(controller.choose_reward_card(0), "Reward card choice should be claimable.")
	assert(controller.pending_reward_cards.is_empty(), "Reward card choice should clear pending choices.")
	assert(controller.persistent_deck.size() == deck_before_reward + 1, "Reward card choice should add one card to the persistent deck.")

	controller.persistent_deck.clear()
	controller.start_demo()
	var guard := 0
	while not controller.is_finished and guard < 20:
		while int(controller.resources.get("action_points", 0)) > 0 and controller.hand.size() > 0:
			var played := false
			for i in range(controller.hand.size()):
				if controller.can_play_card(i):
					controller.play_card(i)
					played = true
					break
			if not played:
				break
		controller.end_turn()
		guard += 1
	assert(controller.is_finished, "Card demo should finish within guard limit.")
	print("CARD_DEMO_SMOKE_OK " + str(controller.final_result.get("id", "")))
	get_tree().quit()
