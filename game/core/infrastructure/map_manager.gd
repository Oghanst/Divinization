extends Node2D
class_name MapManager

# 地图管理器，负责管理地块和资源
# 地块的注册、加载、卸载、生成、销毁
# 管理表现层和逻辑层一致

@export var map_render_layer:MapRenderLayer = null


var grid = {}  # 存储逻辑层数据，Key: Vector2i, Value: Tile
var cities = {}  # 存储城市数据，Key: Vector2i, Value: City

func on_tile_clicked(map_pos: Vector2i) -> void:
	"""
	地块点击事件
	"""
	if grid.has(map_pos):
		map_render_layer.highlight_action(map_pos)
		if map_render_layer.get_tile_resource_name(map_pos) == "grass":
			map_render_layer.set_cell(map_pos, "plain")
	else:
		print_debug("No tile found at: " + str(map_pos))


func set_city(pos: Vector2i, local_pos: Vector2, city: City) -> void:
	"""
	设置城市，同时设置城市周围地块的城市归属
	"""
	assert(cities.has(pos) == false, "City already exists at: " + str(pos))
	grid[pos].sovereignty.set_city(city.city_name)
	city.set_city_position(pos, local_pos)
	# 设置城市周围地块的城市归属，根据城市规模而定
	if city.city_surrounding_tiles.size() == 0:
		city.city_surrounding_tiles.append(city.city_position)
	for level in range(city.city_scale):
		# 获取周围地块
		var new_surrounding_tiles = city.city_surrounding_tiles.duplicate()
		for old_pos in city.city_surrounding_tiles:
			# print("terrain  " ,terrain_render_layer.get_surrounding_cells(old_pos))
			for new_pos in map_render_layer.get_cell_surrounding_cells(old_pos, map_render_layer.tile_terrain_layer):
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


func test_city():
	var city = City.new()
	city.set_city_name("City1")
	city.set_city_sprite(Sprite2D.new())
	city.set_city_scale(City.CITY_SCALE.LARGE)
	var pos = Vector2i(3, 2)
	set_city(pos, map_render_layer.map_to_local(pos), city)
	
	city = cities[pos]
	print(city.city_surrounding_tiles.size())
	for p in city.city_surrounding_tiles:
		print_debug(p)
		map_render_layer.highlight_cell(p)


func _ready():
	visible = true
	initialize_logic_from_render()
	load_to_scene(grid)
	if map_render_layer:
		map_render_layer.connect("tile_clicked", on_tile_clicked)
	else:
		print("MapRenderLayer not found")
	
	
# 从 TileMapLayer 初始化逻辑层
func initialize_logic_from_render():
	# print(map_render_layer.get_used_cells(map_render_layer.tile_terrain_layer))
	for pos in map_render_layer.get_used_cells(map_render_layer.tile_terrain_layer):
		var terrain_name = map_render_layer.get_tile_resource_name(pos)
		# var size = terrain_render_layer.tile_set.tile_size
		print(terrain_name, pos)
		grid[pos] = Tile.new()
		grid[pos].tile_terrain = terrain_name



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


func _exit_tree() -> void:
	clear_scene(cities)
	clear_scene(grid)


