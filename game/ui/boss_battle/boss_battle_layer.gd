extends Control
class_name BossBattleLayer

const BACKGROUND_PATH := "res://assets/generated/boss_battle/plague_village_arena.png"
const BOSS_ART_PATH := "res://assets/generated/boss_battle/ulcer_apostle_cutout.png"
const TEXT_COLOR := Color(0.94, 0.88, 0.76, 1.0)
const MUTED_TEXT_COLOR := Color(0.76, 0.70, 0.60, 1.0)
const ACCENT_COLOR := Color(0.78, 0.58, 0.27, 1.0)
const DANGER_COLOR := Color(0.72, 0.18, 0.15, 1.0)
const LIFE_COLOR := Color(0.36, 0.68, 0.38, 1.0)
const PANEL_BG := Color(0.08, 0.075, 0.065, 0.82)

var controller: CardRunController
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_health_label: Label
var boss_meta_label: Label
var boss_art: TextureRect
var intent_name_label: Label
var intent_body_label: Label
var intent_response_label: Label
var player_health_bar: ProgressBar
var player_health_label: Label
var player_meta_label: Label
var player_progress_label: Label
var result_banner: PanelContainer
var result_label: Label


func bind_controller(card_controller: CardRunController) -> void:
	controller = card_controller
	if not controller.state_changed.is_connected(_on_state_changed):
		controller.state_changed.connect(_on_state_changed)
	if is_inside_tree():
		_on_state_changed(controller.get_snapshot())


func _ready() -> void:
	_build_view()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if controller != null:
		_on_state_changed(controller.get_snapshot())


func _build_view() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	var background := TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = _load_texture(BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.018, 0.015, 0.30)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	boss_art = TextureRect.new()
	boss_art.texture = _load_texture(BOSS_ART_PATH)
	boss_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss_art.anchor_left = 0.32
	boss_art.anchor_top = 0.10
	boss_art.anchor_right = 0.70
	boss_art.anchor_bottom = 0.68
	boss_art.offset_left = 0
	boss_art.offset_top = 0
	boss_art.offset_right = 0
	boss_art.offset_bottom = 0
	boss_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_art)

	_build_boss_hud()
	_build_player_hud()
	_build_intent_card()
	_build_result_banner()


func _build_boss_hud() -> void:
	var panel := _make_floating_panel(DANGER_COLOR)
	panel.anchor_left = 0.24
	panel.anchor_right = 0.76
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0
	panel.offset_top = 24
	panel.offset_right = 0
	panel.offset_bottom = 132
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	boss_name_label = _make_label(25, TEXT_COLOR)
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(boss_name_label)

	boss_health_label = _make_label(20, TEXT_COLOR)
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_health_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(boss_health_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.custom_minimum_size = Vector2(0, 26)
	boss_health_bar.show_percentage = false
	boss_health_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.19, 0.05, 0.045, 1.0), Color(0.32, 0.11, 0.09, 1.0)))
	boss_health_bar.add_theme_stylebox_override("fill", _make_bar_style(DANGER_COLOR, DANGER_COLOR.lightened(0.15)))
	box.add_child(boss_health_bar)

	boss_meta_label = _make_label(18, ACCENT_COLOR.lightened(0.12))
	box.add_child(boss_meta_label)


func _build_player_hud() -> void:
	var panel := _make_floating_panel(LIFE_COLOR)
	panel.anchor_left = 0.03
	panel.anchor_right = 0.27
	panel.anchor_top = 0.14
	panel.anchor_bottom = 0.14
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 164
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title := _make_label(21, LIFE_COLOR.lightened(0.16))
	title.text = "玩家"
	box.add_child(title)

	player_health_label = _make_label(18, TEXT_COLOR)
	box.add_child(player_health_label)

	player_health_bar = ProgressBar.new()
	player_health_bar.custom_minimum_size = Vector2(0, 22)
	player_health_bar.show_percentage = false
	player_health_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.08, 0.14, 0.08, 1.0), Color(0.13, 0.24, 0.13, 1.0)))
	player_health_bar.add_theme_stylebox_override("fill", _make_bar_style(LIFE_COLOR, LIFE_COLOR.lightened(0.14)))
	box.add_child(player_health_bar)

	player_meta_label = _make_label(17, TEXT_COLOR)
	box.add_child(player_meta_label)

	player_progress_label = _make_label(16, MUTED_TEXT_COLOR)
	box.add_child(player_progress_label)


