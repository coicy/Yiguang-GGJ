extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/Level_main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_main := LEVEL_SCENE.instantiate() as Node2D
	root.add_child(level_main)
	await physics_frame

	var level := level_main.get_node("Level01") as HandbuiltLevel
	assert(level != null, "Level_main must wrap the authoritative playable hand-built level.")
	assert(level.get_node_or_null("Geometry/Terrain/StartFloor") != null)
	assert(level.get_node_or_null("Actors/Player") != null)

	var camera := level.get_node("Actors/Player/Camera2D") as Camera2D
	assert(camera.limit_smoothed)
	assert(camera.limit_left == -414 and camera.limit_top == 190)
	assert(camera.limit_right == 1086 and camera.limit_bottom == 690)
	var phantom := level.get_node("PhantomCamera2D") as PhantomCamera2D
	assert(phantom != null)
	assert(phantom.follow_mode == PhantomCamera2D.FollowMode.FRAMED)
	assert(phantom.zoom.is_equal_approx(Vector2(3.0, 3.0)))
	assert(is_equal_approx(phantom.dead_zone_width, 0.6))
	assert(is_equal_approx(phantom.dead_zone_height, 0.52))

	level_main.queue_free()
	quit()
