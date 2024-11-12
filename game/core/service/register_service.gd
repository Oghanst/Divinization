extends Node

# Register service
var registries:Dictionary = {}

func add_registry(registry_name:String, registry: Registry):
	registries[registry_name] = registry

func cleanup_registries()->void:
	for registry in registries:
		if registry.has("cleanup"):
			registry.cleanup()
		else:
			print("Warning: a registry must have cleanup method.")
	registries.clear()

func get_registry(registry_name:String) -> Registry:
	return registries[registry_name]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_registry("resource_registry", ResourceRegistry.new())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _exit_tree() -> void:
	cleanup_registries()
