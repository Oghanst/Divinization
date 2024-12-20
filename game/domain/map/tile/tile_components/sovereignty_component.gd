extends TileComponent
class_name SovereigntyComponent


var sovereignty: Dictionary = {}

func get_sovereignty() -> Dictionary:
	"""
	获取主权信息
	"""
	return sovereignty

func _init(config: Dictionary, in_component_name:String = "sovereignty") -> void:
	"""
	初始化主权组件
	"""
	sovereignty = config
	component_name = in_component_name

func set_property(key: String, value: Variant) -> void:
	"""
	设置属性
	"""
	sovereignty[key] = value

func set_divine(divine: String) -> void:
	"""
	设置神权归属
	"""
	set_property("divine", divine)

func set_city(city: String) -> void:
	"""
	设置城市归属
	"""
	set_property("city", city)

func get_property(key: String) -> Variant:
	"""
	获取属性
	"""
	assert(sovereignty.has(key), "Property not found: " + key)
	return sovereignty[key]

func get_divine() -> String:
	"""
	获取神权归属
	"""
	return get_property("divine")

func get_city() -> String:
	"""
	获取城市归属
	"""
	return get_property("city")

func duplicate() -> SovereigntyComponent:
	"""
	复制组件
	"""
	return SovereigntyComponent.new(sovereignty, component_name)