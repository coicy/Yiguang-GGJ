extends SceneTree

const SANDBOX: PackedScene = preload("res://scenes/levels/whitebox_sandbox.tscn")
const GLOBAL_SIGNAL_BUS_SCRIPT := preload("res://autoloads/global_signal_bus.gd")

var _completed_level_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var global_signal_bus: Node = root.get_node_or_null("GlobalSignalBus")
	var created_global_signal_bus: bool = false
	if global_signal_bus == null:
		global_signal_bus = GLOBAL_SIGNAL_BUS_SCRIPT.new()
		global_signal_bus.name = "GlobalSignalBus"
		root.add_child(global_signal_bus)
		created_global_signal_bus = true
	global_signal_bus.connect(&"level_completed", _on_level_completed)

	var sandbox: Variant = SANDBOX.instantiate()
	root.add_child(sandbox)

	var player_anchor := sandbox.get_node("Actors/PlayerAnchor") as Marker2D
	var nutrition_tank := sandbox.get_node_or_null("Interactions/NutritionTank") as Area2D
	var toxin_zone := sandbox.get_node_or_null("Interactions/ToxinZone") as Area2D
	var switch_a := sandbox.get_node("Interactions/SwitchA") as WhiteboxSwitch
	var exit_device := sandbox.get_node_or_null("Interactions/ExitDevice") as ExitDevice
	var switch_marker := sandbox.get_node_or_null("Interactions/SwitchA/PositionMarker") as Marker2D
	var exit_marker := sandbox.get_node_or_null("Interactions/ExitDevice/PositionMarker") as Marker2D
	var start_checkpoint := sandbox.get_node_or_null("Checkpoints/StartCheckpoint") as Area2D
	var mid_checkpoint := sandbox.get_node_or_null("Checkpoints/MidCheckpoint") as Area2D
	var fall_hazard := sandbox.get_node_or_null("Hazards/FallHazard") as Area2D
	assert(player_anchor != null, "Sandbox must expose a PlayerAnchor marker.")
	assert(nutrition_tank != null, "Sandbox must instance NutritionTank under Interactions.")
	assert(toxin_zone != null, "Sandbox must instance ToxinZone under Interactions.")
	assert(switch_a != null, "Sandbox must expose SwitchA.")
	assert(exit_device != null, "Sandbox must expose ExitDevice under Interactions.")
	assert(switch_marker != null, "SwitchA must expose a whitebox position marker.")
	assert(exit_marker != null, "ExitDevice must expose a whitebox position marker.")
	assert(start_checkpoint != null, "Sandbox must instance StartCheckpoint.")
	assert(mid_checkpoint != null, "Sandbox must instance MidCheckpoint.")
	assert(fall_hazard != null, "Sandbox must instance FallHazard.")
	assert(nutrition_tank.collision_layer == 64 and nutrition_tank.collision_mask == 2, "NutritionTank must use Interactable layer/mask.")
	assert(toxin_zone.collision_layer == 64 and toxin_zone.collision_mask == 2, "ToxinZone must use Interactable layer/mask.")
	assert(start_checkpoint.collision_layer == 64 and start_checkpoint.collision_mask == 2, "StartCheckpoint must use Interactable layer/mask.")
	assert(mid_checkpoint.collision_layer == 64 and mid_checkpoint.collision_mask == 2, "MidCheckpoint must use Interactable layer/mask.")
	assert(fall_hazard.collision_layer == 32 and fall_hazard.collision_mask == 2, "FallHazard must use Hazard layer/mask.")
	assert(player_anchor.position == Vector2(96, 576), "PlayerAnchor must start at the whitebox start position.")
	assert(mid_checkpoint.position == Vector2(640, 576), "MidCheckpoint must have a fixed whitebox position.")
	assert(switch_marker.position == Vector2(832, 560), "SwitchA must have a fixed whitebox position.")
	assert(exit_marker.position == Vector2(1120, 560), "ExitDevice must have a fixed whitebox position.")
	assert(fall_hazard.position == Vector2(1248, 704), "FallHazard must have a fixed whitebox position.")

	var checkpoint_position: Vector2 = sandbox.get_checkpoint_position()
	switch_a.activate()
	sandbox.reset_level()
	assert(not switch_a.is_active(), "Reset must deactivate sandbox mechanisms.")
	assert(player_anchor.global_position == checkpoint_position, "Reset must restore PlayerAnchor to the checkpoint.")

	sandbox.complete_level()
	assert(_completed_level_count == 0, "Closed exits must not complete the level.")
	switch_a.activate()
	sandbox.complete_level()
	assert(_completed_level_count == 1, "An open exit must complete the level once.")
	sandbox.complete_level()
	assert(_completed_level_count == 1, "Completing an already completed level must be idempotent.")
	sandbox.reset_level()
	switch_a.activate()
	sandbox.complete_level()
	assert(_completed_level_count == 2, "Resetting a completed level must allow a later completion event.")

	global_signal_bus.disconnect(&"level_completed", _on_level_completed)
	root.remove_child(global_signal_bus)
	sandbox.reset_level()
	switch_a.activate()
	sandbox.complete_level()
	root.add_child(global_signal_bus)
	global_signal_bus.connect(&"level_completed", _on_level_completed)
	sandbox.complete_level()
	assert(_completed_level_count == 3, "A missing signal bus must not consume the completion event.")
	sandbox.free()
	global_signal_bus.disconnect(&"level_completed", _on_level_completed)
	if created_global_signal_bus:
		global_signal_bus.free()
	quit()


func _on_level_completed(_level_id: StringName) -> void:
	_completed_level_count += 1
