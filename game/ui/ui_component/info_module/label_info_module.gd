extends InfoModule
class_name LabelInfoModule

@export var label: Label

func get_info_component():
	return label

func update_info(info):
	label.text = str(info)

func _init(in_info_name: String =""):
	self.info_name = in_info_name
	self.label = Label.new()
	self.label.autowrap_mode = TextServer.AUTOWRAP_WORD

func _ready() -> void:
	assert(label != null, "Label is null")
