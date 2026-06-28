extends Control
class_name CardDemoView

@export var controller_path: NodePath

const BG_COLOR := Color(0.07, 0.065, 0.055, 1.0)
const PANEL_COLOR := Color(0.14, 0.13, 0.11, 1.0)
const CARD_COLOR := Color(0.20, 0.18, 0.14, 1.0)
const CARD_DISABLED_COLOR := Color(0.13, 0.13, 0.13, 1.0)
const ACCENT_COLOR := Color(0.78, 0.58, 0.28, 1.0)

var controller: CardRunController
var title_label: Label
var resource_label: Label
var progress_label: Label
var final_label: Label
var hand_grid: GridContainer
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
	_fill_rect(self)
	var background = ColorRect.new()
	background.color = BG_COLOR
	_fill_rect(background)
	add_child(background)

	var margin = MarginContainer.new()
	_fill_rect(margin)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root = HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var left_panel = _make_panel(Vector2(360, 0))
	root.add_child(left_panel)
	var left_content = VBoxContainer.new()
	left_content.add_theme_constant_override("separation", 14)
	left_panel.add_child(left_content)

	title_label = _make_label(18)
	left_content.add_child(title_label)

	resource_label = _make_label(16)
	left_content.add_child(_with_title("资源", resource_label))

	progress_label = _make_label(16)
	left_content.add_child(_with_title("关卡进度", progress_label))

	final_label = _make_label(16)
	left_content.add_child(final_label)

	var left_spacer = Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_content.add_child(left_spacer)

	restart_button = Button.new()
	restart_button.text = "重新开始病村"
	restart_button.custom_minimum_size = Vector2(0, 42)
	restart_button.pressed.connect(func(): controller.start_demo())
	left_content.add_child(restart_button)

	var center_panel = _make_panel(Vector2(560, 0))
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(center_panel)
	var center_content = VBoxContainer.new()
	center_content.add_theme_constant_override("separation", 14)
	center_panel.add_child(center_content)

	var hand_header = HBoxContainer.new()
	center_content.add_child(hand_header)
	var hand_title = _make_section_title("手牌")
	hand_header.add_child(hand_title)
	var hand_spacer = Control.new()
	hand_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_header.add_child(hand_spacer)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(112, 38)
	end_turn_button.pressed.connect(func(): controller.end_turn())
	hand_header.add_child(end_turn_button)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)

	hand_grid = GridContainer.new()
	hand_grid.columns = 2
	hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_grid.add_theme_constant_override("h_separation", 12)
	hand_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(hand_grid)

	var right_panel = _make_panel(Vector2(360, 0))
	root.add_child(right_panel)
	var right_content = VBoxContainer.new()
	right_content.add_theme_constant_override("separation", 12)
	right_panel.add_child(right_content)

	right_content.add_child(_make_section_title("日志"))
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 15)
	right_content.add_child(log_label)


func _make_panel(min_size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.33, 0.28, 0.20, 1.0)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _fill_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _make_label(font_size: int) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.91, 0.87, 0.78, 1.0))
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_section_title(text: String) -> Label:
	var label = _make_label(18)
	label.text = text
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	return label


func _with_title(title: String, content: Control) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_make_section_title(title))
	box.add_child(content)
	return box


func _on_state_changed(snapshot: Dictionary) -> void:
	_update_summary(snapshot)
	_update_hand(snapshot)
	_update_log(snapshot)


func _update_summary(snapshot: Dictionary) -> void:
	var encounter = snapshot.get("encounter", {})
	title_label.text = "%s\n%s\n\n最终事件：%s\n当前回合：%s    倒计时：%s" % [
		str(encounter.get("name", "")),
		str(encounter.get("description", "")),
		str(encounter.get("final_event", "")),
		str(snapshot.get("turn", 0)),
		str(snapshot.get("countdown", 0))
	]

	var resources = snapshot.get("resources", {})
	resource_label.text = "行动点 %s/%s\n信仰 %s    信徒 %s\n灵性 %s    材料 %s\n暴露 %s    理智 %s\n牌库 %s    弃牌 %s" % [
		str(resources.get("action_points", 0)),
		str(encounter.get("action_points", 3)),
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
	progress_label.text = "治疗 %s    病源线索 %s\n锚点 %s    信任 %s    见证 %s\n感染 %s    怀疑 %s\n生命 %s    秘仪 %s    死亡 %s" % [
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
	for child in hand_grid.get_children():
		child.queue_free()
	var reward_cards: Array = snapshot.get("pending_reward_cards", [])
	if not reward_cards.is_empty():
		for card in reward_cards:
			if typeof(card) == TYPE_DICTIONARY:
				hand_grid.add_child(_make_reward_card_button(card))
		return
	var cards: Array = snapshot.get("hand", [])
	for card in cards:
		hand_grid.add_child(_make_card_button(card, bool(snapshot.get("is_finished", false))))


func _make_reward_card_button(card: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(250, 178)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "奖励牌三选一\n%s\n[%s]  费用 %s\n\n%s" % [
		str(card.get("name", "")),
		str(card.get("type", "")),
		str(card.get("cost", 0)),
		str(card.get("text", ""))
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var normal = StyleBoxFlat.new()
	normal.bg_color = CARD_COLOR
	normal.border_color = ACCENT_COLOR
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 14
	normal.content_margin_top = 12
	normal.content_margin_right = 14
	normal.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 1.0))
	var choice_index = int(card.get("reward_index", -1))
	button.pressed.connect(func(): controller.choose_reward_card(choice_index))
	return button


func _make_card_button(card: Dictionary, encounter_finished: bool) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(250, 178)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not bool(card.get("can_play", false)) or encounter_finished
	button.text = "%s\n[%s]  费用 %s\n\n%s" % [
		str(card.get("name", "")),
		str(card.get("type", "")),
		str(card.get("cost", 0)),
		str(card.get("text", ""))
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var normal = StyleBoxFlat.new()
	normal.bg_color = CARD_COLOR if not button.disabled else CARD_DISABLED_COLOR
	normal.border_color = ACCENT_COLOR if not button.disabled else Color(0.28, 0.28, 0.28, 1.0)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 14
	normal.content_margin_top = 12
	normal.content_margin_right = 14
	normal.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.56, 0.52, 1.0))
	var index = int(card.get("hand_index", 0))
	button.pressed.connect(func(): controller.play_card(index))
	return button


func _update_log(snapshot: Dictionary) -> void:
	log_label.clear()
	for message in snapshot.get("log", []):
		log_label.append_text(str(message) + "\n\n")
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))
