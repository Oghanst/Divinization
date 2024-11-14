extends Object
class_name PopulationComponent

var population: Dictionary = {}
# population 模版
# {
# 	"population": 20,
# 	"residency": 100,
# 	"food_consumption_coef": 1.0,
# }

var basic_productivity: int = 5
const DEFAULT_PRODUCTIVITY_COEF: float = 1.0
const DEFAULT_POPULATION_REGENERATE_COEF: float = 0.2

func _init(config: Dictionary) -> void:
    """
    初始化人口组件
    """
    population = config


func add_property_value(property_name: String, value: int) -> void:
    """
    添加人口属性
    """
    assert(population.has(property_name), "Property not found: " + property_name)
    population[property_name] += value

func get_property_value(property_name: String):
    """
    获取人口属性
    """
    assert(population.has(property_name), "Property not found: " + property_name)
    return population[property_name]

func regenerate_population(regenerate_coef: float = DEFAULT_POPULATION_REGENERATE_COEF) -> void:
    """
    人口增长
    """
    var current_population:int = get_property_value("population")
    var residency:int = get_property_value("residency")
    var increase_population: int = int(UtilFunctions.s_shape_regenerate(current_population, residency, regenerate_coef))
    var new_population:int = clamp(current_population + increase_population, 0, residency)
    population["population"] = new_population

func set_basic_productivity(value: int) -> void:
    """
    设置基础生产力
    """
    basic_productivity = value

func get_basic_productivity() -> int:
    """
    获取基础生产力
    """
    return basic_productivity

func compute_productivity(productivity_coef: float = DEFAULT_PRODUCTIVITY_COEF) -> int:
    """
    计算人口生产力，其他组件通过修改 productivity_coef 来影响生产力
    """
    var current_population:int = get_property_value("population")
    var productivity:int = int(current_population * productivity_coef) * basic_productivity
    return productivity
 
func consume_food() -> int:
    """
    消耗食物，返回消耗的食物数量，正数
    """
    var food_consumption_coef: float = get_property_value("food_consumption_coef")
    var food_consumption: int = int(get_property_value("population") * food_consumption_coef)
    return food_consumption
