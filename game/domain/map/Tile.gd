extends Node2D
class_name Tile
# 这里的地块变成只负责渲染的地块，资源逻辑等放到 MapManager 管理的另一个地块类中

@export var tile_terrain: String = "grass"
var resources: ResourceComponent

var resource_registry: ResourceRegistry

func _ready() -> void:
	print(get_path())
	resource_registry = RegisterService.get_registry("resource_registry")
	resources = resource_registry.get_resource_component(tile_terrain)
	if resources == null:
		print("Resource component not found: " + tile_terrain)
		queue_free()
		return
	print(resources.resources)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
