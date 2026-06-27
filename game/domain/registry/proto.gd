extends Object
class_name Proto
# 改为proto

var proto: Dictionary = {}

static func construct_config_from_proto(proto_dict: Dictionary, raw_config: Dictionary) -> Dictionary:
	"""
	根据 proto 生成资源配置
	"""
	var config:Dictionary = {}
	for key in proto_dict:
		var proto_value = proto_dict[key]
		var value = raw_config[key] if raw_config.has(key) else proto_value
		if typeof(proto_value) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
			config[key] = construct_config_from_proto(proto_value, value)
		else:
			config[key] = value
	return config

func construct_config(raw_config: Dictionary) -> Dictionary:
	"""
	根据 proto 生成资源配置
	"""
	return construct_config_from_proto(proto, raw_config)

func _init(proto_dict: Dictionary) -> void:
	"""
	初始化 proto
	"""
	proto = proto_dict

func clear() -> void:
	"""
	清理 proto
	"""
	proto.clear()
