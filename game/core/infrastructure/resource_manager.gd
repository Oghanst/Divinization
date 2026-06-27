extends Node
class_name ResourceManager
# 负责管理游戏中的资源

var points: Array[Point] = []
var points_dir: String = "res://data/game_meta/points/"

var items_meta: Dictionary = {}
var items_meta_file: String = "res://data/game_meta/items.json"
var items: Array[Item] = []


func load_points() -> void:
	"""
	加载所有的点
	"""
	var point_files = UtilFunctions.get_dir_contents(points_dir)
	for file in point_files:
		var point = load(file)
		points.append(point)

# func save_points() -> void:
# 	"""
# 	保存所有的点
# 	"""
# 	for point in points:
# 		ResourceSaver.save(point)

func load_items_meta() -> void:
	"""
	加载所有的物品
	"""
	var file = FileAccess.open(items_meta_file, FileAccess.READ)
	if file:
		var data = JSON.new()
		var error = data.parse(file.get_as_text())
		if error == OK:
			var items_data = data.result
			for item_data in items_data:
				var item = Item.new()
				item.construct_item(item_data)
				items_meta[item.item_id] = item
		else:
			print("An error occurred when trying to parse the item file.")
	else:
		print("An error occurred when trying to access the item file.")


# func save_items() -> void:
# 	"""
# 	保存所有的物品
# 	"""
# 	var items_data = []
# 	for item in items_meta.values():
# 		items_data.append(item)
# 	var data:JSON = JSON.new()
# 	data.result = items_data
# 	var file = FileAccess.open(items_meta_file, FileAccess.WRITE)
# 	if file:
# 		file.store_string(data.to_string())
# 		file.close()
# 	else:
# 		print("An error occurred when trying to access the item file.")
