extends Node2D
class_name Tile
# 这里的地块变成只负责渲染的地块，资源逻辑等放到 MapManager 管理的另一个地块类中

@export var tile_terrain: String = "grass"

# 资源组件
var resource_component_factory: ResourceComponentFactory
var resources: ResourceComponent

# 人口组件
var population_component_factory: PopulationComponentFactory
var population: PopulationComponent

# 主权组件
var sovereignty_component_factory: SovereigntyComponentFactory
var sovereignty: SovereigntyComponent

# 建筑组件

# 神权组件


func get_tile_info() -> Dictionary:
	var tile_info: Dictionary = {
		"resource": resources.get_resources(),
		"population": population.get_population(),
		"sovereignty": sovereignty.get_sovereignty(),
	}
	return tile_info

func _ready() -> void:
	# 获取各个组件的实例，在生命周期中只获取一次
	resource_component_factory = RegisterService.get_registry("resource_component_factory")
	resources = resource_component_factory.get_component(tile_terrain)

	population_component_factory = RegisterService.get_registry("population_component_factory")
	population = population_component_factory.get_component(tile_terrain)

	sovereignty_component_factory = RegisterService.get_registry("sovereignty_component_factory")
	sovereignty = sovereignty_component_factory.get_component()
	if resources == null:
		print("Resource component not found: " + tile_terrain)
		queue_free()
		return
