extends Control
class_name CivilizationStatusPanel

signal action_requested(action_id: String)

const PANEL_COLOR := Color(0.10, 0.095, 0.08, 0.94)
const ACCENT_COLOR := Color(0.56, 0.45, 0.26, 1.0)
const TEXT_COLOR := Color(0.93, 0.88, 0.77, 1.0)
const MUTED_TEXT_COLOR := Color(0.76, 0.71, 0.62, 1.0)
const DISABLED_TEXT_COLOR := Color(0.48, 0.45, 0.40, 1.0)
const PANEL_WIDTH := 500.0
const PANEL_HEIGHT := 700.0

var header_label: Label
var player_label: Label
var crisis_preview_label: Label
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
	crisis_preview_label.text = _format_crisis_preview(snapshot)
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

	crisis_preview_label = _make_label(17, MUTED_TEXT_COLOR)
	root.add_child(crisis_preview_label)

	current_tile_label = _make_label(18, MUTED_TEXT_COLOR)
	root.add_child(current_tile_label)

	selected_tile_label = _make_label(18, MUTED_TEXT_COLOR)
	root.add_child(selected_tile_label)


func _format_header(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("global_resources", {})
	var event_label := "最终事件" if bool(snapshot.get("crisis_active", false)) else "倒计时"
	var pending: Dictionary = snapshot.get("pending_event", {})
	var pending_line := ""
	if not pending.is_empty():
		var options: Array[String] = ["放任"]
		if not pending.get("handled_effects", []).is_empty():
			options.append("处理")
		if not pending.get("converted_effects", []).is_empty():
			options.append("转化")
		if not pending.get("exploited_effects", []).is_empty():
			options.append("利用")
		pending_line = "\n预兆：%s（%s）" % [str(pending.get("name", "")), " / ".join(options)]
	return "第 %s 回合  行动点 %s/%s\n节点：%s\n信仰 %s  材料 %s  信徒 %s  据点 %s  使徒 %s\n%s %s：%s%s" % [
		str(snapshot.get("turn", 1)),
		str(snapshot.get("action_points", 0)),
		str(snapshot.get("max_action_points", 0)),
		str(snapshot.get("stage_node_name", "病村")),
		str(resources.get("faith", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("followers", 0)),
		str(resources.get("cult_cells", 0)),
		str(resources.get("apostles", 0)),
		event_label,
		str(snapshot.get("event_countdown", 0)),
		str(snapshot.get("event_summary", "")),
		pending_line,
	]


func _format_player(snapshot: Dictionary) -> String:
	var routes: Dictionary = snapshot.get("route_affinity", {})
	var threshold_mods: Dictionary = snapshot.get("route_bonus_threshold_mods", {})
	var threshold_text := _format_route_threshold_mods(threshold_mods)
	return "生命 %s/%s  等级 %s  经验 %s\n理智 %s  隐秘 %s  位置 %s\n倾向 生命%s 信仰%s 死亡%s 隐秘%s%s" % [
		str(snapshot.get("life", 0)),
		str(snapshot.get("max_life", 0)),
		str(snapshot.get("level", 1)),
		str(snapshot.get("experience", 0)),
		str(snapshot.get("sanity_status", "")),
		str(snapshot.get("secrecy_status", "")),
		str(snapshot.get("player_coord", Vector2i.ZERO)),
		str(routes.get("life", 0)),
		str(routes.get("faith", 0)),
		str(routes.get("death", 0)),
		str(routes.get("secret", 0)),
		threshold_text,
	]


func _format_crisis_preview(snapshot: Dictionary) -> String:
	if bool(snapshot.get("stage_node_pending", false)):
		var node_lines: Array[String] = ["选择下个节点"]
		for node in snapshot.get("stage_node_options", []):
			if typeof(node) != TYPE_DICTIONARY:
				continue
			node_lines.append("%s（%s 回合）：%s" % [
				str(node.get("name", "")),
				str(node.get("turn_limit", 0)),
				str(node.get("effect_summary", "")),
			])
		return "\n".join(node_lines)
	if bool(snapshot.get("stage_resolved", false)):
		var reward_lines: Array[String] = ["阶段结果：%s" % str(snapshot.get("event_summary", ""))]
		var rewards: Array = snapshot.get("stage_reward_options", [])
		if bool(snapshot.get("stage_reward_pending", false)) and not rewards.is_empty():
			reward_lines.append("选择奖励")
			for reward in rewards:
				if typeof(reward) != TYPE_DICTIONARY:
					continue
				reward_lines.append("%s：%s" % [
					str(reward.get("name", "")),
					str(reward.get("effect_summary", "")),
				])
		elif bool(snapshot.get("stage_reward_claimed", false)):
			reward_lines.append("奖励已领取")
		return "\n".join(reward_lines)
	if bool(snapshot.get("organization_hunt_pending", false)):
		return "追猎预警\n敌对势力正在逼近教团。据点与使徒会暴露你的位置。\n选择遮蔽追猎、误导追猎，或放任搜查。"
	var previews: Array = snapshot.get("crisis_preview", [])
	var lines: Array[String] = []
	if not previews.is_empty():
		lines.append("准备方向")
		for item in previews:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var mark := "可用" if bool(item.get("ready", false)) else "准备"
			lines.append("%s｜%s：%s" % [
				mark,
				str(item.get("name", "")),
				str(item.get("status", "")),
			])
	var ascension: Dictionary = snapshot.get("ascension", {})
	var ascension_text := _format_ascension(ascension)
	if not ascension_text.is_empty():
		lines.append(ascension_text)
	return "\n".join(lines)


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


func _format_route_threshold_mods(mods: Dictionary) -> String:
	var parts: Array[String] = []
	for route_id in ["life", "faith", "death", "secret"]:
		var value := int(mods.get(route_id, 0))
		if value == 0:
			continue
		parts.append("%s%s" % [_route_short_name(route_id), _signed_int(value)])
	return "" if parts.is_empty() else "\n加成阈值 " + "  ".join(parts)


func _format_ascension(ascension: Dictionary) -> String:
	if ascension.is_empty():
		return ""
	if bool(ascension.get("complete", false)):
		var lines: Array[String] = ["章节目标", "已晋升｜第一次晋升：%s路线" % str(ascension.get("route_name", ""))]
		var upgrade: Dictionary = ascension.get("power_upgrade", {})
		if not upgrade.is_empty():
			var mark := "已强化" if bool(upgrade.get("complete", false)) else ("可强化" if bool(upgrade.get("ready", false)) else "强化准备")
			lines.append("%s｜%s" % [mark, str(upgrade.get("status", _format_power_upgrade_status(upgrade)))])
		return "\n".join(lines)
	var mark := "可举行" if bool(ascension.get("ready", false)) else "准备"
	return "章节目标\n%s｜第一次晋升：%s" % [
		mark,
		str(ascension.get("status", "")),
	]


func _format_power_upgrade_status(upgrade: Dictionary) -> String:
	if bool(upgrade.get("complete", false)):
		return "权能牌：%s" % str(upgrade.get("to_card_name", ""))
	return "%s -> %s" % [
		str(upgrade.get("from_card_name", "")),
		str(upgrade.get("to_card_name", "")),
	]


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
