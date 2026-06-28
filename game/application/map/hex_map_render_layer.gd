@tool
extends Node2D
class_name HexMapRenderLayer

const PLAYER_OWNER := "隐秘教团"
const TERRAIN_PLAIN := "plain"
const TERRAIN_FOREST := "forest"
const TERRAIN_HILL := "hill"
const TERRAIN_WATER := "water"
const TERRAIN_RUIN := "ruin"
const TERRAIN_HOLY_SITE := "holy_site"
const SITE_VILLAGE_GATE := "village_gate"
const SITE_SICK_HOUSE := "sick_house"
const SITE_OLD_WELL := "old_well"
const SITE_RUINED_SHRINE := "ruined_shrine"
const SITE_GRAVEYARD := "graveyard"

@export var hex_size: float = 52.0
@export var show_editor_preview := true:
	set(value):
		show_editor_preview = value
		_queue_preview_redraw()
@export_range(1, 10, 1) var editor_preview_radius := 6:
	set(value):
		editor_preview_radius = value
		_queue_preview_redraw()
@export var editor_preview_hex_size: float = 52.0:
	set(value):
		editor_preview_hex_size = value
		_queue_preview_redraw()

var tiles: Dictionary = {}
var selected_coord := Vector2i.ZERO
var player_coord := Vector2i.ZERO
var terrain_textures: Dictionary = {}
var resource_textures: Dictionary = {}
var shrine_texture: Texture2D

var terrain_colors := {
	TERRAIN_PLAIN: Color(0.30, 0.43, 0.25, 1.0),
	TERRAIN_FOREST: Color(0.16, 0.32, 0.21, 1.0),
	TERRAIN_HILL: Color(0.43, 0.37, 0.28, 1.0),
	TERRAIN_WATER: Color(0.16, 0.30, 0.43, 1.0),
	TERRAIN_RUIN: Color(0.35, 0.31, 0.39, 1.0),
	TERRAIN_HOLY_SITE: Color(0.47, 0.38, 0.22, 1.0),
}

var terrain_names := {
	TERRAIN_PLAIN: "平原",
	TERRAIN_FOREST: "森林",
	TERRAIN_HILL: "丘陵",
	TERRAIN_WATER: "水域",
	TERRAIN_RUIN: "遗迹",
	TERRAIN_HOLY_SITE: "圣址",
}


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func setup_map(map_tiles: Dictionary, generated: Dictionary, size: float) -> void:
	tiles = map_tiles
	hex_size = size
	_load_generated_textures(generated)
	queue_redraw()


func set_selected_coord(coord: Vector2i) -> void:
	selected_coord = coord
	queue_redraw()


func set_player_coord(coord: Vector2i) -> void:
	player_coord = coord
	queue_redraw()


func get_terrain_name(terrain: String) -> String:
	return terrain_names.get(terrain, terrain)


func collect_tile_textures(tile: RefCounted) -> void:
	if not terrain_textures.has(tile.terrain):
		terrain_textures[tile.terrain] = _load_texture(tile.terrain_texture_path)
	for i in range(tile.resource_ids.size()):
		var resource_id: String = tile.resource_ids[i]
		if not resource_textures.has(resource_id) and i < tile.resource_texture_paths.size():
			resource_textures[resource_id] = _load_texture(tile.resource_texture_paths[i])


