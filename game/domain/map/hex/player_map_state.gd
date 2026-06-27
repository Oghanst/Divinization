extends RefCounted
class_name PlayerMapState

var turn: int = 1
var player_coord := Vector2i.ZERO
var selected_coord := Vector2i.ZERO
var max_action_points: int = 3
var action_points: int = 3
var life: int = 8
var max_life: int = 10
var experience: int = 0
var level: int = 1
var inventory: Dictionary = {}
var sanity_status: String = "稳定"
var secrecy_status: String = "隐匿"
var secrecy_pressure: int = 2
var global_resources := {
	"faith": 4,
	"materials": 1,
	"followers": 3,
}
var event_key: String = "plague_outbreak"
var event_countdown: int = 6
var event_summary: String = "瘟疫将在 6 回合后全面爆发"


func reset_action_points() -> void:
	action_points = max_action_points


func can_spend_action_points(cost: int) -> bool:
	return action_points >= cost


func spend_action_points(cost: int) -> bool:
	if not can_spend_action_points(cost):
		return false
	action_points -= cost
	return true


func change_global_resource(key: String, delta: int) -> void:
	if key.is_empty():
		return
	global_resources[key] = max(0, int(global_resources.get(key, 0)) + delta)


func add_item(item_id: String, quantity: int = 1) -> void:
	if item_id.is_empty() or quantity <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + quantity


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	var current := int(inventory.get(item_id, 0))
	if current < quantity:
		return false
	current -= quantity
	if current <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = current
	return true


func heal(amount: int) -> int:
	var before := life
	life = min(max_life, life + max(0, amount))
	return life - before


func change_secrecy_pressure(delta: int) -> void:
	secrecy_pressure = max(0, secrecy_pressure + delta)
	secrecy_status = "隐匿" if secrecy_pressure == 0 else "被追踪"
