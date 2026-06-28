extends Control
class_name CivilizationStatusPanel

signal action_requested(action_id: String)

const PANEL_COLOR := Color(0.10, 0.095, 0.08, 0.94)
const BAR_COLOR := Color(0.075, 0.070, 0.060, 0.96)
const ACCENT_COLOR := Color(0.72, 0.55, 0.28, 1.0)
const TEXT_COLOR := Color(0.93, 0.88, 0.77, 1.0)
const MUTED_TEXT_COLOR := Color(0.76, 0.71, 0.62, 1.0)
const DANGER_COLOR := Color(0.72, 0.20, 0.16, 1.0)
const WARNING_COLOR := Color(0.82, 0.56, 0.20, 1.0)
const LIFE_COLOR := Color(0.34, 0.70, 0.40, 1.0)
const TOP_BAR_HEIGHT := 136.0
const SIDE_PANEL_WIDTH := 540.0
const SIDE_PANEL_TOP := 170.0
const BOTTOM_UI_RESERVED_HEIGHT := 560.0

var player_core_label: Label
var life_bar: ProgressBar
var life_bar_label: Label
var player_detail_label: Label
var resource_label: Label
var route_label: Label
var stage_label: Label
var enemy_intents_box: VBoxContainer
var tile_detail_label: Label
var recent_log_label: Label
var latest_snapshot: Dictionary = {}
var ui_scale := 1.0


func _ready() -> void:
	_build_view()


func set_ui_scale(value: float) -> void:
	ui_scale = value
	if is_inside_tree():
		_build_view()
		if not latest_snapshot.is_empty():
			update_view(latest_snapshot)


func update_view(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	if player_core_label == null:
		return
	player_core_label.text = _format_player_core(snapshot)
	_update_life_bar(snapshot)
	player_detail_label.text = _format_player_detail(snapshot)
	resource_label.text = _format_resource_strip(snapshot)
	route_label.text = _format_route_status(snapshot)
	stage_label.text = _format_stage_goal(snapshot)
	_render_enemy_intents(snapshot)
	tile_detail_label.text = _format_tile_details(snapshot)
	recent_log_label.text = _format_recent_log(snapshot)


func _build_view() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_PASS

	var viewport_size := get_viewport_rect().size
	_build_top_bar(viewport_size)
	_build_side_panel(viewport_size)


func _build_top_bar(viewport_size: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(_scaled(24), _scaled(18))
	panel.size = Vector2(max(_scaled(920), viewport_size.x - _scaled(48)), _scaled(TOP_BAR_HEIGHT))
	panel.custom_minimum_size = panel.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style(BAR_COLOR, ACCENT_COLOR))
	add_child(panel)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", _scaled_int(22))
	panel.add_child(row)

	var player_box := VBoxContainer.new()
	player_box.custom_minimum_size = Vector2(_scaled(360), 0)
	player_box.add_theme_constant_override("separation", _scaled_int(7))
	row.add_child(player_box)

	player_core_label = _make_label(27, TEXT_COLOR)
	_set_single_line_label(player_core_label)
	player_box.add_child(player_core_label)

	var life_row := HBoxContainer.new()
	life_row.add_theme_constant_override("separation", _scaled_int(10))
	player_box.add_child(life_row)

	life_bar = ProgressBar.new()
	life_bar.custom_minimum_size = Vector2(_scaled(230), _scaled(22))
	life_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_bar.show_percentage = false
	life_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.18, 0.055, 0.045, 1.0), Color(0.34, 0.16, 0.12, 1.0)))
	life_bar.add_theme_stylebox_override("fill", _make_bar_style(LIFE_COLOR, LIFE_COLOR.darkened(0.12)))
	life_row.add_child(life_bar)

	life_bar_label = _make_label(18, TEXT_COLOR)
	_set_single_line_label(life_bar_label)
	life_bar_label.custom_minimum_size = Vector2(_scaled(92), _scaled(24))
	life_row.add_child(life_bar_label)

	player_detail_label = _make_label(18, MUTED_TEXT_COLOR)
	player_box.add_child(player_detail_label)

	var resource_box := VBoxContainer.new()
	resource_box.custom_minimum_size = Vector2(_scaled(440), 0)
	resource_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_box.add_theme_constant_override("separation", _scaled_int(7))
	row.add_child(resource_box)

	resource_label = _make_label(21, TEXT_COLOR)
	resource_box.add_child(resource_label)

	route_label = _make_label(18, MUTED_TEXT_COLOR)
	resource_box.add_child(route_label)

	var stage_box := VBoxContainer.new()
	stage_box.custom_minimum_size = Vector2(_scaled(420), 0)
	stage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_box.add_theme_constant_override("separation", _scaled_int(7))
	row.add_child(stage_box)

	var stage_title := _make_label(18, ACCENT_COLOR)
	stage_title.text = "当前目标"
	_set_single_line_label(stage_title)
	stage_box.add_child(stage_title)

	stage_label = _make_label(19, TEXT_COLOR)
	stage_box.add_child(stage_label)


