extends Node


func _ready() -> void:
	var controller = CardRunController.new()
	add_child(controller)
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
