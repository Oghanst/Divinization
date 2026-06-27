extends Control
class_name MapCardHandLayer

signal end_turn_requested
signal map_action_requested(action_id: String)

const PANEL_COLOR := Color(0.10, 0.095, 0.08, 0.94)
const CARD_COLOR := Color(0.18, 0.15, 0.11, 0.98)
const CARD_DISABLED_COLOR := Color(0.11, 0.105, 0.10, 0.92)
const ACCENT_COLOR := Color(0.82, 0.62, 0.30, 1.0)
const TEXT_COLOR := Color(0.92, 0.87, 0.76, 1.0)
const CARD_TEXT_COLOR := Color(0.18, 0.12, 0.07, 1.0)
const CARD_FRAME_PATH := "res://assets/generated/card_demo/card_frame_front.png"
const CARD_FRAME_BASE_SIZE := Vector2(420, 588)
const CARD_SIZE := Vector2(196, 274)
const CARD_PREVIEW_SIZE := Vector2(260, 364)
const BOTTOM_PANEL_HEIGHT := 430.0
const ACTION_DOCK_WIDTH := 430.0
const CARD_LOG_WIDTH := 520.0
const INVENTORY_SLOT_COUNT := 12
const INVENTORY_POPUP_SIZE := Vector2(560, 360)
const INVENTORY_SLOT_SIZE := Vector2(116, 86)
const TYPE_COLORS := {
	"行动": Color(0.55, 0.43, 0.25, 1.0),
	"神迹": Color(0.72, 0.58, 0.26, 1.0),
	"秘仪": Color(0.34, 0.28, 0.52, 1.0),
	"探索": Color(0.24, 0.42, 0.38, 1.0),
	"仪式": Color(0.58, 0.32, 0.22, 1.0),
	"死亡": Color(0.30, 0.25, 0.31, 1.0),
	"污染": Color(0.55, 0.16, 0.14, 1.0),
}

var controller: CardRunController
var title_label: Label
var resource_label: Label
var progress_label: Label
var map_status_label: Label
var inventory_button: Button
var inventory_popup: PanelContainer
var inventory_grid: GridContainer
var map_actions_grid: GridContainer
var map_log_label: RichTextLabel
var hand_box: HBoxContainer
var log_label: RichTextLabel
var end_turn_button: Button
var restart_button: Button
var play_hint_label: Label
var hand_panel: PanelContainer
var art_cache: Dictionary = {}
var card_frame_texture: Texture2D
var dragging_card: Dictionary = {}
var dragging_card_index := -1
var drag_preview: Control
var drag_start_position := Vector2.ZERO
var is_dragging_card := false
var map_snapshot: Dictionary = {}
var ui_scale := 1.0
var is_inventory_open := false


func bind_controller(card_controller: CardRunController) -> void:
	controller = card_controller
	if not controller.state_changed.is_connected(_on_state_changed):
		controller.state_changed.connect(_on_state_changed)
	if is_inside_tree():
		_on_state_changed(controller.get_snapshot())


func update_map_snapshot(snapshot: Dictionary) -> void:
	map_snapshot = snapshot.duplicate(true)
	if map_status_label != null:
		_update_map_actions()


func _ready() -> void:
	ui_scale = _calculate_ui_scale()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_view()


