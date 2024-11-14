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
