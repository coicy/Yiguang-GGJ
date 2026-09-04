extends SceneTree

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

	var level := preload("res://scenes/levels/whitebox_sandbox.tscn").instantiate() as WhiteboxSandbox
	root.add_child(level)
	await process_frame
	var player := level.get_player()
	assert(player != null)
	assert(player.current_form_id() == &"sprout")
	assert(level.get_node("Course/LowTunnel") != null)
	assert(level.get_node("Course/WindSection/WindZone") != null)
	assert(level.get_node("Course/HighSwitch") != null)
	assert(level.get_node("Course/VineSection/VineAnchor") != null)
	assert(level.get_node("Course/ToxinSection/ToxinZone") != null)
	assert(level.get_node("Course/FinalLowSwitch") != null)

	var initial := player.capture_state()
	level.activate_checkpoint_for_test(&"mid")
	player.form_controller.restore_form(&"mature")
	level.respawn_player()
	assert(player.current_form_id() == level.checkpoint_form_id())
	level.restart_level()
	assert(player.current_form_id() == initial["form"])
	assert(not level.is_completed())

	level.complete_level()
	assert(not level.is_completed())
	var high_switch := level.get_node("Course/HighSwitch") as AbilitySwitch
	var final_switch := level.get_node("Course/FinalLowSwitch") as AbilitySwitch
	high_switch.activate_for_test()
	final_switch.activate_for_test()
	level.complete_level()
	assert(level.is_completed())

	level.free()
	if created_signal_bus:
		signal_bus.free()
	quit()
