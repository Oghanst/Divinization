# AttributeType.gd
extends Resource
class_name AttributeType

# 属性类别
enum Category {
    MAGIC,
    PHYSICAL
}

# 魔法属性枚举
enum MagicType {
    WIND,
    EARTH,
    WATER,
    FIRE,
    LIGHT,
    DARK
}

# 物理属性枚举
enum PhysicalType {
    PIERCING,
    SLASHING,
    CRUSHING,
    RENDING
}
