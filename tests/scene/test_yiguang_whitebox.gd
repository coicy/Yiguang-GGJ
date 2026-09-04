extends SceneTree

const LEVEL: PackedScene = preload("res://scenes/levels/yiguang_whitebox.tscn")
const GLOBAL_SIGNAL_BUS_SCRIPT := preload("res://autoloads/global_signal_bus.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var signal_bus := root.get_node_or_null("GlobalSignalBus")
	var created_signal_bus := false
	if signal_bus == null:
		signal_bus = GLOBAL_SIGNAL_BUS_SCRIPT.new()
		signal_bus.name = "GlobalSignalBus"
		root.add_child(signal_bus)
		created_signal_bus = true

	var level := LEVEL.instantiate() as YiguangWhitebox
	root.add_child(level)
	await process_frame

	assert(level.get_player() != null)
	assert(level.get_player().global_position == Vector2(16, 928))
	assert(level.terrain.get_used_cells().size() == 168)
	assert(level.terrain.get_cell_source_id(Vector2i(37, 11)) == -1)
	assert(level.terrain.tile_set.get_physics_layers_count() == 1)
	var atlas := level.terrain.tile_set.get_source(0) as TileSetAtlasSource
	assert(atlas.get_tile_data(Vector2i(0, 0), 0).get_collision_polygons_count(0) == 1)
	assert(atlas.get_tile_data(Vector2i(1, 0), 0).get_collision_polygons_count(0) == 0)
	assert(level.get_node("Geometry/MovingPlatforms").get_child_count() == 5)
	assert(level.get_node("VineAnchors").get_child_count() == 7)
	assert(level.get_node("WindZones").get_child_count() == 2)
	assert(level.get_node("Interactions/GrowDrugA").position == Vector2(272, 896))
	assert(level.get_node("Interactions/GrowDrugB").position == Vector2(752, 912))
	assert(level.get_node("Interactions/GrowDrugC").position == Vector2(1072, 784))
	assert(level.get_node("Interactions/UnGrowDrugA").position == Vector2(400, 896))
	assert(level.get_node("Interactions/UnGrowDrugB").position == Vector2(1136, 912))
	assert(level.lower_checkpoint.position == Vector2(688, 928))
	assert(level.upper_checkpoint.position == Vector2(848, 608))
	assert(level.exit_goal.position == Vector2(1280, 928))

	level.lower_switch.activate_for_test()
	level.middle_switch.activate_for_test()
	level.upper_switch.activate_for_test()
	await process_frame
	assert(level.linked_lift.is_active())
	assert(level.middle_platform.is_active())
	assert(level.bridge_platform.is_active())
	assert(level.top_lift_a.is_active())
	assert(level.top_lift_b.is_active())
	assert(level.exit_goal.is_unlocked())

	level.restart_level()
	assert(not level.is_completed())
	assert(not level.lower_switch.is_active())
	assert(not level.middle_switch.is_active())
	assert(not level.upper_switch.is_active())

	level.free()
	if created_signal_bus:
		signal_bus.free()
	quit()
