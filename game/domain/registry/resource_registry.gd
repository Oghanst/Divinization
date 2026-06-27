extends Registry
class_name ResourceRegistry

# 资源元数据注册表，只有表内的资源才能被使用
var resource_metas:Dictionary = {}
var resource_metas_path:String
var name_to_id:Dictionary = {}

func register_resource_meta(resource_meta: ResourceMeta) -> void:
	"""
	注册资源
	"""
	var resource_name = resource_meta.name
	if resource_meta.resource_id in resource_metas.keys():
		print("Resource " + resource_name  + str(resource_meta.resource_id) + " already exists.")
		return
	resource_metas[resource_meta.resource_id] = resource_meta
	name_to_id[resource_name] = resource_meta.resource_id

func get_resource_meta_by_name(resource_name: String) -> ResourceMeta:
	"""
	根据资源名获取资源元数据
	"""
	return resource_metas[name_to_id[resource_name]]

func load_resource_metas() -> void:
	"""
	加载资源元数据
	"""
	var file = FileAccess.open(resource_metas_path, FileAccess.READ)
	if file:
		var data = JSON.new()
		var error = data.parse(file.get_as_text())
		if error == OK:
			var resources_data = data.result
			for resource_data in resources_data: # resources_data is a list of dictionaries
				var resource_meta:ResourceMeta = ResourceMeta.new()
				resource_meta.construct_resource_meta(resource_data)
				register_resource_meta(resource_meta)
		else:
			print("An error occurred when trying to parse the resource file.")
	else:
		print("An error occurred when trying to access the resource file.")


func _init() -> void:
	print("ResourceRegistry ready")
	if resource_metas_path:
		load_resource_metas()
	else:
		register_default_resource_metas()
		print("ResourceRegistry: No resource meta file specified, using default values.")

func cleanup() -> void:
	"""
	清理资源
	"""
	resource_metas.clear()


func register_default_resource_metas() -> void:
	"""
	注册默认资源元数据
	"""
	var resources_meta_data = [
		{
			"resource_id": 1,
			"name": "wood",
			"description": "Wood is a resource that is used to build buildings and ships.",
			"tags": ["building_material"]
		},
		{
			"resource_id": 2,
			"name": "stone",
			"description": "Stone is a resource that is used to build buildings and ships.",
			"tags": ["building_material"]
		},
		{
			"resource_id": 3,
			"name": "iron",
			"description": "Iron is a resource that is used to build buildings and ships.",
			"tags": ["building_material"]
		},
		{
			"resource_id": 4,
			"name": "gold",
			"description": "Gold is a resource that is used to buy things.",
			"tags": ["currency"]
		},
		{
			"resource_id": 5,
			"name": "food",
			"description": "Food is a resource that is used to feed your people.",
			"tags": ["food"]
		},
		{
			"resource_id": 6,
			"name": "ruby",
			"description": "Ruby is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 7,
			"name": "sapphire",
			"description": "Sapphire is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 8,
			"name": "emerald",
			"description": "Emerald is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 9,
			"name": "diamond",
			"description": "Diamond is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 10,
			"name": "onyx",
			"description": "Onyx is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 11,
			"name": "amethyst",
			"description": "Amethyst is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 12,
			"name": "topaz",
			"description": "Topaz is a magical resource.",
			"tags": ["magic"]
		},
		{
			"resource_id": 13,
			"name": "aquamarine",
			"description": "Aquamarine is a magical resource.",
			"tags": ["magic"]
		}
	]
	for resource_data in resources_meta_data:
		var resource_meta:ResourceMeta = ResourceMeta.new()
		resource_meta.construct_resource_meta(resource_data)
		register_resource_meta(resource_meta)
