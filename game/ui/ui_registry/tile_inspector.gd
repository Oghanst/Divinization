extends DynamicBoxContainer
class_name TileInspector


func on_show_info_module(info: Dictionary) -> void:
	self.update_content(info)
	self.visible = true

func on_hide_info_module() -> void:
	self.visible = false


func construct_inspector()->void:
	register_info_module("resource", TreeInfoModule.new("resource"))
	register_info_module("population", TreeInfoModule.new("population"))
	register_info_module("sovereignty", TreeInfoModule.new("sovereignty"))

func _ready() -> void:
	self.construct_inspector()
	self.visible = false
	