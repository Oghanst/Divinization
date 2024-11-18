extends InfoModule
class_name TreeInfoModule

var component: Tree = null

func get_info_component():
	return component

func update_info(info: Dictionary):
	component.clear()
	var item = component.create_item()
	item.set_text(0, self.info_name)
	item.set_collapsed_recursive(false)
	update_info_dfs(info, component.get_root())

func update_info_dfs(info: Dictionary, parent: TreeItem):
	for key in info.keys():
		if info[key] is not Dictionary:
			var item = component.create_item(parent)
			item.set_text(0, key)
			item.set_text(1, str(info[key]))
		else:
			var item = component.create_item(parent)
			item.set_text(0, key)
			update_info_dfs(info[key], item)

func _init(in_info_name: String ="TreeInfoModule"):
	self.info_name = in_info_name
	self.component = Tree.new()
	self.component.columns = 2
	self.component.set_column_expand(0, true)
	self.component.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 水平方向扩展
	self.component.size_flags_vertical = Control.SIZE_EXPAND_FILL    # 垂直方向扩展

func _ready() -> void:
	assert(component!=null, "component is not set")
