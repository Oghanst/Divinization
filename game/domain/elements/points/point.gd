extends Resource
class_name Point

@export var point_id: int
@export var name: String
@export var description: String
@export var quantity: int
@export var max_quantity: int = -1

func consume(amount: int) -> bool:
    if quantity >= amount:
        quantity -= amount
        return true
    else:
        return false

func add(amount: int) -> bool:
    if max_quantity < 0 or quantity + amount <= max_quantity:
        quantity += amount
        return true
    else:
        return false

func consume_or_clear(amount: int) -> int:
    """
    消耗指定数量的点数，返回无法被消耗掉的部分（也就是余数）
    """
    if quantity >= amount:
        quantity -= amount
        return 0
    else:
        var diff = amount - quantity
        quantity = 0
        return diff

func add_or_fill(amount: int) -> int:
    """
    将点数增加指定数量，返回不能被增加的部分（也就是余数）
    """
    if max_quantity < 0 or quantity + amount <= max_quantity:
        quantity += amount
        return 0
    else:
        var diff = max_quantity - quantity
        quantity = max_quantity
        return amount - diff

func get_quantity() -> int:
    return quantity
