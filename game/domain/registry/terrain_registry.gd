extends Registry
class_name TerrainRegistry

var terrain_types: Array[String] = []

func register_terrain_type(terrain_type: String) -> void:
	"""
	注册地形类型
	"""
	if terrain_types.find(terrain_type) == -1:
		terrain_types.append(terrain_type)

func register_default_terrain_types() -> void:
	"""
	注册默认地形类型
	"""
	register_terrain_type("grass")
	register_terrain_type("plain")
	register_terrain_type("forest")
	register_terrain_type("mountain")


func _init() -> void:
	register_default_terrain_types()
	print("TerrainRegistry ready")