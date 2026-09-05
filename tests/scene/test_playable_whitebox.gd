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
	assert(level.get_node("Course/LegStep") != null)
	assert(level.get_node("Course/HighSwitch") != null)
	assert(level.get_node("Course/VineSection/VineAnchor") != null)
	assert(level.get_node("Course/ToxinSection/ToxinZone") != null)
	assert(level.get_node("Course/FinalLowSwitch") != null)
	var wind_zone := level.get_node("Course/WindSection/WindZone") as WindZone
	var wind_hazard := level.get_node("Course/WindSection/WindHazard") as Hazard
	var hazard_collision := wind_hazard.get_node("CollisionShape2D") as CollisionShape2D
	var hazard_shape := hazard_collision.shape as RectangleShape2D
	var step_collision := level.get_node("Course/LegStep/CollisionShape2D") as CollisionShape2D
	var step_shape := step_collision.shape as RectangleShape2D
	var hazard_right := hazard_collision.global_position.x + hazard_shape.size.x * 0.5
	var step_left := step_collision.global_position.x - step_shape.size.x * 0.5
	assert(step_left - hazard_right >= 64.0)
	var high_switch_label := level.get_node("Course/HighSwitchLabel") as Label
	assert(high_switch_label.global_position.x >= wind_zone.global_position.x + 212.0)

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
	# Let queued nodes and the audio mixer release stopped playback before shutdown.
	await process_frame
	await create_timer(0.1).timeout
	quit()
