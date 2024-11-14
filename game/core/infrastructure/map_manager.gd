extends Node2D
class_name MapManager

# 地图管理器，负责管理地块和资源
# 地块的注册、加载、卸载、生成、销毁
# 管理表现层和逻辑层一致

# 需要定义绘制好的tilemaplayer子节点
# 地形采用图块而不是场景，通过图集名称来获取地形类型。到时候一个图集就是一个地形类型，需要预制好图块而不是像croptails那样，并且每个图集名称必须是地形名称
@export var terrain_render_layer:TileMapLayer = null


var grid = {}  # 存储逻辑层数据，Key: Vector2, Value: Tile
var highlighted_grids: Dictionary = {}  # 存储高亮的地块
var highlighted_color: Color = Color(1, 1, 0, 0.5)  # 高亮颜色

func highlight_grid(pos: Vector2) -> void:
	"""
	高亮地块
	"""
	if not highlighted_grids.has(pos):
		var highlighted_rect = ColorRect.new()
		highlighted_rect.color = highlighted_color
		highlighted_rect.size = terrain_render_layer.tile_set.tile_size
		highlighted_rect.position = terrain_render_layer.map_to_local(pos) - highlighted_rect.size / 2
		add_child(highlighted_rect)
		highlighted_rect.visible = true
		highlighted_rect.z_index = 1
		highlighted_grids[pos] = highlighted_rect
		print_debug("highlighted grid at: " + str(pos))

func unhighlight_grid(pos: Vector2) -> void:
	"""
	取消高亮地块
	"""
	if highlighted_grids.has(pos):
		highlighted_grids[pos].queue_free()
		highlighted_grids.erase(pos)

func highlight_action(pos: Vector2) -> void:
	"""
	高亮地块动作
	"""
	if highlighted_grids.has(pos):
		unhighlight_grid(pos)
	else:
		highlight_grid(pos)

func _ready():
	assert(terrain_render_layer != null, "Terrain render layer is not set.")
	visible = true
	initialize_logic_from_render()
	load_grid_to_scene()
	
# 从 TileMapLayer 初始化逻辑层
func initialize_logic_from_render():
	for pos in terrain_render_layer.get_used_cells():
		var terrain_name = get_tile_resource_name(terrain_render_layer, pos)
		# var size = terrain_render_layer.tile_set.tile_size
		# print_debug(terrain_name, pos)
		grid[pos] = Tile.new()
		grid[pos].tile_terrain = terrain_name


func _input(event: InputEvent) -> void:
	# 处理鼠标点击事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var pos = terrain_render_layer.local_to_map(to_local(get_global_mouse_position()))
			if grid.has(pos):
				print_debug(grid[pos].tile_terrain)
				# print_debug(grid[pos].resources.resources)
				print_debug(grid[pos].population.population)
				highlight_action(pos)
			else:
				print_debug("No tile found at: " + str(pos))

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
