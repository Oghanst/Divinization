extends Registry
class_name SovereigntyComponentFactory

var sovereignty_proto: Proto = Proto.new({
	"divine": "",
	"city": "",
})

var factory:Dictionary = {}

func register_basic_sovereignty_component(key:String, sovereignty_config:Dictionary) -> void:
	"""
	根据 key 注册主权, sovereignty_config 需要和主权的 proto 结构一致
	"""
	var config: Dictionary = sovereignty_proto.construct_config(sovereignty_config)
	factory[key] = SovereigntyComponent.new(config)

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
	print("SovereigntyComponentFactory ready")
	register_default_sovereignty()

func get_component(key: String = "") -> SovereigntyComponent:
	"""
	获取主权组件的实例， key 为空则返回默认主权（无主权）组件
	"""
	return factory[key].duplicate()


func cleanup() -> void:
	for component in factory.values():
		component.free()
	factory.clear()
	sovereignty_proto.clear()
	sovereignty_proto.free()
