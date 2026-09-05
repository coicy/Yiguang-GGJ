extends SceneTree
const LEVEL_SCENE := preload("res://scenes/levels/Level_main.tscn")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var main := LEVEL_SCENE.instantiate()
	root.add_child(main)
	await process_frame # Wait for PhantomCameraHost registration.
	await physics_frame
	var level := main.get_node("Level01") as GreenhouseLevel
	assert(level != null, "Main wraps the production greenhouse")
	assert(level.get_node_or_null("NurseryRoom/Foundation/Collision") != null)
	assert(level.get_node_or_null("Actors/Player") != null)
	assert(level.encounters.size() == 8)
	var camera := level.get_node("Camera2D") as Camera2D
	assert(camera.enabled)
	var host := camera.get_node("PhantomCameraHost") as PhantomCameraHost
	var phantom := level.get_node("PhantomCamera2D") as PhantomCamera2D
	assert(level.current_room != null)
	assert(host.get_active_pcam() == level._room_cameras[level.current_room])
	assert(phantom.follow_mode == PhantomCamera2D.FollowMode.FRAMED)
	assert(phantom.follow_target == level.get_node("Actors/Player"))
	assert(is_equal_approx(phantom.dead_zone_width, 0.6))
	assert(is_equal_approx(phantom.dead_zone_height, 0.52))
	assert(phantom.lookahead)
	assert(camera.zoom.is_equal_approx(Vector2(2.5,2.5)))
	var bounds := (level.get_node("CameraBounds") as CameraBounds).get_world_rect()
	assert(camera.limit_left == int(bounds.position.x) and camera.limit_top == int(bounds.position.y))
	assert(camera.limit_right == int(bounds.end.x) and camera.limit_bottom == int(bounds.end.y))
	main.queue_free()
	quit()