func _build_intent_card() -> void:
	var panel := _make_floating_panel(ACCENT_COLOR)
	panel.anchor_left = 0.75
	panel.anchor_right = 0.97
	panel.anchor_top = 0.15
	panel.anchor_bottom = 0.15
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 210
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)

	var title := _make_label(18, ACCENT_COLOR)
	title.text = "敌方意图"
	box.add_child(title)

	intent_name_label = _make_label(24, TEXT_COLOR)
	box.add_child(intent_name_label)

	intent_body_label = _make_label(18, TEXT_COLOR)
	box.add_child(intent_body_label)

	intent_response_label = _make_label(16, MUTED_TEXT_COLOR)
	box.add_child(intent_response_label)


func _build_result_banner() -> void:
	result_banner = _make_floating_panel(ACCENT_COLOR)
	result_banner.anchor_left = 0.34
	result_banner.anchor_right = 0.66
	result_banner.anchor_top = 0.68
	result_banner.anchor_bottom = 0.68
	result_banner.offset_left = 0
	result_banner.offset_top = -42
	result_banner.offset_right = 0
	result_banner.offset_bottom = 32
	result_banner.visible = false
	add_child(result_banner)

	result_label = _make_label(23, TEXT_COLOR)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_banner.add_child(result_label)


func _on_state_changed(snapshot: Dictionary) -> void:
	var phase := str(snapshot.get("phase", "preparation"))
	visible = ["boss", "finished"].has(phase)
	if not visible:
		return
	var boss: Dictionary = snapshot.get("boss", {})
	var result: Dictionary = snapshot.get("final_result", {})
	_update_boss_hud(boss, phase)
	_update_player_hud(snapshot)
	_update_intent_card(boss, result, phase)


func _update_boss_hud(boss: Dictionary, phase: String) -> void:
	var max_life: int = max(1, int(boss.get("max_life", 1)))
	var life: int = clamp(int(boss.get("life", 0)), 0, max_life)
	boss_name_label.text = str(boss.get("name", "溃疡使徒"))
	boss_health_bar.max_value = max_life
	boss_health_bar.value = life
	boss_health_label.text = "%s / %s" % [str(life), str(max_life)]
	boss_meta_label.text = "病灶护层 %s   蓄力 %s   回合 %s%s" % [
		str(boss.get("lesion_shield", 0)),
		str(boss.get("charge", 0)),
		str(boss.get("turn", 1)),
		"   已结算" if phase == "finished" else "",
	]


func _update_player_hud(snapshot: Dictionary) -> void:
	var resources: Dictionary = snapshot.get("resources", {})
	var progress: Dictionary = snapshot.get("progress", {})
	var max_life: int = max(1, int(resources.get("max_life", 1)))
	var life: int = clamp(int(resources.get("life", 0)), 0, max_life)
	player_health_bar.max_value = max_life
	player_health_bar.value = life
	player_health_label.text = "生命 %s / %s" % [str(life), str(max_life)]
	player_meta_label.text = "AP %s/%s   护盾 %s" % [
		str(resources.get("action_points", 0)),
		str(snapshot.get("encounter", {}).get("action_points", 3)),
		str(snapshot.get("player_block", 0)),
	]
	player_progress_label.text = "病势 %s/6   线索 %s/3   锚点 %s/3\n信徒 %s   材料 %s   信仰 %s" % [
		str(progress.get("infection", 0)),
		str(progress.get("source_clues", 0)),
		str(progress.get("anchor_progress", 0)),
		str(resources.get("followers", 0)),
		str(resources.get("materials", 0)),
		str(resources.get("faith", 0)),
	]


func _update_intent_card(boss: Dictionary, result: Dictionary, phase: String) -> void:
	result_banner.visible = phase == "finished"
	if phase == "finished":
		intent_name_label.text = "战斗结束"
		intent_body_label.text = str(result.get("text", ""))
		intent_response_label.text = "选择奖励牌后回到下一步。"
		result_label.text = str(result.get("name", "关卡结束"))
		return
	var intent: Dictionary = boss.get("intent", {})
	intent_name_label.text = str(intent.get("name", "未知意图"))
	intent_body_label.text = str(intent.get("text", ""))
	intent_response_label.text = "应对：防御 / 治疗 / 攻击 / 满足条件后使用萌芽祭净化"


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_floating_panel(border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, border_color))
	return panel


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture := ResourceLoader.load(path) as Texture2D
		if texture != null:
			return texture
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(image)
	return null


func _make_panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_bar_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
