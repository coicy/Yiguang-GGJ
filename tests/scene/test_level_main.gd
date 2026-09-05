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
	assert(camera.zoom.is_equal_approx(Vector2(4.0, 4.0)))
	assert(camera.limit_smoothed)
	assert(camera.position_smoothing_enabled)
	assert(camera.limit_left == -256 and camera.limit_top == -128)
	assert(camera.limit_right == 1088 and camera.limit_bottom == 640)

	level_main.queue_free()
	quit()
