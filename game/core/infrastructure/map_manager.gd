extends Node2D
class_name MapManager

# 地图管理器，负责管理地块和资源
# 地块的注册、加载、卸载、生成、销毁
# 管理表现层和逻辑层一致

# 需要定义绘制好的tilemaplayer子节点
# 地形采用图块而不是场景，通过图集名称来获取地形类型。到时候一个图集就是一个地形类型，需要预制好图块而不是像croptails那样，并且每个图集名称必须是地形名称
@export var terrain_render_layer:TileMapLayer = null


var grid = {}  # 存储逻辑层数据，Key: Vector2i, Value: Tile
var cities = {}  # 存储城市数据，Key: Vector2i, Value: City

func set_city(pos: Vector2i, local_pos: Vector2, city: City) -> void:
	"""
	设置城市，同时设置城市周围地块的城市归属
	"""
	assert(cities.has(pos) == false, "City already exists at: " + str(pos))
	# print_debug(grid[pos])
	grid[pos].sovereignty.set_city(city.city_name)
	city.set_city_position(pos, local_pos)
	# 设置城市周围地块的城市归属，根据城市规模而定
	if city.city_surrounding_tiles.size() == 0:
		# print_debug("City surrounding tiles not set, generating...")
		city.city_surrounding_tiles.append(city.city_position)
	print("scale ", city.city_scale)
	for level in range(city.city_scale):
		# 获取周围地块
		var new_surrounding_tiles = city.city_surrounding_tiles.duplicate()
		for old_pos in city.city_surrounding_tiles:
			# print("terrain  " ,terrain_render_layer.get_surrounding_cells(old_pos))
			for new_pos in terrain_render_layer.get_surrounding_cells(old_pos):
				if grid.has(new_pos):
					if grid[new_pos].sovereignty.get_city() != "" and grid[new_pos].sovereignty.get_city() != city.city_name:
						continue # 已经有城市了, 跳过; TODO: 以后可以考虑合并城市
					grid[new_pos].sovereignty.set_city(city.city_name)
					new_surrounding_tiles.append(new_pos)
		city.city_surrounding_tiles = new_surrounding_tiles
	cities[pos] = city
	# 将城市添加到场景
	add_child(city)

func remove_city(pos: Vector2) -> void:
	"""
	移除城市，同时移除城市周围地块的城市归属
	"""
	assert(cities.has(pos) == true, "City not found at: " + str(pos))
	var city = cities[pos]
	cities.erase(pos)
	# 移除城市周围地块的城市归属
	for tile in city.city_surrounding_tiles:
		if grid.has(tile):
			grid[tile].sovereignty.set_city("")
	# 从场景移除城市
	city.queue_free()


func _ready():
	assert(terrain_render_layer != null, "Terrain render layer is not set.")
	visible = true
	initialize_logic_from_render()
	# print_debug(grid)
	load_to_scene(grid)
	var city = City.new()
	city.set_city_name("City1")
	city.set_city_sprite(Sprite2D.new())
	city.set_city_scale(City.CITY_SCALE.LARGE)
	var pos = Vector2i(3, 2)
	set_city(pos, terrain_render_layer.map_to_local(pos), city)
	
	city = cities[pos]
	print(city.city_surrounding_tiles.size())
	for p in city.city_surrounding_tiles:
		print_debug(p)
		highlight_grid(p)
	
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

func load_to_scene(dict: Dictionary) -> void:
	"""
	加载地图数据到场景
	"""
	for pos in dict.keys():
		var tile = dict[pos]
		# tile.position = terrain_render_layer.map_to_world(pos)
		add_child(tile)

func clear_scene(dict: Dictionary) -> void:
	"""
	清空场景
	"""
	for pos in dict.keys():
		dict[pos].queue_free()
	dict.clear()

func get_tile_resource_name(map_layer:TileMapLayer, pos: Vector2)->String:
	var source_id = map_layer.get_cell_source_id(pos)
	return get_source_resource_name(map_layer, source_id)

func get_source_resource_name(map_layer:TileMapLayer, source_id: int)->String:
	var source = map_layer.tile_set.get_source(source_id) 
	return source.resource_name

func _exit_tree() -> void:
	clear_scene(cities)
	clear_scene(grid)



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
