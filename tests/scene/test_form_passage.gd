extends SceneTree
## Sweep each form through the actual sandbox tunnel collision geometry.
const SANDBOX := preload("res://scenes/levels/whitebox_sandbox.tscn")
const FORMS := [preload("res://features/forms/sprout.tres"), preload("res://features/forms/humanoid.tres"), preload("res://features/forms/mature.tres")]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source := SANDBOX.instantiate()
	for tunnel_path in ["Course/LowTunnel", "Course/FinalTunnel"]:
		var tunnel := source.get_node(tunnel_path).duplicate() as StaticBody2D
		root.add_child(tunnel)
		var ceiling := tunnel.get_node("CollisionShape2D") as CollisionShape2D
		var floor_path := "Geometry/StartFloor" if tunnel_path == "Course/LowTunnel" else "Geometry/FinalFloor"
		var floor_body := source.get_node(floor_path).duplicate() as StaticBody2D
		root.add_child(floor_body)
		var floor_shape := floor_body.get_node("CollisionShape2D") as CollisionShape2D
		var floor_top := floor_shape.position.y - (floor_shape.shape as RectangleShape2D).size.y * 0.5
		for form: FormDefinition in FORMS:
			var body := preload("res://features/player/player.tscn").instantiate() as Player
			root.add_child(body)
			body.set_physics_process(false)
			body.form_controller.restore_form(form.id)
			if form.collision_shape_kind == FormDefinition.CollisionShapeKind.CIRCLE:
				assert(body.collision_shape.shape is CircleShape2D)
			else:
				assert(body.collision_shape.shape is CapsuleShape2D)
			var half_width := (ceiling.shape as RectangleShape2D).size.x * 0.5
			body.position = Vector2(ceiling.position.x - half_width - 40.0, floor_top - 0.1)
			await physics_frame
			var blocked := body.test_move(body.global_transform, Vector2(half_width * 2.0 + 80.0, 0.0))
			if blocked == (form.id == &"sprout"):
				push_error("Unexpected tunnel clearance: %s / %s" % [tunnel_path, form.id])
				quit(1)
				return
			body.free()
		tunnel.free()
		floor_body.free()
	source.free()
	print("Both tunnels admit sprout and block the larger forms.")
	quit()
