extends Meta
class_name ItemMeta

@export var item_id: int
@export var is_consumable: bool
@export var is_equipment: bool
@export var icon_path: String

func construct_item_meta(data: Dictionary) -> void:
	item_id = data["item_id"]
	name = data["name"]
	description = data["description"]
	is_consumable = data["is_consumable"]
	is_equipment = data["is_equipment"]
	icon_path = data["icon_path"]

func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"name": name,
		"description": description,
		"is_consumable": is_consumable,
		"is_equipment": is_equipment,
		"icon_path": icon_path,
	}

func _to_string() -> String:
	return str(to_dict())