func _build_side_panel(viewport_size: Vector2) -> void:
	var panel_size := Vector2(
		_scaled(SIDE_PANEL_WIDTH),
		max(_scaled(320), viewport_size.y - _scaled(SIDE_PANEL_TOP) - _scaled(BOTTOM_UI_RESERVED_HEIGHT))
	)
	var panel := PanelContainer.new()
	panel.position = Vector2(
		max(_scaled(24), viewport_size.x - _scaled(24) - panel_size.x),
		_scaled(SIDE_PANEL_TOP)
	)
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, ACCENT_COLOR))
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(max(_scaled(120), panel_size.x - _scaled(52)), 0)
	box.add_theme_constant_override("separation", _scaled_int(14))
	scroll.add_child(box)

	box.add_child(_make_section_title("敌方意图"))
	enemy_intents_box = VBoxContainer.new()
	enemy_intents_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_intents_box.add_theme_constant_override("separation", _scaled_int(10))
	box.add_child(enemy_intents_box)

	box.add_child(_make_separator())
	box.add_child(_make_section_title("地块详情"))
	tile_detail_label = _make_label(18, MUTED_TEXT_COLOR)
	box.add_child(tile_detail_label)

	box.add_child(_make_separator())
	box.add_child(_make_section_title("近期记录"))
	recent_log_label = _make_label(17, MUTED_TEXT_COLOR)
	box.add_child(recent_log_label)


func _format_player_core(snapshot: Dictionary) -> String:
	return "第 %s 回合   AP %s/%s   Lv.%s" % [
		str(snapshot.get("turn", 1)),
		str(snapshot.get("action_points", 0)),
		str(snapshot.get("max_action_points", 0)),
		str(snapshot.get("level", 1)),
	]


func _update_life_bar(snapshot: Dictionary) -> void:
	if life_bar == null or life_bar_label == null:
		return
	var max_life: int = max(1, int(snapshot.get("max_life", 1)))
	var life: int = clamp(int(snapshot.get("life", 0)), 0, max_life)
	life_bar.max_value = max_life
	life_bar.value = life
	life_bar_label.text = "%s/%s" % [str(life), str(max_life)]
	var ratio := float(life) / float(max_life)
	var color := LIFE_COLOR
	if ratio <= 0.30:
		color = DANGER_COLOR
	elif ratio <= 0.55:
		color = WARNING_COLOR
	life_bar.add_theme_stylebox_override("fill", _make_bar_style(color, color.darkened(0.12)))


func _format_player_detail(snapshot: Dictionary) -> String:
	return "经验 %s   位置 %s\n理智：%s   隐秘：%s" % [
		str(snapshot.get("experience", 0)),
		str(snapshot.get("player_coord", Vector2i.ZERO)),
		str(snapshot.get("sanity_status", "")),
		str(snapshot.get("secrecy_status", "")),
	]


