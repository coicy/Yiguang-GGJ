extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node2D
	root.add_child(level)
	await physics_frame

	assert(Engine.has_singleton("PhantomCameraManager"))
	var manager := root.get_node_or_null("PhantomCameraManager")
	assert(manager != null)

	var camera := level.get_node("Actors/Player/Camera2D") as Camera2D
	var host := camera.get_node("PhantomCameraHost") as PhantomCameraHost
	var phantom := level.get_node("PhantomCamera2D") as PhantomCamera2D
	var bounds := level.get_node("CameraBounds") as CameraBounds
	assert(host != null)
	assert(phantom != null)
	assert(phantom.follow_mode == PhantomCamera2D.FollowMode.FRAMED)
	assert(is_instance_valid(phantom.follow_target))
	assert(phantom.follow_target.name == "Player")
	assert(is_equal_approx(phantom.dead_zone_width, 0.6))
	assert(is_equal_approx(phantom.dead_zone_height, 0.52))
	assert(phantom.lookahead)
	assert(phantom.limit_left == int(bounds.get_world_rect().position.x))
	assert(phantom.limit_top == int(bounds.get_world_rect().position.y))
	assert(phantom.limit_right == int(bounds.get_world_rect().end.x))
	assert(phantom.limit_bottom == int(bounds.get_world_rect().end.y))

	level.queue_free()
	print("PASS: Phantom Camera integration, adjustable deadzone, look-ahead and CameraBounds limits")
	quit()
