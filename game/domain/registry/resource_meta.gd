extends Meta
class_name ResourceMeta

@export var resource_id: int
@export var tags: Array = []

func construct_resource_meta(data: Dictionary) -> void:
	resource_id = data["resource_id"]
	name = data["name"]
	description = data["description"]
	tags = data["tags"]

func to_dict() -> Dictionary:
	return {
		"resource_id": resource_id,
		"name": name,
		"description": description,
		"tags": tags,
	}

func _to_string() -> String:
	return str(to_dict())