func _format_resource_strip(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("global_resources", {})
	return "信仰 %s   材料 %s   信徒 %s   据点 %s   使徒 %s" % [
		str(resources.get("faith", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("followers", 0)),
		str(resources.get("cult_cells", 0)),
		str(resources.get("apostles", 0)),
	]


func _format_route_status(snapshot: Dictionary) -> String:
	var routes: Dictionary = snapshot.get("route_affinity", {})
	var threshold_text := _format_route_threshold_mods(snapshot.get("route_bonus_threshold_mods", {}))
	var ascension: Dictionary = snapshot.get("ascension", {})
	var ascension_text := ""
	if not ascension.is_empty():
		if bool(ascension.get("complete", false)):
			ascension_text = "   已晋升：%s路线" % str(ascension.get("route_name", ""))
		else:
			ascension_text = "   晋升：%s" % str(ascension.get("status", ""))
	return "路线 生命%s 信仰%s 死亡%s 隐秘%s%s%s" % [
		str(routes.get("life", 0)),
		str(routes.get("faith", 0)),
		str(routes.get("death", 0)),
		str(routes.get("secret", 0)),
		threshold_text,
		ascension_text,
	]


func _format_stage_goal(snapshot: Dictionary) -> String:
	if bool(snapshot.get("stage_node_pending", false)):
		return "选择下个节点"
	if bool(snapshot.get("stage_reward_pending", false)):
		return "领取阶段奖励"
	if bool(snapshot.get("crisis_active", false)) and not bool(snapshot.get("stage_resolved", false)):
		return "最终事件处理中：%s" % str(snapshot.get("event_summary", ""))
	var event_label := "最终事件" if bool(snapshot.get("crisis_active", false)) else "倒计时"
	return "%s｜%s  %s：%s" % [
		str(snapshot.get("stage_node_name", "病村")),
		event_label,
		str(snapshot.get("event_countdown", 0)),
		str(snapshot.get("event_summary", "")),
	]


func _format_enemy_intents(snapshot: Dictionary) -> String:
	var intents: Array = snapshot.get("enemy_intents", [])
	if intents.is_empty():
		return "暂无明确敌意。继续探索、积累资源并观察预兆。"
	var lines: Array[String] = []
	for intent in intents:
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		var marker := _intent_marker(str(intent.get("severity", "normal")))
		lines.append("%s %s｜%s" % [
			marker,
			str(intent.get("title", "")),
			str(intent.get("timing", "")),
		])
		var body := str(intent.get("body", ""))
		if not body.is_empty():
			lines.append(body)
		var consequence := str(intent.get("consequence", ""))
		if not consequence.is_empty():
			lines.append("后果：%s" % consequence)
		var responses := str(intent.get("responses", ""))
		if not responses.is_empty():
			lines.append("应对：%s" % responses)
		lines.append("")
	if not lines.is_empty() and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines)


func _render_enemy_intents(snapshot: Dictionary) -> void:
	if enemy_intents_box == null:
		return
	for child in enemy_intents_box.get_children():
		enemy_intents_box.remove_child(child)
		child.queue_free()
	var intents: Array = snapshot.get("enemy_intents", [])
	if intents.is_empty():
		enemy_intents_box.add_child(_make_intent_card({
			"title": "暂无明确敌意",
			"timing": "观察中",
			"body": "继续探索、积累资源并观察预兆。",
			"severity": "normal",
		}))
		return
	for intent in intents:
		if typeof(intent) == TYPE_DICTIONARY:
			enemy_intents_box.add_child(_make_intent_card(intent))


func _make_intent_card(intent: Dictionary) -> PanelContainer:
	var severity := str(intent.get("severity", "normal"))
	var accent := _intent_color(severity)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_intent_style(accent))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _scaled_int(6))
	card.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", _scaled_int(8))
	box.add_child(title_row)

	var badge := Label.new()
	badge.text = _intent_badge_text(severity)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(_scaled(48), _scaled(30))
	badge.add_theme_font_size_override("font_size", _scaled_int(16))
	badge.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04, 1.0))
	badge.add_theme_stylebox_override("normal", _make_badge_style(accent))
	title_row.add_child(badge)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", _scaled_int(2))
	title_row.add_child(title_box)

	var title := _make_label(19, TEXT_COLOR)
	title.text = str(intent.get("title", ""))
	title_box.add_child(title)

	var timing := _make_label(16, accent.lightened(0.20))
	timing.text = str(intent.get("timing", ""))
	_set_single_line_label(timing)
	title_box.add_child(timing)

	_add_intent_line(box, str(intent.get("body", "")), TEXT_COLOR)
	_add_intent_line(box, _prefixed_text("后果", str(intent.get("consequence", ""))), WARNING_COLOR.lightened(0.20))
	_add_intent_line(box, _prefixed_text("应对", str(intent.get("responses", ""))), MUTED_TEXT_COLOR)
	return card


func _add_intent_line(parent: VBoxContainer, text: String, color: Color) -> void:
	if text.is_empty():
		return
	var label := _make_label(17, color)
	label.text = text
	parent.add_child(label)


func _prefixed_text(prefix: String, text: String) -> String:
	return "" if text.is_empty() else "%s：%s" % [prefix, text]


func _format_tile_details(snapshot: Dictionary) -> String:
	var current := _format_tile(snapshot.get("current_tile", {}))
	var selected := _format_tile(snapshot.get("selected_tile", {}))
	return "当前位置\n%s\n\n选中地块\n%s" % [current, selected]


