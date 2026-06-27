extends Node
class_name HexMapCameraController

signal primary_map_pressed(world_position: Vector2)

@export var keyboard_pan_speed: float = 520.0
@export var min_zoom: float = 0.55
@export var max_zoom: float = 2.5
@export var zoom_step: float = 1.12

var camera: Camera2D
var is_panning := false
var last_mouse_position := Vector2.ZERO
var active_touches: Dictionary = {}
var last_touch_midpoint := Vector2.ZERO
var last_touch_distance := 0.0


func bind_camera(target_camera: Camera2D) -> void:
	camera = target_camera
	if camera != null:
		camera.enabled = true


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			primary_map_pressed.emit(_screen_to_world(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			last_mouse_position = get_viewport().get_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_mouse(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_mouse(1.0 / zoom_step)
	elif event is InputEventMouseMotion and is_panning:
		var mouse_position := get_viewport().get_mouse_position()
		_pan_by_screen_delta(mouse_position - last_mouse_position)
		last_mouse_position = mouse_position
	elif event is InputEventMagnifyGesture:
		_zoom_at_screen_position(event.factor, event.position)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_keyboard_pan(delta: float) -> void:
	if camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return
	camera.position += direction.normalized() * keyboard_pan_speed * delta / camera.zoom.x


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	if camera == null:
		return
	camera.position -= screen_delta / camera.zoom.x


func _zoom_at_mouse(factor: float) -> void:
	_zoom_at_screen_position(factor, get_viewport().get_mouse_position())


func _zoom_at_screen_position(factor: float, screen_position: Vector2) -> void:
	if camera == null:
		return
	var before_zoom_world := _screen_to_world(screen_position)
	var next_zoom: float = clamp(camera.zoom.x * factor, min_zoom, max_zoom)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after_zoom_world := _screen_to_world(screen_position)
	camera.position += before_zoom_world - after_zoom_world


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touches[event.index] = event.position
	else:
		active_touches.erase(event.index)
	_reset_touch_gesture_state()
	if not event.pressed and active_touches.is_empty():
		is_panning = false
	if event.pressed and active_touches.size() == 1:
		last_touch_midpoint = event.position


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	active_touches[event.index] = event.position
	if active_touches.size() == 1:
		_pan_by_screen_delta(event.relative)
		last_touch_midpoint = event.position
	elif active_touches.size() >= 2:
		var points := active_touches.values()
		var first: Vector2 = points[0]
		var second: Vector2 = points[1]
		var midpoint := (first + second) / 2.0
		var distance := first.distance_to(second)
		if last_touch_distance > 0.0:
			_zoom_at_screen_position(distance / last_touch_distance, midpoint)
			_pan_by_screen_delta(midpoint - last_touch_midpoint)
		last_touch_midpoint = midpoint
		last_touch_distance = distance


func _reset_touch_gesture_state() -> void:
	if active_touches.size() >= 2:
		var points := active_touches.values()
		var first: Vector2 = points[0]
		var second: Vector2 = points[1]
		last_touch_midpoint = (first + second) / 2.0
		last_touch_distance = first.distance_to(second)
	elif active_touches.size() == 1:
		last_touch_midpoint = active_touches.values()[0]
		last_touch_distance = 0.0
	else:
		last_touch_midpoint = Vector2.ZERO
		last_touch_distance = 0.0
