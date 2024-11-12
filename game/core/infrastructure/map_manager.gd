extends Node2D
class_name MapManager

# 地图管理器，负责管理地块和资源
# 地块的注册、加载、卸载、生成、销毁
# 管理表现层和逻辑层一致

# 假设有个tilemaplayer子节点
@export var render_layer:TileMapLayer = null


var grid = {}  # 存储逻辑层数据，Key: Vector2, Value: Dictionary

func _ready():
	if render_layer:
		print(get_tile_type(0, 1))
		print(get_tile_type(0, 22))
		initialize_logic_from_render()
	else:
		print("Render layer is not set!")

# 从 TileMapLayer 初始化逻辑层
func initialize_logic_from_render():
	for x in range(render_layer.get_used_rect().position.x, render_layer.get_used_rect().end.x):
		for y in range(render_layer.get_used_rect().position.y, render_layer.get_used_rect().end.y):
			var pos = Vector2(x, y)
			var source_id = render_layer.get_cell_source_id(pos)
			# print(source_id)

func get_tile_type(source_id: int, tile_id: int) :
	var source = render_layer.tile_set.get_source(source_id) as TileSetScenesCollectionSource
	if !source:
		return null
	var scene = source.get_scene_tile_scene(tile_id)
	if scene:
		return scene._bundled["names"][0]
	else:
		return null
	




# # Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass
