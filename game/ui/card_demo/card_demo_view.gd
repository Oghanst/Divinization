extends Control
class_name CardDemoView

@export var controller_path: NodePath

var controller: CardRunController
var title_label: Label
var resource_label: Label
var progress_label: Label
var final_label: Label
var hand_box: VBoxContainer
var log_label: RichTextLabel
var end_turn_button: Button
var restart_button: Button


func _ready() -> void:
	_resolve_controller()
	_build_view()
	controller.state_changed.connect(_on_state_changed)
	controller.start_demo()


func _resolve_controller() -> void:
	if controller_path != NodePath(""):
		controller = get_node(controller_path)
	else:
		controller = CardRunController.new()
		controller.name = "CardRunController"
		add_child(controller)


func _build_view() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	add_child(root)

	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(420, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_panel)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_panel.add_child(title_label)

	resource_label = Label.new()
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_panel.add_child(resource_label)

	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_panel.add_child(progress_label)

	final_label = Label.new()
	final_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_panel.add_child(final_label)

	restart_button = Button.new()
	restart_button.text = "重新开始病村"
	restart_button.pressed.connect(func(): controller.start_demo())
	left_panel.add_child(restart_button)

	var center_panel = VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center_panel)

	var hand_title = Label.new()
	hand_title.text = "手牌"
	center_panel.add_child(hand_title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scroll)

	hand_box = VBoxContainer.new()
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hand_box)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.pressed.connect(func(): controller.end_turn())
	center_panel.add_child(end_turn_button)

	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(520, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var log_title = Label.new()
	log_title.text = "日志"
	right_panel.add_child(log_title)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(log_label)


func _on_state_changed(snapshot: Dictionary) -> void:
	_update_summary(snapshot)
	_update_hand(snapshot)
	_update_log(snapshot)


func _update_summary(snapshot: Dictionary) -> void:
	var encounter = snapshot.get("encounter", {})
	title_label.text = "%s\n%s\n最终事件：%s | 当前回合：%s | 倒计时：%s" % [
		str(encounter.get("name", "")),
		str(encounter.get("description", "")),
		str(encounter.get("final_event", "")),
		str(snapshot.get("turn", 0)),
		str(snapshot.get("countdown", 0))
	]

	var resources = snapshot.get("resources", {})
	resource_label.text = "资源\n行动点：%s | 信仰：%s | 信徒：%s | 灵性：%s | 材料：%s | 暴露：%s | 理智：%s\n牌库：%s | 弃牌：%s" % [
		str(resources.get("action_points", 0)),
		str(resources.get("faith", 0)),
		str(resources.get("followers", 0)),
		str(resources.get("will", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("exposure", 0)),
		str(resources.get("sanity", 0)),
		str(snapshot.get("deck_count", 0)),
		str(snapshot.get("discard_count", 0))
	]

	var progress = snapshot.get("progress", {})
	progress_label.text = "关卡进度\n治疗：%s | 病源线索：%s | 锚点：%s | 信任：%s | 见证：%s\n感染：%s | 怀疑：%s\n生命倾向：%s | 秘仪倾向：%s | 死亡倾向：%s" % [
		str(progress.get("cure_progress", 0)),
		str(progress.get("source_clues", 0)),
		str(progress.get("anchor_progress", 0)),
		str(progress.get("public_trust", 0)),
		str(progress.get("witness", 0)),
		str(progress.get("infection", 0)),
		str(progress.get("suspicion", 0)),
		str(progress.get("life_route", 0)),
		str(progress.get("secret_route", 0)),
		str(progress.get("death_route", 0))
	]

	if bool(snapshot.get("is_finished", false)):
		var result = snapshot.get("final_result", {})
		final_label.text = "关卡结局：%s\n%s" % [
			str(result.get("name", "")),
			str(result.get("text", ""))
		]
		end_turn_button.disabled = true
	else:
		final_label.text = ""
		end_turn_button.disabled = false


func _update_hand(snapshot: Dictionary) -> void:
	for child in hand_box.get_children():
		child.queue_free()
	var cards: Array = snapshot.get("hand", [])
	for card in cards:
		var button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not bool(card.get("can_play", false)) or bool(snapshot.get("is_finished", false))
		button.text = "[%s] %s  费用:%s\n%s" % [
			str(card.get("type", "")),
			str(card.get("name", "")),
			str(card.get("cost", 0)),
			str(card.get("text", ""))
		]
		var index = int(card.get("hand_index", 0))
		button.pressed.connect(func(): controller.play_card(index))
		hand_box.add_child(button)


func _update_log(snapshot: Dictionary) -> void:
	log_label.clear()
	for message in snapshot.get("log", []):
		log_label.append_text(str(message) + "\n")
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))
