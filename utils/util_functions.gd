extends Node

func s_shape_regenerate(stock: int, capacity: int, regen_coef: float) -> int:
	"""
	S形增长，基于当前数目和最大容量，在容量的一半时增长最快，基数是当前数目，适用于人口的增长
	"""
	var regen_amount = int( (1-(float)(stock)/(float)(capacity)) * regen_coef * stock )
	return regen_amount

func linear_regenerate(stock: int, _capacity: int, regen_coef: float) -> int:
	"""
	线性增长，基于当前数目和最大容量，适用于资源的增长
	"""
	var regen_amount = int( regen_coef * stock )
	return regen_amount

func get_dir_contents(path: String) -> Array[String]:
	"""
	获取指定目录下的所有文件，非递归
	"""
	var dir = DirAccess.open(path)
	var contents = []

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				contents.append(path + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

	return contents