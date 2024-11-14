extends Object
class_name Meta

var meta: Dictionary = {}

static func construct_config_from_meta(meta_dict: Dictionary, raw_config: Dictionary) -> Dictionary:
	"""
	根据 meta 生成资源配置
	"""
	var config:Dictionary = {}
	for key in meta_dict:
		var meta_value = meta_dict[key]
		var value = raw_config[key] if raw_config.has(key) else meta_value
		if typeof(meta_value) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
			config[key] = construct_config_from_meta(meta_value, value)
		else:
			config[key] = value
	return config

func construct_config(raw_config: Dictionary) -> Dictionary:
	"""
	根据 meta 生成资源配置
	"""
	return construct_config_from_meta(meta, raw_config)

func _init(meta_dict: Dictionary) -> void:
	"""
	初始化 meta
	"""
	meta = meta_dict

func clear() -> void:
	"""
	清理 meta
	"""
	meta.clear()
