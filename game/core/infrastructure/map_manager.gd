extends Node2D
class_name MapManager

# 地图管理器，负责管理地块和资源
# 地块的注册、加载、卸载、生成、销毁
# 管理表现层和逻辑层一致

# 需要定义绘制好的tilemaplayer子节点
# 地形采用图块而不是场景，通过图集名称来获取地形类型。到时候一个图集就是一个地形类型，需要预制好图块而不是像croptails那样，并且每个图集名称必须是地形名称
@export var terrain_render_layer:TileMapLayer = null


var grid = {}  # 存储逻辑层数据，Key: Vector2, Value: Tile

func _ready():
	assert(terrain_render_layer != null, "Terrain render layer is not set.")
	initialize_logic_from_render()
	load_grid_to_scene()
	
# 从 TileMapLayer 初始化逻辑层
func initialize_logic_from_render():
	for pos in terrain_render_layer.get_used_cells():
		var terrain_name = get_tile_resource_name(terrain_render_layer, pos)
		print(terrain_name, pos)
		grid[pos] = Tile.new()
		grid[pos].tile_terrain = terrain_name

func load_grid_to_scene():
	for pos in grid.keys():
		var tile = grid[pos]
		# tile.position = terrain_render_layer.map_to_world(pos)
		add_child(tile)

func get_tile_resource_name(map_layer:TileMapLayer, pos: Vector2)->String:
	var source_id = map_layer.get_cell_source_id(pos)
	return get_source_resource_name(map_layer, source_id)

func get_source_resource_name(map_layer:TileMapLayer, source_id: int)->String:
	var source = map_layer.tile_set.get_source(source_id) 
	return source.resource_name

func _exit_tree() -> void:
	for pos in grid.keys():
		grid[pos].queue_free()
	grid.clear()

