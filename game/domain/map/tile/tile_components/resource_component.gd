extends Object
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

func _init(config:Dictionary) -> void:
	"""
	初始化资源组件
	"""
	resources = config
	
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

func s_shape_regenerate(stock: int, capacity: int, regen_coef: float) -> int:
	var regen_amount = int( (1-(float)(stock)/(float)(capacity)) * regen_coef * capacity )
	return regen_amount

func regenerate_resource(resource_name: String, regenerate_func:Callable = s_shape_regenerate) -> void:
	assert(resources.has(resource_name), "Resource not found: " + resource_name)
	var resource:Dictionary = resources[resource_name]
	var stock:int = resource["property"]["stock"]
	var capacity:int = resource["property"]["capacity"]
	var regen_coef:float = resource["property"]["regen_coef"]
	var regen_amount:int = regenerate_func.call(stock, capacity, regen_coef)
	var new_stock:int = min(stock + regen_amount, capacity)
	resource["property"]["stock"] = new_stock

func get_all_resources() -> Dictionary:
	"""
	获取所有资源
	"""
	return resources
