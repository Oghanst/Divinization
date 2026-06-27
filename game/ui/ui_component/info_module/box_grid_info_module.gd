extends InfoModule
class_name BoxGridInfoModule

var component: BoxContainer = null

func get_info_component():
	return component

func update_info(info: Dictionary):
	
	for key in info.keys():
		var node = component.get_node_or_null("Grid/" + key)
		if !node:
			var grid:GridContainer = component.get_node("Grid")
			var label_title: Label = Label.new()
			var label_content: Label = Label.new()
			label_title.name = "Title"+key
			label_title.text = key
			label_content.name = key
			label_content.text = str(info[key])
			grid.add_child(label_title)
			grid.add_child(label_content)
		else:
			node.text = str(info[key])
		# for child in component.get_node("Grid").get_children():
		# 	print(child.name)


func construct_component():
	component = BoxContainer.new()
	var title: Label = Label.new()
	title.text = self.info_name
	component.add_child(title)
	var grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	component.add_child(grid)
	component.vertical = true
	# print("init ok")

func _init(in_info_name: String ="BoxGridInfoModule"):
	self.info_name = in_info_name
	construct_component()

func _ready() -> void:
	assert(component!=null, "component is not set")