func _format_tile(tile: Dictionary) -> String:
	if tile.is_empty():
		return "无"
	var site_name := str(tile.get("site_name", ""))
	var site_prefix := ""
	if not site_name.is_empty():
		site_prefix = "｜" + site_name
	if not bool(tile.get("explored", false)):
		var site_hint := ""
		if not site_name.is_empty():
			site_hint = "\n显著地点：%s" % site_name
		return "坐标 %s｜%s%s\n未知地块，需要调查。%s\n当前位置：%s" % [
			str(tile.get("coord", Vector2i.ZERO)),
			str(tile.get("terrain_name", "")),
			site_prefix,
			site_hint,
			"是" if bool(tile.get("is_player_location", false)) else "否",
		]
	var yields: Dictionary = tile.get("yields", {})
	var site_line := "地点：无"
	if not site_name.is_empty():
		site_line = "地点：%s\n%s" % [
			site_name,
			str(tile.get("site_description", "")),
		]
	return "坐标 %s｜%s｜人口 %s\n%s\n资源：%s\n产出：食物 %s / 生产 %s / 信仰 %s\n建筑：%s\n状态：%s\n入口：%s｜当前位置：%s" % [
		str(tile.get("coord", Vector2i.ZERO)),
		str(tile.get("terrain_name", "")),
		str(tile.get("population", 0)),
		site_line,
		str(tile.get("resource_text", "无")),
		str(yields.get("food", 0)),
		str(yields.get("production", 0)),
		str(yields.get("faith", 0)),
		str(tile.get("building_text", "无")),
		str(tile.get("state_text", "无")),
		str(tile.get("entrance_text", "无")),
		"是" if bool(tile.get("is_player_location", false)) else "否",
	]


func _format_recent_log(snapshot: Dictionary) -> String:
	var messages: Array = snapshot.get("log", [])
	if messages.is_empty():
		return "暂无记录。"
	var lines: Array[String] = []
	var start: int = max(0, messages.size() - 5)
	for i in range(start, messages.size()):
		lines.append("· " + str(messages[i]))
	return "\n".join(lines)


func _format_route_threshold_mods(mods: Dictionary) -> String:
	var parts: Array[String] = []
	for route_id in ["life", "faith", "death", "secret"]:
		var value := int(mods.get(route_id, 0))
		if value == 0:
			continue
		parts.append("%s%s" % [_route_short_name(route_id), _signed_int(value)])
	return "" if parts.is_empty() else "  阈值 " + " ".join(parts)


func _intent_marker(severity: String) -> String:
	match severity:
		"critical":
			return "!!"
		"warning":
			return "!"
	return "•"


func _intent_color(severity: String) -> Color:
	match severity:
		"critical":
			return DANGER_COLOR
		"warning":
			return WARNING_COLOR
	return ACCENT_COLOR


func _intent_badge_text(severity: String) -> String:
	match severity:
		"critical":
			return "危"
		"warning":
			return "警"
	return "意"


func _route_short_name(route_id: String) -> String:
	match route_id:
		"life":
			return "生命"
		"faith":
			return "信仰"
		"death":
			return "死亡"
		"secret":
			return "隐秘"
	return route_id


func _signed_int(value: int) -> String:
	if value > 0:
		return "+%s" % str(value)
	return str(value)


func _make_section_title(text: String) -> Label:
	var label := _make_label(20, ACCENT_COLOR)
	label.text = text
	_set_single_line_label(label)
	return label


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.38, 0.30, 0.18, 0.8))
	return separator


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.add_theme_font_size_override("font_size", _scaled_int(font_size))
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _set_single_line_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _make_panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(8))
	style.content_margin_left = _scaled_int(18)
	style.content_margin_top = _scaled_int(15)
	style.content_margin_right = _scaled_int(18)
	style.content_margin_bottom = _scaled_int(15)
	return style


func _make_intent_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.10, 0.98)
	style.border_color = accent
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(8))
	style.content_margin_left = _scaled_int(12)
	style.content_margin_top = _scaled_int(10)
	style.content_margin_right = _scaled_int(12)
	style.content_margin_bottom = _scaled_int(10)
	return style


func _make_badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.18)
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(6))
	return style


func _make_bar_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(5))
	return style


func _scaled(value: float) -> float:
	return value * ui_scale


func _scaled_int(value: int) -> int:
	return max(1, int(round(float(value) * ui_scale)))
