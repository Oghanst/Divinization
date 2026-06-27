extends Registry
class_name ResourceComponentFactory

var resource_proto:Proto = Proto.new({
	"stock": 0,
	"capacity": 0,
	"regen_coef": 0.0,
})
var factory: Dictionary = {}

func build_factory() -> void:
	register_default_resources()


func get_component(tile_terrain: String) -> ResourceComponent:
	"""
	获取资源组件的实例
	"""
	return factory[tile_terrain].duplicate()


func register_basic_resource_component(tile_terrain:String, resource_config:Dictionary) -> void:
	"""
	根据地块类型注册资源, resource_config 需要和资源的 proto 结构一致
	"""
	var config: Dictionary = {}
	# 根据 proto 生成资源配置
	for resource_name in resource_config:
		var temp_config = resource_proto.construct_config(resource_config[resource_name])
		config[resource_name] = temp_config
	factory[tile_terrain] = ResourceComponent.new(config)


func register_default_resources() -> void:
	"""
	注册默认资源
	"""
	register_basic_resource_component("grass", {
		"food": {
				"stock": 300,
				"capacity": 1000,
				"regen_coef": 2.0,
		},
		"wood": {
				"stock": 250,
				"capacity": 500,
				"regen_coef": 0.5,
		},
		"stone": {
				"stock": 100,
				"capacity": 100,
				"regen_coef": 0.0,
		},
		"iron": {
				"stock": 100,
				"capacity": 100,
				"regen_coef": 0.0,
		},
		"gold": {
				"stock": 0,
				"capacity": 100,
				"regen_coef": 0.0,
		},
	})
	register_basic_resource_component("plain", {
		"food": {
				"stock": 200,
				"capacity": 1000,
				"regen_coef": 2.0,
		},
		"wood": {
				"stock": 200,
				"capacity": 500,
				"regen_coef": 0.5,
		},
		"stone": {
				"stock": 50,
				"capacity": 100,
				"regen_coef": 0.0,
		},
		"iron": {
				"stock": 50,
				"capacity": 100,
				"regen_coef": 0.0,
		},
		"gold": {
				"stock": 0,
				"capacity": 100,
				"regen_coef": 0.0,
		},
		"ruby": {
				"stock": 0,
				"capacity": 100,
				"regen_coef": 0.0,
		},
	})


func _init() -> void:
	print("ResourceComponentFactory ready")
	build_factory()

func cleanup() -> void:
	for component in factory.values():
		component.free()
	factory.clear()
	resource_proto.clear()
	resource_proto.free()