func hex_to_pixel(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	return Vector2(
		hex_size * sqrt(3.0) * (q + r / 2.0),
		hex_size * 1.5 * r
	)


func pixel_to_hex(pixel: Vector2) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / hex_size
	var r := (2.0 / 3.0 * pixel.y) / hex_size
	return _cube_round(Vector3(q, -q - r, r))


func world_to_hex(world_position: Vector2) -> Vector2i:
	return pixel_to_hex(to_local(world_position))


func _draw() -> void:
	if tiles.is_empty():
		if Engine.is_editor_hint() and show_editor_preview:
			_draw_editor_preview()
		return
	for coord in tiles.keys():
		_draw_tile(tiles[coord])


func _load_generated_textures(generated: Dictionary) -> void:
	terrain_textures.clear()
	resource_textures.clear()
	for terrain_def in generated.get("terrain_defs", {}).values():
		var terrain_id := str(terrain_def.get("id", ""))
		var texture_path := str(terrain_def.get("texture", ""))
		terrain_textures[terrain_id] = _load_texture(texture_path)
		if terrain_def.has("color"):
			terrain_colors[terrain_id] = Color.html("#" + str(terrain_def["color"]))
		if terrain_def.has("name"):
			terrain_names[terrain_id] = str(terrain_def["name"])
	for resource_def in generated.get("resource_defs", {}).values():
		var resource_id := str(resource_def.get("id", ""))
		resource_textures[resource_id] = _load_texture(str(resource_def.get("texture", "")))
	shrine_texture = _load_texture("res://assets/generated/hex_map/resources/secret_shrine.png")


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var imported_texture := ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _draw_tile(tile: RefCounted) -> void:
	var center := hex_to_pixel(tile.coord)
	var points := _hex_points(center)
	var base_color: Color = terrain_colors.get(tile.terrain, Color.DARK_GRAY)
	var terrain_texture: Texture2D = terrain_textures.get(tile.terrain)
	if terrain_texture != null:
		var texture_size := Vector2(hex_size * 2.08, hex_size * 2.08)
		draw_texture_rect(terrain_texture, Rect2(center - texture_size / 2.0, texture_size), false)
	else:
		if tile.owner == PLAYER_OWNER:
			base_color = base_color.lightened(0.16)
		draw_colored_polygon(points, base_color)
	draw_polyline(PackedVector2Array(points + [points[0]]), Color(0.05, 0.045, 0.04, 1.0), 2.0)
	if tile.coord == selected_coord:
		draw_polyline(PackedVector2Array(points + [points[0]]), Color(0.95, 0.75, 0.32, 1.0), 4.0)
	_draw_resource_markers(tile, center)
	_draw_site_marker(tile, center)
	if tile.has_building("secret_shrine"):
		_draw_marker_texture(shrine_texture, center + Vector2(0, 18), 30.0)
	elif tile.owner == PLAYER_OWNER:
		draw_circle(center, 5.0, Color(0.91, 0.86, 0.72, 1.0))
	_draw_state_markers(tile, center)
	if tile.coord == player_coord:
		_draw_player_marker(center)


func _draw_resource_markers(tile: RefCounted, center: Vector2) -> void:
	var marker_count: int = min(tile.resource_ids.size(), 2)
	for i in range(marker_count):
		var texture: Texture2D = resource_textures.get(tile.resource_ids[i])
		var offset := Vector2(28 + i * 18, -28 + i * 16)
		_draw_marker_texture(texture, center + offset, 24.0)


func _draw_site_marker(tile: RefCounted, center: Vector2) -> void:
	var site_id := str(tile.site_id)
	if site_id.is_empty():
		return
	var marker_center := center + Vector2(-28, -28)
	var outer := Color(0.08, 0.065, 0.04, 0.92)
	var inner := Color(0.95, 0.74, 0.30, 0.95)
	match site_id:
		SITE_SICK_HOUSE:
			inner = Color(0.74, 0.22, 0.18, 0.96)
		SITE_OLD_WELL:
			inner = Color(0.22, 0.63, 0.74, 0.96)
		SITE_RUINED_SHRINE:
			inner = Color(0.82, 0.62, 0.28, 0.96)
		SITE_GRAVEYARD:
			inner = Color(0.52, 0.50, 0.46, 0.96)
	draw_circle(marker_center, 13.0, outer)
	draw_circle(marker_center, 9.0, inner)
	match site_id:
		SITE_SICK_HOUSE:
			draw_line(marker_center + Vector2(-5, 0), marker_center + Vector2(5, 0), outer, 3.0)
			draw_line(marker_center + Vector2(0, -5), marker_center + Vector2(0, 5), outer, 3.0)
		SITE_OLD_WELL:
			draw_arc(marker_center, 5.0, 0.0, TAU, 18, outer, 2.5)
		SITE_RUINED_SHRINE:
			draw_line(marker_center + Vector2(-5, 5), marker_center + Vector2(0, -5), outer, 2.5)
			draw_line(marker_center + Vector2(0, -5), marker_center + Vector2(5, 5), outer, 2.5)
			draw_line(marker_center + Vector2(-5, 5), marker_center + Vector2(5, 5), outer, 2.5)
		SITE_GRAVEYARD:
			draw_line(marker_center + Vector2(0, -6), marker_center + Vector2(0, 6), outer, 2.5)
			draw_line(marker_center + Vector2(-4, -1), marker_center + Vector2(4, -1), outer, 2.5)
		SITE_VILLAGE_GATE:
			draw_arc(marker_center, 5.5, 0.0, TAU, 20, outer, 2.5)


func _draw_marker_texture(texture: Texture2D, center: Vector2, size: float) -> void:
	if texture == null:
		draw_circle(center, size * 0.42, Color(0.95, 0.76, 0.35, 1.0))
		return
	var rect := Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size))
	draw_texture_rect(texture, rect, false)


