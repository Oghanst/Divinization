extends Node

var attribute_system:AttributeSystem = null

func _ready() -> void:
	attribute_system = AttributeSystem.new()

func _exit_tree() -> void:
	pass 