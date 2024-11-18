extends Node
class_name City

enum CITY_SCALE {
	SMALL = 0,
	MEDIUM = 1,
	LARGE = 2,
}

@export var city_name: String = ""
@export var city_position: Vector2i = Vector2(0, 0)
@export var city_sprite: Sprite2D

var city_scale: CITY_SCALE = CITY_SCALE.SMALL
var defence: int = 0
var city_surrounding_tiles: Array[Vector2i] = []

# ===================================
# 简单的函数接口
# ===================================

func set_city_position(map_pos: Vector2i, local_pos: Vector2) -> void:
	"""
	设置城市位置
	"""
	city_position = map_pos
	city_sprite.position = local_pos

func set_city_scale(scale: CITY_SCALE) -> void:
	"""
	设置城市规模
	"""
	city_scale = scale

func set_city_name(new_city_name: String) -> void:
	"""
	设置城市名称
	"""
	city_name = new_city_name

func set_city_sprite(sprite: Sprite2D) -> void:
	"""
	设置城市精灵
	"""
	city_sprite = sprite

func set_city_surrounding_tiles(tiles: Array[Vector2i]) -> void:
	"""
	设置城市周围地块
	"""
	city_surrounding_tiles = tiles

func _init() -> void:
	pass
