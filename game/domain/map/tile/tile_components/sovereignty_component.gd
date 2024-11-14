extends Object
class_name SovereigntyComponent

var sovereignty: String = ""  # 主权归属

func _init() -> void:
	"""
	初始化主权组件
	"""
	pass

func set_sovereignty(new_sovereignty: String) -> void:
	sovereignty = new_sovereignty