extends Resource
class_name MagicAttribute

@export var magic_type: AttributeType.MagicType=AttributeType.MagicType.LIGHT # MagicTyp
@export var value: float = 0

func get_type_name() -> String:
    return AttributeType.MagicType.keys()[magic_type].to_lower()

func _init(in_magic_type: AttributeType.MagicType=AttributeType.MagicType.LIGHT, in_value: float=0) -> void:
    self.magic_type = in_magic_type
    self.value = in_value
