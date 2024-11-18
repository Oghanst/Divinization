extends Object
class_name AttributeSystem

var max_damage_coefficient:float = 100.0

func _init() -> void:
	"""
	初始化属性系统
	"""
	print("AttributeSystem ready")

func yield_defense_attribute_general(magic_defense:int, physical_defense:int)->CompoundAttribute:
	"""
	一个类型的防御用一个值表示，用于通用设定
	"""
	var compound_attribute = CompoundAttribute.new()
	for key in AttributeType.MagicType.keys():
		compound_attribute.set_attribute_value(AttributeType.Category.MAGIC, key.to_lower(), magic_defense)
	for key in AttributeType.PhysicalType.keys():
		compound_attribute.set_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower(), physical_defense)
	return compound_attribute

func yield_defense_attribute(magic_defense:Dictionary, physical_defense:Dictionary)->CompoundAttribute:
	"""
	一个类型的防御用一个字典表示，用于特殊设定
	"""
	var compound_attribute = CompoundAttribute.new()
	for key in magic_defense.keys():
		if not AttributeType.MagicType.has(key):
			continue
		compound_attribute.set_attribute_value(AttributeType.Category.MAGIC, key.to_lower(), magic_defense[key])
	for key in physical_defense.keys():
		if not AttributeType.PhysicalType.has(key):
			continue
		compound_attribute.set_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower(), physical_defense[key])
	return compound_attribute

func yield_attack_attribute_general(magic_attack:int, physical_attack:int)->CompoundAttribute:
	"""
	一个类型的攻击用一个值表示，用于通用设定
	"""
	var compound_attribute = CompoundAttribute.new()
	for key in AttributeType.MagicType.keys():
		compound_attribute.set_attribute_value(AttributeType.Category.MAGIC, key.to_lower(), magic_attack)
	for key in AttributeType.PhysicalType.keys():
		compound_attribute.set_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower(), physical_attack)
	return compound_attribute

func yield_attack_attribute(magic_attack:Dictionary, physical_attack:Dictionary)->CompoundAttribute:
	"""
	一个类型的攻击用一个字典表示，用于特殊设定
	"""
	var compound_attribute = CompoundAttribute.new()
	for key in magic_attack.keys():
		if not AttributeType.MagicType.has(key):
			continue
		compound_attribute.set_attribute_value(AttributeType.Category.MAGIC, key.to_lower(), magic_attack[key])
	for key in physical_attack.keys():
		if not AttributeType.PhysicalType.has(key):
			continue
		compound_attribute.set_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower(), physical_attack[key])
	return compound_attribute

func compute_damage_coefficient(defense:int)->float:
	"""
	计算伤害系数，defense的值决定减伤率
	"""
	var defense_exp = exp(float(defense))
	if defense_exp == 0:
		return max_damage_coefficient
	return min(max_damage_coefficient, 1.0/defense_exp)
		

func compute_damage(attack:CompoundAttribute, defense:CompoundAttribute)->int:
	"""
	计算伤害，defense的值决定减伤率
	"""
	var damage:int = 0
	for key in AttributeType.MagicType.keys():
		var magic_damage = attack.get_attribute_value(AttributeType.Category.MAGIC, key.to_lower())
		var magic_defense = defense.get_attribute_value(AttributeType.Category.MAGIC, key.to_lower())
		var magic_damage_coefficient = compute_damage_coefficient(magic_defense)
		damage += int(magic_damage * magic_damage_coefficient)
	for key in AttributeType.PhysicalType.keys():
		var physical_damage = attack.get_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower())
		var physical_defense = defense.get_attribute_value(AttributeType.Category.PHYSICAL, key.to_lower())
		var physical_damage_coefficient = compute_damage_coefficient(physical_defense)
		damage += int(physical_damage * physical_damage_coefficient)
	return damage