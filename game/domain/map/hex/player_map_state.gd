extends RefCounted
class_name PlayerMapState

var turn: int = 1
var player_coord := Vector2i.ZERO
var selected_coord := Vector2i.ZERO
var max_action_points: int = 3
var action_points: int = 3
var life: int = 24
var max_life: int = 24
var experience: int = 0
var level: int = 1
var ascension_tier: int = 0
var ascension_route: String = ""
var power_card_upgraded: bool = false
var inventory: Dictionary = {}
var sanity_status: String = "稳定"
var secrecy_status: String = "隐匿"
var secrecy_pressure: int = 2
var organization_hunt_pending: bool = false
var crisis_active: bool = false
var stage_resolved: bool = false
var stage_result_id: String = ""
var stage_reward_pending: bool = false
var stage_reward_claimed: bool = false
var stage_reward_options: Array = []
var stage_node_pending: bool = false
var stage_node_options: Array = []
var stage_node_id: String = "sick_village"
var stage_node_name: String = "病村"
var route_affinity := {
	"life": 0,
	"faith": 0,
	"death": 0,
	"secret": 0,
}
var route_bonus_threshold_mods := {
	"life": 0,
	"faith": 0,
	"death": 0,
	"secret": 0,
}
var global_resources := {
	"faith": 0,
	"materials": 1,
	"followers": 0,
	"cult_cells": 0,
	"apostles": 0,
}
var event_key: String = "plague_outbreak"
var event_countdown: int = 5
var event_countdown_template: String = "溃疡使徒将在 {countdown} 回合后抵达"
var event_crisis_summary: String = "关底战：溃疡使徒抵达"
var event_crisis_log: String = "阶段事件：溃疡使徒抵达。病势、病源线索与初生锚点将决定关底战强度和胜利方式。"
var event_summary: String = "溃疡使徒将在 5 回合后抵达"


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


func take_damage(amount: int) -> int:
	var before := life
	life = max(0, life - max(0, amount))
	return before - life


func gain_experience(amount: int) -> void:
	experience += max(0, amount)
	while experience >= level * 5:
		experience -= level * 5
		level += 1


func complete_first_ascension(route_id: String) -> void:
	if ascension_tier >= 1:
		return
	ascension_tier = 1
	ascension_route = route_id
	level = max(level, 2)
	max_life += 2
	heal(2)


func change_route_affinity(route_id: String, delta: int) -> void:
	if route_id.is_empty():
		return
	route_affinity[route_id] = max(0, int(route_affinity.get(route_id, 0)) + delta)


func change_route_bonus_threshold(route_id: String, delta: int) -> void:
	if route_id.is_empty():
		return
	route_bonus_threshold_mods[route_id] = int(route_bonus_threshold_mods.get(route_id, 0)) + delta
