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
	var switch_a := sandbox.get_node("Interactions/SwitchA") as WhiteboxSwitch
	assert(player_anchor != null, "Sandbox must expose a PlayerAnchor marker.")
	assert(switch_a != null, "Sandbox must expose SwitchA.")

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

	global_signal_bus.disconnect(&"level_completed", _on_level_completed)
	sandbox.free()
	if created_global_signal_bus:
		global_signal_bus.free()
	quit()


func _on_level_completed(_level_id: StringName) -> void:
	_completed_level_count += 1
