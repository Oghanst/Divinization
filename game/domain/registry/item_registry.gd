extends Registry
class_name ItemRegistry

var item_metas:Dictionary = {}
var name_to_id:Dictionary = {}
var item_metas_path:String = "res://data/game_meta/items_meta.json"


func register_item_meta(item_meta: ItemMeta) -> void:
	var item_name = item_meta.name
	if item_meta.item_id in item_metas.keys():
		print("Item id " + item_name + str(item_meta.item_id) + " already exists.")
		return
	item_metas[item_meta.item_id] = item_meta
	name_to_id[item_name] = item_meta.item_id

func load_items_meta() -> void:
	var file = FileAccess.open(item_metas_path, FileAccess.READ)
	if file:
		var data = JSON.new()
		var error = data.parse(file.get_as_text())
		if error == OK:
			var items_data = data.result
			for item_data in items_data: # items_data is a list of dictionaries
				var item_meta = ItemMeta.new()
				item_meta.construct_item_meta(item_data)
				register_item_meta(item_meta)
		else:
			print("An error occurred when trying to parse the item file.")
	else:
		print("An error occurred when trying to access the item file.")

func get_item_meta(item_id: int) -> ItemMeta:
	return item_metas[item_id]

func get_item_meta_by_name(item_name: String) -> ItemMeta:
	return item_metas[name_to_id[item_name]]