func _input(event: InputEvent) -> void:
	if not is_dragging_card:
		return
	if event is InputEventMouseMotion:
		_update_card_drag(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_card_drag(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_update_card_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_card_drag(event.position)
		get_viewport().set_input_as_handled()


func _build_view() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 0
	margin.offset_top = 0
	margin.offset_right = 0
	margin.offset_bottom = 0
	margin.add_theme_constant_override("margin_left", _scaled_int(28))
	margin.add_theme_constant_override("margin_top", _scaled_int(28))
	margin.add_theme_constant_override("margin_right", _scaled_int(28))
	margin.add_theme_constant_override("margin_bottom", _scaled_int(28))
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(root)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	play_hint_label = _make_label(30)
	play_hint_label.text = "释放以打出"
	play_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_hint_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
	play_hint_label.visible = false
	root.add_child(play_hint_label)

	hand_panel = PanelContainer.new()
	hand_panel.custom_minimum_size = Vector2(0, _scaled(BOTTOM_PANEL_HEIGHT))
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_panel.clip_contents = true
	hand_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(hand_panel)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", _scaled_int(12))
	hand_panel.add_child(row)

	var action_dock := VBoxContainer.new()
	action_dock.custom_minimum_size = Vector2(_scaled(ACTION_DOCK_WIDTH), 0)
	action_dock.add_theme_constant_override("separation", _scaled_int(7))
	row.add_child(action_dock)

	var action_header := HBoxContainer.new()
	action_header.add_theme_constant_override("separation", _scaled_int(8))
	action_dock.add_child(action_header)

	var action_title := _make_label(20)
	action_title.text = "普通行动"
	action_title.add_theme_color_override("font_color", ACCENT_COLOR)
	action_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_header.add_child(action_title)

	inventory_button = Button.new()
	inventory_button.text = "背包 0/%s" % str(INVENTORY_SLOT_COUNT)
	inventory_button.custom_minimum_size = Vector2(_scaled(132), _scaled(40))
	inventory_button.add_theme_font_size_override("font_size", _scaled_int(17))
	inventory_button.pressed.connect(_toggle_inventory_popup)
	action_header.add_child(inventory_button)

	map_status_label = _make_label(17)
	action_dock.add_child(map_status_label)

	map_actions_grid = GridContainer.new()
	map_actions_grid.columns = 4
	map_actions_grid.add_theme_constant_override("h_separation", _scaled_int(6))
	map_actions_grid.add_theme_constant_override("v_separation", _scaled_int(6))
	action_dock.add_child(map_actions_grid)

	map_log_label = RichTextLabel.new()
	map_log_label.bbcode_enabled = false
	map_log_label.fit_content = false
	map_log_label.scroll_active = true
	map_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_log_label.add_theme_font_size_override("normal_font_size", _scaled_int(15))
	map_log_label.add_theme_color_override("default_color", Color(0.72, 0.67, 0.58, 1.0))
	action_dock.add_child(map_log_label)

	var card_zone := VBoxContainer.new()
	card_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_zone.add_theme_constant_override("separation", _scaled_int(6))
	row.add_child(card_zone)

	var card_header := HBoxContainer.new()
	card_header.custom_minimum_size = Vector2(0, _scaled(28))
	card_header.add_theme_constant_override("separation", _scaled_int(12))
	card_zone.add_child(card_header)

	title_label = _make_label(19)
	_set_single_line_label(title_label)
	title_label.custom_minimum_size = Vector2(0, _scaled(26))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_header.add_child(title_label)

	resource_label = _make_label(16)
	_set_single_line_label(resource_label)
	resource_label.custom_minimum_size = Vector2(0, _scaled(26))
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_header.add_child(resource_label)

	progress_label = _make_label(16)
	_set_single_line_label(progress_label)
	progress_label.custom_minimum_size = Vector2(0, _scaled(26))
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_header.add_child(progress_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_zone.add_child(scroll)

	hand_box = HBoxContainer.new()
	hand_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation", _scaled_int(8))
	scroll.add_child(hand_box)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(_scaled(CARD_LOG_WIDTH), 0)
	side.add_theme_constant_override("separation", _scaled_int(6))
	row.add_child(side)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _scaled_int(8))
	side.add_child(header)
	var log_title := _make_label(19)
	log_title.text = "关卡日志"
	log_title.add_theme_color_override("font_color", ACCENT_COLOR)
	header.add_child(log_title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(_scaled(124), _scaled(42))
	end_turn_button.add_theme_font_size_override("font_size", _scaled_int(17))
	end_turn_button.pressed.connect(func(): end_turn_requested.emit())
	header.add_child(end_turn_button)

	restart_button = Button.new()
	restart_button.text = "重开关卡"
	restart_button.custom_minimum_size = Vector2(_scaled(114), _scaled(42))
	restart_button.add_theme_font_size_override("font_size", _scaled_int(17))
	restart_button.pressed.connect(func(): controller.start_demo())
	header.add_child(restart_button)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", _scaled_int(16))
	log_label.add_theme_color_override("default_color", TEXT_COLOR)
	side.add_child(log_label)

	_build_inventory_popup()
	_update_map_actions()


func _on_state_changed(snapshot: Dictionary) -> void:
	_update_summary(snapshot)
	_update_hand(snapshot)
	_update_log(snapshot)


func _update_summary(snapshot: Dictionary) -> void:
	var encounter: Dictionary = snapshot.get("encounter", {})
	title_label.text = "%s  |  %s 回合后：%s" % [
		str(encounter.get("name", "")),
		str(snapshot.get("countdown", 0)),
		str(encounter.get("final_event", "")),
	]
	var resources: Dictionary = snapshot.get("resources", {})
	resource_label.text = "牌 AP %s/%s  信仰 %s  灵性 %s  材料 %s" % [
		str(resources.get("action_points", 0)),
		str(encounter.get("action_points", 3)),
		str(resources.get("faith", 0)),
		str(resources.get("will", 0)),
		str(resources.get("materials", 0)),
	]
	var progress: Dictionary = snapshot.get("progress", {})
	progress_label.text = "治疗 %s  线索 %s  锚点 %s  感染 %s  怀疑 %s" % [
		str(progress.get("cure_progress", 0)),
		str(progress.get("source_clues", 0)),
		str(progress.get("anchor_progress", 0)),
		str(progress.get("infection", 0)),
		str(progress.get("suspicion", 0)),
	]
	end_turn_button.disabled = bool(snapshot.get("is_finished", false))


func _update_map_actions() -> void:
	if map_status_label == null or map_actions_grid == null:
		return
	var resources: Dictionary = map_snapshot.get("global_resources", {})
	var stage_text := "最终事件处理中" if bool(map_snapshot.get("crisis_active", false)) else str(map_snapshot.get("event_summary", ""))
	var pending_event: Dictionary = map_snapshot.get("pending_event", {})
	if not pending_event.is_empty():
		var options: Array[String] = ["放任"]
		if not pending_event.get("handled_effects", []).is_empty():
			options.append("处理")
		if not pending_event.get("converted_effects", []).is_empty():
			options.append("转化")
		if not pending_event.get("exploited_effects", []).is_empty():
			options.append("利用")
		stage_text += "\n预兆：%s（%s）" % [str(pending_event.get("name", "")), " / ".join(options)]
	map_status_label.text = "地图 AP %s/%s  生命 %s/%s\n信仰 %s  材料 %s  信徒 %s\n位置 %s\n%s" % [
		str(map_snapshot.get("action_points", 0)),
		str(map_snapshot.get("max_action_points", 0)),
		str(map_snapshot.get("life", 0)),
		str(map_snapshot.get("max_life", 0)),
		str(resources.get("faith", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("followers", 0)),
		str(map_snapshot.get("player_coord", Vector2i.ZERO)),
		stage_text,
	]
	_refresh_inventory_popup()
	for child in map_actions_grid.get_children():
		map_actions_grid.remove_child(child)
		child.queue_free()
	for action in map_snapshot.get("actions", []):
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_id := str(action.get("id", ""))
		if action_id == "end_turn":
			continue
		map_actions_grid.add_child(_make_map_action_button(action, action_id))
	_update_map_log()


func _build_inventory_popup() -> void:
	inventory_popup = PanelContainer.new()
	inventory_popup.name = "InventoryPopup"
	inventory_popup.visible = is_inventory_open
	inventory_popup.custom_minimum_size = INVENTORY_POPUP_SIZE * ui_scale
	inventory_popup.size = INVENTORY_POPUP_SIZE * ui_scale
	inventory_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_popup.z_index = 20
	inventory_popup.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(inventory_popup)
	_position_inventory_popup()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _scaled_int(12))
	inventory_popup.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _scaled_int(10))
	box.add_child(header)

	var title := _make_label(20)
	title.text = "背包"
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(_scaled(82), _scaled(36))
	close_button.add_theme_font_size_override("font_size", _scaled_int(16))
	close_button.pressed.connect(_close_inventory_popup)
	header.add_child(close_button)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.add_theme_constant_override("h_separation", _scaled_int(10))
	inventory_grid.add_theme_constant_override("v_separation", _scaled_int(10))
	box.add_child(inventory_grid)
	_refresh_inventory_popup()


func _toggle_inventory_popup() -> void:
	is_inventory_open = not is_inventory_open
	if inventory_popup != null:
		inventory_popup.visible = is_inventory_open
		_position_inventory_popup()


func _close_inventory_popup() -> void:
	is_inventory_open = false
	if inventory_popup != null:
		inventory_popup.visible = false


func _position_inventory_popup() -> void:
	if inventory_popup == null:
		return
	var viewport_size := get_viewport_rect().size
	var popup_size := INVENTORY_POPUP_SIZE * ui_scale
	inventory_popup.size = popup_size
	var x := viewport_size.x - _scaled(28) - popup_size.x
	var y := viewport_size.y - _scaled(28) - _scaled(BOTTOM_PANEL_HEIGHT) - popup_size.y - _scaled(18)
	inventory_popup.position = Vector2(max(_scaled(28), x), max(_scaled(76), y))


func _refresh_inventory_popup() -> void:
	var entries: Array = map_snapshot.get("inventory", [])
	if inventory_button != null:
		inventory_button.text = "背包 %s/%s" % [str(min(entries.size(), INVENTORY_SLOT_COUNT)), str(INVENTORY_SLOT_COUNT)]
	if inventory_popup != null:
		inventory_popup.visible = is_inventory_open
		_position_inventory_popup()
	if inventory_grid == null:
		return
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	for i in range(INVENTORY_SLOT_COUNT):
		var entry: Dictionary = {}
		if i < entries.size() and typeof(entries[i]) == TYPE_DICTIONARY:
			entry = entries[i]
		inventory_grid.add_child(_make_inventory_slot(entry))


func _make_inventory_slot(entry: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = INVENTORY_SLOT_SIZE * ui_scale
	slot.add_theme_stylebox_override("panel", _make_inventory_slot_style(not entry.is_empty()))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", _scaled_int(4))
	slot.add_child(box)

	var name_label := _make_label(15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.text = "空"
	if not entry.is_empty():
		name_label.text = str(entry.get("name", entry.get("id", "")))
	box.add_child(name_label)

	var quantity_label := _make_label(16)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", ACCENT_COLOR)
	quantity_label.text = ""
	if not entry.is_empty():
		quantity_label.text = "x%s" % str(entry.get("quantity", 0))
	box.add_child(quantity_label)
	return slot


func _make_map_action_button(action: Dictionary, action_id: String) -> Button:
	var button := Button.new()
	button.text = str(action.get("label", action_id))
	button.custom_minimum_size = Vector2(_scaled(96), _scaled(40))
	button.add_theme_font_size_override("font_size", _scaled_int(16))
	button.disabled = not bool(action.get("enabled", false))
	button.tooltip_text = str(action.get("reason", ""))
	button.pressed.connect(func(): map_action_requested.emit(action_id))
	return button


func _update_map_log() -> void:
	if map_log_label == null:
		return
	map_log_label.clear()
	var messages: Array = map_snapshot.get("log", [])
	var start: int = max(0, messages.size() - 4)
	for i in range(start, messages.size()):
		map_log_label.append_text(str(messages[i]) + "\n")
	map_log_label.scroll_to_line(max(0, map_log_label.get_line_count() - 1))


func _update_hand(snapshot: Dictionary) -> void:
	for child in hand_box.get_children():
		child.queue_free()
	var cards: Array = snapshot.get("hand", [])
	for card in cards:
		hand_box.add_child(_make_card_view(card, bool(snapshot.get("is_finished", false))))


func _make_card_view(card: Dictionary, encounter_finished: bool, preview: bool = false) -> Control:
	var disabled := not bool(card.get("can_play", false)) or encounter_finished
	var base_card_size := CARD_SIZE if not preview else CARD_PREVIEW_SIZE
	var card_size := base_card_size * ui_scale
	var card_root := Control.new()
	card_root.custom_minimum_size = card_size
	card_root.size = card_size
	card_root.clip_contents = true
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	card_root.modulate = Color(1, 1, 1, 0.56) if disabled else Color.WHITE

	var frame := TextureRect.new()
	frame.position = Vector2.ZERO
	frame.size = card_size
	frame.texture = _load_card_frame()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(frame)

	var scale_factor := card_size.x / CARD_FRAME_BASE_SIZE.x

	var cost_badge := Label.new()
	cost_badge.position = Vector2(20, 52) * scale_factor
	cost_badge.size = Vector2(58, 58) * scale_factor
	cost_badge.text = str(card.get("cost", 0))
	cost_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_theme_font_size_override("font_size", int(40 * scale_factor))
	cost_badge.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04, 1.0))
	cost_badge.add_theme_stylebox_override("normal", _make_badge_style())
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(cost_badge)

	_add_clipped_label(
		card_root,
		Rect2(Vector2(100, 34) * scale_factor, Vector2(210, 42) * scale_factor),
		str(card.get("name", "")),
		int((34 if not preview else 36) * scale_factor),
		Color(0.98, 0.91, 0.72, 1.0),
		false
	)

	_add_clipped_label(
		card_root,
		Rect2(Vector2(112, 76) * scale_factor, Vector2(180, 30) * scale_factor),
		str(card.get("type", "")),
		int(24 * scale_factor),
		TYPE_COLORS.get(str(card.get("type", "")), ACCENT_COLOR).lightened(0.32),
		false
	)

	var art := TextureRect.new()
	art.position = Vector2(68, 126) * scale_factor
	art.size = Vector2(284, 214) * scale_factor
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _load_card_art(str(card.get("art", "")))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(art)

	_add_clipped_label(
		card_root,
		Rect2(Vector2(74, 388) * scale_factor, Vector2(272, 104) * scale_factor),
		str(card.get("text", "")),
		int((27 if not preview else 29) * scale_factor),
		CARD_TEXT_COLOR,
		true
	)

	if preview:
		card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return card_root

	var index := int(card.get("hand_index", 0))
	card_root.gui_input.connect(func(event: InputEvent): _on_card_gui_input(event, card, index))
	return card_root


func _on_card_gui_input(event: InputEvent, card: Dictionary, hand_index: int) -> void:
	if not bool(card.get("can_play", false)):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_card_drag(card, hand_index, get_viewport().get_mouse_position())
		else:
			_finish_card_drag(get_viewport().get_mouse_position())
	elif event is InputEventMouseMotion and is_dragging_card:
		_update_card_drag(get_viewport().get_mouse_position())
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_card_drag(card, hand_index, event.position)
		else:
			_finish_card_drag(event.position)
	elif event is InputEventScreenDrag and is_dragging_card:
		_update_card_drag(event.position)


func _begin_card_drag(card: Dictionary, hand_index: int, screen_position: Vector2) -> void:
	is_dragging_card = true
	dragging_card = card.duplicate(true)
	dragging_card_index = hand_index
	drag_start_position = screen_position
	if drag_preview != null:
		drag_preview.queue_free()
	drag_preview = _make_card_view(card, false, true)
	drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(drag_preview)
	_update_card_drag(screen_position)
	_update_play_hint(screen_position)


func _update_card_drag(screen_position: Vector2) -> void:
	if drag_preview == null:
		return
	drag_preview.global_position = screen_position - drag_preview.size / 2.0
	_update_play_hint(screen_position)


func _finish_card_drag(screen_position: Vector2) -> void:
	if not is_dragging_card:
		return
	var should_play := _is_in_play_zone(screen_position)
	_clear_drag_preview()
	if should_play:
		controller.play_card(dragging_card_index)
	elif screen_position.distance_to(drag_start_position) < 8.0:
		controller.play_card(dragging_card_index)
	dragging_card.clear()
	dragging_card_index = -1


func _clear_drag_preview() -> void:
	is_dragging_card = false
	play_hint_label.visible = false
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null


func _is_in_play_zone(screen_position: Vector2) -> bool:
	if hand_panel == null:
		return false
	return screen_position.y < hand_panel.global_position.y - 12.0


func _update_play_hint(screen_position: Vector2) -> void:
	play_hint_label.visible = _is_in_play_zone(screen_position)


func _update_log(snapshot: Dictionary) -> void:
	log_label.clear()
	var messages: Array = snapshot.get("log", [])
	var start: int = max(0, messages.size() - 6)
	for i in range(start, messages.size()):
		log_label.append_text(str(messages[i]) + "\n\n")
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.42, 0.32, 0.18, 1.0)
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(8))
	style.content_margin_left = _scaled_int(14)
	style.content_margin_top = _scaled_int(12)
	style.content_margin_right = _scaled_int(14)
	style.content_margin_bottom = _scaled_int(12)
	return style


