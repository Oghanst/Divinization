extends Registry
class_name ResourceRegistry

# 资源元数据注册表，只有表内的资源才能被使用，需要有默认值
var resource_metas:Dictionary = {}
var registry:Dictionary = {}

func register_resource_meta(resource_name: String, resource_meta: Meta) -> void:
	"""
	注册资源
	"""
	resource_metas[resource_name] = resource_meta


func register_resource_metas_from_file(file_path: String) -> void:
	"""
	从文件注册资源
	"""
	pass

func register_default_resource_metas() -> void:
	"""
	注册默认资源
	TODO:后续改为从配置文件读取
	"""
	resource_metas["food"] = Meta.new({
		"property": {
			"stock": 0,
			"capacity": 0,
			"regen_coef": 2.0,
		},
		"tags": ["food"],
	})

	resource_metas["wood"] = Meta.new({
		"property": {
			"stock": 0,
			"capacity": 0,
			"regen_coef": 0.0,
		},
		"tags": ["bulding_material"],
	})

	resource_metas["stone"] = Meta.new({
		"property": {
			"stock": 0,
			"capacity": 0,
			"regen_coef": 0.0,
		},
		"tags": ["bulding_material"],
	})

	resource_metas["iron"] = Meta.new({
		"property": {
			"stock": 0,
			"capacity": 0,
			"regen_coef": 0.0,
		},
		"tags": ["bulding_material"],
	})

	resource_metas["gold"] = Meta.new({
		"property": {
			"stock": 0,
			"capacity": 0,
			"regen_coef": 0.0,
		},
		"tags": ["currency"],
	})


func register_basic_resource_component(tile_terrain:String, resource_config:Dictionary) -> void:
	"""
	根据地块类型注册资源, resource_config 需要和资源的 meta 结构一致
	"""
	var config: Dictionary = {}
	# 根据 meta 生成资源配置
	for resource_name in resource_config:
		var meta = resource_metas[resource_name]
		if meta == null:
			print("Resource not registered: " + resource_name)
			continue
		var temp_config = meta.construct_config(resource_config[resource_name])
		config[resource_name] = temp_config
	registry[tile_terrain] = ResourceComponent.new(config)
		

func register_resources_from_file(file_path: String) -> void:
	"""
	从文件注册资源
	"""
	pass

func register_default_resources() -> void:
	"""
	注册默认资源
	"""
	register_basic_resource_component("grass", {
		"food": {
			"property": {
				"stock": 300,
				"capacity": 1000,
				"regen_coef": 2.0,
			},
		},
		"wood": {
			"property": {
				"stock": 250,
				"capacity": 500,
				"regen_coef": 0.5,
			},
		},
		"stone": {
			"property": {
				"stock": 100,
				"capacity": 100,
				"regen_coef": 0.0,
			},
		},
		"iron": {
			"property": {
				"stock": 100,
				"capacity": 100,
				"regen_coef": 0.0,
			},
		},
		"gold": {
			"property": {
				"stock": 0,
				"capacity": 100,
				"regen_coef": 0.0,
			},
		},
	})

func get_resource_component(tile_terrain: String) -> ResourceComponent:
	"""
	获取资源组件
	"""
	return registry[tile_terrain]

func _init() -> void:
	print("ResourceRegistry ready")
	register_default_resource_metas()
	register_default_resources()

func cleanup() -> void:
	"""
	清理资源
	"""
	registry.clear()
	resource_metas.clear()

