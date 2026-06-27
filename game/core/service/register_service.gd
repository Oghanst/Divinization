extends Node

# Registery service
var registries:Dictionary = {}

func add_registry(registry_name:String, registry: Registry):
	registries[registry_name] = registry

func cleanup_registries()->void:
	for registry_name in registries:
		var registry = registries[registry_name]
		if registry.has_method("cleanup"):
			registry.cleanup()
		else:
			print("WARNING: a registry must have cleanup method.")
		registry.free()
	registries.clear()

func get_registry(registry_name:String) -> Registry:
	return registries[registry_name]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_registry("resource_registry", ResourceRegistry.new())
	add_registry("resource_component_factory", ResourceComponentFactory.new())
	add_registry("population_component_factory", PopulationComponentFactory.new())
	add_registry("sovereignty_component_factory", SovereigntyComponentFactory.new())
	add_registry("terrain_registry", TerrainRegistry.new())


func _exit_tree() -> void:
	cleanup_registries()
