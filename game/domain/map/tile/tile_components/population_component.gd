extends Object
class_name PopulationComponent

var population: Dictionary = {}
# population 模版
# {
# 	"population": {

func _init(config: Dictionary) -> void:
    """
    初始化人口组件
    """
    population = config