func _draw_state_markers(tile: RefCounted, center: Vector2) -> void:
	var marker_count: int = min(tile.states.size(), 3)
	for i in range(marker_count):
		var offset := Vector2(-30 + i * 14, 28)
		var color := Color(0.70, 0.36, 0.32, 1.0)
		if tile.states[i] == "blessed" or tile.states[i] == "anchor":
			color = Color(0.86, 0.68, 0.32, 1.0)
		elif tile.states[i] == "depleted" or tile.states[i] == "investigated":
			color = Color(0.55, 0.50, 0.42, 1.0)
		draw_circle(center + offset, 4.0, color)


func _draw_player_marker(center: Vector2) -> void:
	draw_circle(center, 11.0, Color(0.97, 0.85, 0.42, 0.92))
	draw_arc(center, 17.0, 0.0, TAU, 32, Color(0.12, 0.09, 0.04, 1.0), 3.0)
	draw_arc(center, 21.0, -PI / 2.0, PI / 2.0, 16, Color(0.97, 0.85, 0.42, 0.82), 2.0)


func _hex_points(center: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return points


func _draw_editor_preview() -> void:
	var preview_colors: Array[Color] = [
		Color(0.30, 0.43, 0.25, 0.92),
		Color(0.16, 0.32, 0.21, 0.92),
		Color(0.43, 0.37, 0.28, 0.92),
		Color(0.16, 0.30, 0.43, 0.92),
		Color(0.47, 0.38, 0.22, 0.92),
	]
	for q in range(-editor_preview_radius, editor_preview_radius + 1):
		var r1: int = max(-editor_preview_radius, -q - editor_preview_radius)
		var r2: int = min(editor_preview_radius, -q + editor_preview_radius)
		for r in range(r1, r2 + 1):
			var coord := Vector2i(q, r)
			var center := _preview_hex_to_pixel(coord)
			var points := _preview_hex_points(center)
			var color_index: int = int(abs(q * 3 + r * 5)) % preview_colors.size()
			draw_colored_polygon(points, preview_colors[color_index])
			draw_polyline(PackedVector2Array(points + [points[0]]), Color(0.05, 0.045, 0.04, 1.0), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0.95, 0.75, 0.32, 1.0))


func _preview_hex_to_pixel(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	return Vector2(
		editor_preview_hex_size * sqrt(3.0) * (q + r / 2.0),
		editor_preview_hex_size * 1.5 * r
	)


func _preview_hex_points(center: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * editor_preview_hex_size)
	return points


func _queue_preview_redraw() -> void:
	if is_inside_tree():
		queue_redraw()


func _cube_round(cube: Vector3) -> Vector2i:
	var rx: float = round(cube.x)
	var ry: float = round(cube.y)
	var rz: float = round(cube.z)
	var x_diff: float = abs(rx - cube.x)
	var y_diff: float = abs(ry - cube.y)
	var z_diff: float = abs(rz - cube.z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))
