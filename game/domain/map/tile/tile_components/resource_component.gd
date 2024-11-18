extends TileComponent
class_name ResourceComponent

var resources: Dictionary = {}
# resources 模版
# {
# 	"food": {
# 		"property": {
# 			"stock": 300,
# 			"capacity": 1000,
# 			"regen_coef": 2.0,
# 		},
# 	},
# 	"wood": {
# 		"property": {
# 			"stock": 250,
# 			"capacity": 500,
# 			"regen_coef": 0.5,
# 		},
# 	},
# 	"stone": {
# 		"property": {
# 			"stock": 100,
# 			"capacity": 100,
# 			"regen_coef": 0.0,
# 		},
# 	},
# 	"iron": {
# 		"property": {
# 			"stock": 100,
# 			"capacity": 100,
# 			"regen_coef": 0.0,
# 		},
# 	},
# 	"gold": {
# 		"property": {
# 			"stock": 0,
# 			"capacity": 100,
# 			"regen_coef": 0.0,
# 		},
# 	},
# }

func _init(config:Dictionary, in_component_name:String="resource") -> void:
	"""
	初始化资源组件
	"""
	resources = config
	component_name = in_component_name
	
func collect_resource(resource_name: String, amount: int) -> int:
	"""
	收集资源, 返回实际收集的数量
	"""
	assert(resources.has(resource_name), "Resource not found: " + resource_name)
	assert(amount > 0, "Amount must be positive")
	var resource:Dictionary = resources[resource_name]
	var stock:int = resource["property"]["stock"]
	var new_stock:int = max(stock - amount, 0)
	var collected:int = stock - new_stock
	resource["property"]["stock"] = new_stock
	return collected


func regenerate_resource(resource_name: String, regenerate_func:Callable = UtilFunctions.linear_regenerate) -> void:
	assert(resources.has(resource_name), "Resource not found: " + resource_name)
	var resource:Dictionary = resources[resource_name]
	var stock:int = resource["property"]["stock"]
	var capacity:int = resource["property"]["capacity"]
	var regen_coef:float = resource["property"]["regen_coef"]
	var regen_amount:int = regenerate_func.call(stock, capacity, regen_coef)
	var new_stock:int = min(stock + regen_amount, capacity)
	resource["property"]["stock"] = new_stock

func get_resources() -> Dictionary:
	"""
	获取所有资源
	"""
	return resources

func get_property(key: String) -> Variant:
	"""
	获取资源属性
	"""
	assert(resources.has(key), "Property not found: " + key)
	return resources[key]

func duplicate() -> ResourceComponent:
	"""
	复制组件
	"""
	return ResourceComponent.new(resources, component_name)