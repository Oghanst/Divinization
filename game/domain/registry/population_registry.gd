extends Registry
class_name PopulationRegistry

# 人口元数据，不需要像资源元数据一样是个dict
var population_meta: Meta = Meta.new({
	"population": 0,
	"residency": 0,
	"food_consumption_coef": 1.0,
})
var registry:Dictionary = {}

func register_basic_population_component(tile_terrain:String, population_config:Dictionary) -> void:
	"""
	根据地块类型注册资源, resource_config 需要和资源的 meta 结构一致
	"""
	var config: Dictionary = population_meta.construct_config(population_config)
	registry[tile_terrain] = PopulationComponent.new(config)

func register_default_population() -> void:
	"""
	注册默认资源
	"""
	register_basic_population_component("grass", {
		"population": 20,
		"residency": 100,
		"food_consumption_coef": 1.0,
	})
	register_basic_population_component("plain", {
		"population": 10,
		"residency": 200,
		"food_consumption_coef": 1.5,
	})

func get_component(tile_terrain: String) -> PopulationComponent:
	"""
	获取资源组件
	"""
	return registry[tile_terrain]

func _init() -> void:
	print("PopulationRegistry ready")
	register_default_population()

func cleanup() -> void:
	"""
	清理资源
	"""
	registry.clear()
	population_meta.clear()
