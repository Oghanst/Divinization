extends Resource
class_name CompoundAttribute

var magic_attributes: Dictionary = {}
var physical_attributes: Dictionary = {}


# 获取某种属性的值
func get_attribute_value(category: AttributeType.Category, type: String) -> int:
	var default_value = 0
	match category:
		AttributeType.Category.MAGIC:
			return magic_attributes[type]
		AttributeType.Category.PHYSICAL:
			return physical_attributes[type]
	return default_value

func set_attribute_value(category: AttributeType.Category, type: String, value: int) -> void:
	match category:
		AttributeType.Category.MAGIC:
			magic_attributes[type] = value
		AttributeType.Category.PHYSICAL:
			physical_attributes[type] = value

func _init() -> void:
	"""
	初始化复合属性
	"""
	for key in AttributeType.MagicType.keys():
		key = key.to_lower()
		magic_attributes[key] = 0
	for key in AttributeType.PhysicalType.keys():
		key = key.to_lower()
		physical_attributes[key] = 0