func _make_card_style(disabled: bool, highlighted: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_DISABLED_COLOR if disabled else CARD_COLOR
	if highlighted and not disabled:
		style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = Color(0.28, 0.25, 0.20, 1.0) if disabled else ACCENT_COLOR
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(8))
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = _scaled_int(7)
	style.shadow_offset = Vector2(0, _scaled(4))
	style.content_margin_left = _scaled_int(9)
	style.content_margin_top = _scaled_int(9)
	style.content_margin_right = _scaled_int(9)
	style.content_margin_bottom = _scaled_int(9)
	return style


func _make_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.69, 0.28, 1.0)
	style.border_color = Color(0.20, 0.12, 0.05, 1.0)
	style.set_border_width_all(_scaled_int(2))
	style.set_corner_radius_all(_scaled_int(14))
	return style


func _make_inventory_slot_style(filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.145, 0.105, 0.96) if filled else Color(0.09, 0.085, 0.075, 0.82)
	style.border_color = Color(0.58, 0.42, 0.20, 0.95) if filled else Color(0.28, 0.23, 0.16, 0.95)
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(6))
	style.content_margin_left = _scaled_int(8)
	style.content_margin_top = _scaled_int(7)
	style.content_margin_right = _scaled_int(8)
	style.content_margin_bottom = _scaled_int(7)
	return style


