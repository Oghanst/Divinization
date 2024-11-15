extends Node2D
class_name MapRenderLayer

# 地图渲染层，负责渲染地图，父节点必须是map manager

# ===================================
# 属性
# ===================================

# 需要定义绘制好的tilemaplayer子节点
# 地形采用图块而不是场景，通过图集名称来获取地形类型。到时候一个图集就是一个地形类型，需要预制好图块而不是像croptails那样，并且每个图集名称必须是地形名称
@export var tile_terrain_layer: TileMapLayer = null

var tile_to_source_id: Dictionary = {}  # 存储地形到 tile_id 的映射


var highlighted_cells: Dictionary = {}  # 存储高亮的地块
var highlighted_color: Color = Color(1, 1, 0, 0.5)  # 高亮颜色

# ===================================
# 信号
# ===================================

signal tile_clicked(pos: Vector2)

# ===================================
# 基本函数
# ===================================

func _ready() -> void:
	assert(tile_terrain_layer != null, "Render Terrain layer is not set.")
	setup_tile_to_source_id()
	print("MapRenderLayer ready")

func setup_tile_to_source_id() -> void:
	"""
	设置地形到 tile_id 的映射
	"""
	for i in range(tile_terrain_layer.tile_set.get_source_count()):
		var source_id = tile_terrain_layer.tile_set.get_source_id(i)
		var tile_name = get_source_resource_name(source_id)
		tile_to_source_id[tile_name] = source_id
	
	# 根据注册的地形类型检查是否有未找到对应 tile_id 的地形
	var terrain_not_found = []
	for key in RegisterService.get_registry("terrain_registry").terrain_types:
		if not tile_to_source_id.has(key):
			terrain_not_found.append(key)
	if terrain_not_found.size() > 0:
		print("WARNING: Terrain not found: " + str(terrain_not_found), ". Try check your tileset.")

# ===================================
# 给核心层的接口
# ===================================

func get_used_cells(layer: TileMapLayer) -> Array[Vector2i]:
	"""
	获取使用的单元格
	"""
	return layer.get_used_cells()

func get_cell_surrounding_cells(pos:Vector2i, layer: TileMapLayer)->Array[Vector2i]:
	return layer.get_surrounding_cells(pos)

func map_to_local(map_pos:Vector2i, layer: TileMapLayer=tile_terrain_layer)->Vector2:
	return layer.map_to_local(map_pos)

func local_to_map(local_pos:Vector2, layer: TileMapLayer=tile_terrain_layer)->Vector2i:
	return layer.local_to_map(local_pos)

func get_tile_resource_name(pos: Vector2, layer: TileMapLayer=tile_terrain_layer)->String:
	var source_id = layer.get_cell_source_id(pos)
	return get_source_resource_name(source_id, layer)

func get_source_resource_name(source_id: int, layer: TileMapLayer=tile_terrain_layer)->String:
	var source = layer.tile_set.get_source(source_id) 
	return source.resource_name

# ===================================
# 控制渲染层
# ===================================

func set_tile_terrain_layer(layer: TileMapLayer) -> void:
	"""
	设置地形图层
	"""
	tile_terrain_layer = layer

func set_cell(pos:Vector2i, tile_type: String, layer:TileMapLayer=tile_terrain_layer) -> void:
	"""
	设置单元格地形
	"""
	var source_id = tile_to_source_id[tile_type]
	# WARN: get_tile_id(0) 默认使用第一个tile，如果需要修改，需要额外的逻辑。
	layer.set_cell(pos, source_id, layer.tile_set.get_source(source_id).get_tile_id(0)) 
	print(get_tile_resource_name(pos, layer))


# 高亮相关功能

func highlight_cell(pos: Vector2) -> void:
	"""
	高亮地块，这部分是最简单的逻辑，TODO: 后续还要修改
	"""
	if not highlighted_cells.has(pos):
		var highlighted_rect = ColorRect.new()
		highlighted_rect.color = highlighted_color
		highlighted_rect.size = tile_terrain_layer.tile_set.tile_size
		highlighted_rect.position = map_to_local(pos) - highlighted_rect.size / 2
		add_child(highlighted_rect)
		highlighted_rect.visible = true
		highlighted_rect.z_index = 1 # 置于0层之上
		highlighted_cells[pos] = highlighted_rect
		print("highlighted grid at: " + str(pos))

func unhighlight_cell(pos: Vector2) -> void:
	"""
	取消高亮地块
	"""
	if highlighted_cells.has(pos):
		highlighted_cells[pos].queue_free()
		highlighted_cells.erase(pos)

func highlight_action(pos: Vector2) -> void:
	"""
	高亮地块动作
	"""
	if highlighted_cells.has(pos):
		unhighlight_cell(pos)
	else:
		highlight_cell(pos)


# ===================================
# 处理交互（要设置信号让 map manager 知道）
# ===================================


func _input(event: InputEvent) -> void:
	"""
	处理输入事件
	"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			
			var pos = local_to_map(to_local(get_global_mouse_position()))
			emit_signal("tile_clicked", pos)

