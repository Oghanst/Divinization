extends Control
class_name InfoModule

var info_name: String

func _init(in_info_name: String ="") -> void:
	self.info_name = in_info_name

func update_info(_data) -> void:
	pass

func get_info_component():
	print("infomodule get_info_component")
	pass