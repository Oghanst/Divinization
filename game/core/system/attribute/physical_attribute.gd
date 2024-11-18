extends Resource
class_name PhysicalTypeAttribute

@export var physical_type: AttributeType.PhysicalType=AttributeType.PhysicalType.SLASHING  # PhysicalType
@export var value: float = 0

func get_type_name() -> String:
    return AttributeType.PhysicalType.keys()[physical_type].to_lower()

func _init(in_physical_type: AttributeType.PhysicalType=AttributeType.PhysicalType.SLASHING, in_value: float=0) -> void:
    self.physical_type = in_physical_type
    self.value = in_value

