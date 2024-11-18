extends BoxContainer
class_name DynamicBoxContainer

# 要被动态展示的资源是子节点，而且要有注册好的名字和对应的info module
var registered_module: Dictionary = {}
var loaded_nodes: Dictionary = {}

func register_info_module(info_name:String, info_module:InfoModule) -> void:
	"""
	注册信息模块
	"""
	if not registered_module.has(info_name):
		registered_module[info_name] = info_module
	else:
		print("info module already registered")
	load_info_module(info_name)

func load_info_module(info_name:String) -> void:
	"""
	加载信息模块
	"""
	if not registered_module.has(info_name):
		print("info module not registered")
		return
	
	if not loaded_nodes.has(info_name):
		var info_module = registered_module[info_name].get_info_component()
		add_child(info_module)
		loaded_nodes[info_name] = info_module
	else:
		print("info module already loaded")

func clear_info_module() -> void:
	"""
	清空信息
	"""
	for node in get_children():
		node.queue_free()
	loaded_nodes.clear()
	registered_module.clear()

func update_content(info_data:Dictionary) -> void:
	"""
	更新内容
	"""
	print("update_content")
	for info_name in registered_module.keys():
		if info_data.has(info_name):
			registered_module[info_name].update_info(info_data[info_name])
		else:
			print("info data not found")
	queue_sort()

func initialize_info_module() -> void:
	"""
	初始化信息模块
	"""
	register_info_module("resource", TreeInfoModule.new("resource"))
	register_info_module("population", TreeInfoModule.new("population"))

func _ready() -> void:
	"""
	初始化
	"""
	print_debug("DynamicBoxContainer ready")
	self.vertical = true
	# initialize_info_module()
	# update_content({
	# 	"resource": {
	# 		"food": {
	# 			"property": {
	# 				"stock": 300,
	# 				"capacity": 1000,
	# 				"regen_coef": 2.0,
	# 			},
	# 		},
	# 		"wood": {
	# 			"property": {
	# 				"stock": 250,
	# 				"capacity": 500,
	# 				"regen_coef": 0.5,
	# 			},
	# 		},
	# 		"stone": {
	# 			"property": {
	# 				"stock": 100,
	# 				"capacity": 100,
	# 				"regen_coef": 0.0,
	# 			},
	# 		},
	# 		"iron": {
	# 			"property": {
	# 				"stock": 100,
	# 				"capacity": 100,
	# 				"regen_coef": 0.0,
	# 			},
	# 		},
	# 		"gold": {
	# 			"property": {
	# 				"stock": 0,
	# 				"capacity": 100,
	# 				"regen_coef": 0.0,
	# 			},
	# 		},
	# 	},
	# 	"population": {
	# 		"population": 20,
	# 		"residency": 100,
	# 		"food_consumption_coef": 1.0,
	# 	}
	# })

	# print(get_children())
	