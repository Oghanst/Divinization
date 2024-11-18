extends Registry
class_name SovereigntyRegistry

var sovereignty_meta: Meta = Meta.new({
	"divine": "",
	"city": "",
})

var registry:Dictionary = {}

func register_basic_sovereignty_component(key:String, sovereignty_config:Dictionary) -> void:
	"""
	根据 key 注册主权, sovereignty_config 需要和主权的 meta 结构一致
	"""
	var config: Dictionary = sovereignty_meta.construct_config(sovereignty_config)
	registry[key] = SovereigntyComponent.new(config)

func register_default_sovereignty() -> void:
	"""
	注册默认主权
	"""
	# 默认主权组件， key 为空
	register_basic_sovereignty_component("", {
		"divine": "",
		"city": "",
	})
	

func _init() -> void:
	print("SovereigntyRegistry ready")
	register_default_sovereignty()

func get_component(key: String = "") -> SovereigntyComponent:
	"""
	获取主权组件的实例， key 为空则返回默认主权（无主权）组件
	"""
	return registry[key].duplicate()


func cleanup() -> void:
	registry.clear()
	sovereignty_meta.clear()