func _load_card_frame() -> Texture2D:
	if card_frame_texture != null:
		return card_frame_texture
	card_frame_texture = _load_card_art(CARD_FRAME_PATH)
	return card_frame_texture


func _load_card_art(path: String) -> Texture2D:
	if path == "":
		return null
	if art_cache.has(path):
		return art_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D
	else:
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) == OK:
			texture = ImageTexture.create_from_image(image)
	art_cache[path] = texture
	return texture


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", _scaled_int(font_size))
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _set_single_line_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _add_clipped_label(
	parent: Control,
	rect: Rect2,
	value: String,
	font_size: int,
	color: Color,
	autowrap: bool
) -> Label:
	var clipper := Control.new()
	clipper.position = rect.position
	clipper.size = rect.size
	clipper.clip_contents = true
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clipper)

	var label := Label.new()
	label.position = Vector2.ZERO
	label.size = rect.size
	label.text = value
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if autowrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", max(1, font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.add_child(label)
	return label


func _on_viewport_size_changed() -> void:
	var next_scale := _calculate_ui_scale()
	if abs(next_scale - ui_scale) < 0.05:
		return
	ui_scale = next_scale
	_rebuild_view()


func _rebuild_view() -> void:
	_clear_drag_preview()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_view()
	if controller != null:
		_on_state_changed(controller.get_snapshot())


func _calculate_ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	var scale_from_width := viewport_size.x / 1920.0
	var scale_from_height := viewport_size.y / 1080.0
	return clamp(min(scale_from_width, scale_from_height), 1.0, 1.28)


func _scaled(value: float) -> float:
	return value * ui_scale


func _scaled_int(value: int) -> int:
	return max(1, int(round(float(value) * ui_scale)))
