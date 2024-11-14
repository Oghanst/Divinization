extends Object
class_name SovereigntyComponent


var sovereignty: Dictionary = {}

func _init(config: Dictionary) -> void:
	"""
	初始化主权组件
	"""
	sovereignty = config

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