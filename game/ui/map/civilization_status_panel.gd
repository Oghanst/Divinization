extends Control
class_name CivilizationStatusPanel

signal action_requested(action_id: String)

const PANEL_COLOR := Color(0.10, 0.095, 0.08, 0.94)
const ACCENT_COLOR := Color(0.56, 0.45, 0.26, 1.0)
const TEXT_COLOR := Color(0.93, 0.88, 0.77, 1.0)
const MUTED_TEXT_COLOR := Color(0.76, 0.71, 0.62, 1.0)
const DISABLED_TEXT_COLOR := Color(0.48, 0.45, 0.40, 1.0)
const PANEL_WIDTH := 500.0
const PANEL_HEIGHT := 580.0

var header_label: Label
var player_label: Label
var current_tile_label: Label
var selected_tile_label: Label
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
	if header_label == null:
		return
	header_label.text = _format_header(snapshot)
	player_label.text = _format_player(snapshot)
	current_tile_label.text = _format_current_tile(snapshot.get("current_tile", {}))
	selected_tile_label.text = "选中地块\n" + _format_tile(snapshot.get("selected_tile", {}))


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

	var panel := PanelContainer.new()
	panel.position = Vector2(_scaled(24), _scaled(24))
	panel.size = Vector2(_scaled(PANEL_WIDTH), _scaled(PANEL_HEIGHT))
	panel.custom_minimum_size = panel.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _scaled_int(10))
	panel.add_child(root)

	header_label = _make_label(22, TEXT_COLOR)
	root.add_child(header_label)

	player_label = _make_label(18, MUTED_TEXT_COLOR)
	root.add_child(player_label)

	current_tile_label = _make_label(18, MUTED_TEXT_COLOR)
	root.add_child(current_tile_label)

	selected_tile_label = _make_label(18, MUTED_TEXT_COLOR)
	root.add_child(selected_tile_label)


func _format_header(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("global_resources", {})
	return "第 %s 回合  行动点 %s/%s\n信仰 %s  材料 %s  信徒 %s\n倒计时 %s：%s" % [
		str(snapshot.get("turn", 1)),
		str(snapshot.get("action_points", 0)),
		str(snapshot.get("max_action_points", 0)),
		str(resources.get("faith", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("followers", 0)),
		str(snapshot.get("event_countdown", 0)),
		str(snapshot.get("event_summary", "")),
	]


func _format_player(snapshot: Dictionary) -> String:
	return "生命 %s/%s  等级 %s  经验 %s\n理智 %s  隐秘 %s  位置 %s" % [
		str(snapshot.get("life", 0)),
		str(snapshot.get("max_life", 0)),
		str(snapshot.get("level", 1)),
		str(snapshot.get("experience", 0)),
		str(snapshot.get("sanity_status", "")),
		str(snapshot.get("secrecy_status", "")),
		str(snapshot.get("player_coord", Vector2i.ZERO)),
	]


func _format_current_tile(tile: Dictionary) -> String:
	if tile.is_empty():
		return "当前位置：无"
	return "当前位置：%s  %s  状态 %s" % [
		str(tile.get("coord", Vector2i.ZERO)),
		str(tile.get("terrain_name", "")),
		str(tile.get("state_text", "未知" if not bool(tile.get("explored", false)) else "无")),
	]


func _format_tile(tile: Dictionary) -> String:
	if tile.is_empty():
		return "无"
	if not bool(tile.get("explored", false)):
		return "坐标 %s  地形 %s\n资源/人口/建筑：未知\n状态：可疑  当前位置：%s" % [
			str(tile.get("coord", Vector2i.ZERO)),
			str(tile.get("terrain_name", "")),
			"是" if bool(tile.get("is_player_location", false)) else "否",
		]
	var yields: Dictionary = tile.get("yields", {})
	return "坐标 %s  %s  人口 %s\n资源：%s\n产出：食物 %s / 生产 %s / 信仰 %s\n建筑：%s\n状态：%s\n入口：%s  当前位置：%s" % [
		str(tile.get("coord", Vector2i.ZERO)),
		str(tile.get("terrain_name", "")),
		str(tile.get("population", 0)),
		str(tile.get("resource_text", "无")),
		str(yields.get("food", 0)),
		str(yields.get("production", 0)),
		str(yields.get("faith", 0)),
		str(tile.get("building_text", "无")),
		str(tile.get("state_text", "无")),
		str(tile.get("entrance_text", "无")),
		"是" if bool(tile.get("is_player_location", false)) else "否",
	]


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _scaled_int(font_size))
	label.add_theme_color_override("font_color", color)
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = ACCENT_COLOR
	style.set_border_width_all(_scaled_int(1))
	style.set_corner_radius_all(_scaled_int(8))
	style.content_margin_left = _scaled_int(16)
	style.content_margin_top = _scaled_int(14)
	style.content_margin_right = _scaled_int(16)
	style.content_margin_bottom = _scaled_int(14)
	return style


func _scaled(value: float) -> float:
	return value * ui_scale


func _scaled_int(value: int) -> int:
	return max(1, int(round(float(value) * ui_scale)))
