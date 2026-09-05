extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/json_whitebox_level.tscn")
const B1_ID := "0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d"
const B2_ID := "bbbb4660-96d0-11f1-9ec0-d3fb842dd849"
const B3_ID := "59bb7020-96d0-11f1-9ec0-1f9ad61c57bc"
const B4_ID := "17ea7d40-96d0-11f1-9ec0-5b135eaa7d6d"
const C1_ID := "6eaa3900-96d0-11f1-a2bb-61a47c4c3084"
const C2_ID := "3005cb90-96d0-11f1-9ec0-231d9bef30a8"
const C3_ID := "3c92f320-96d0-11f1-9ec0-adb2f775b414"
const C4_ID := "44101060-96d0-11f1-9ec0-dd217176b5ba"
const C5_ID := "de356dc0-96d0-11f1-9ec0-15760920bd18"
const C6_ID := "322a3230-96d0-11f1-9ec0-65ba33f44fa8"
const BIG_WIND_ID := "ccedf6a0-96d0-11f1-9ec0-ed0fd8838cf2"
const CHECKPOINT_ID := "a8139720-96d0-11f1-9ec0-076994b461f9"
const SOURCE_PATH := "res://data/Yiguang.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node2D
	root.add_child(level)
	await physics_frame
	_assert_source_entities_built(level)
	var player := level.get_node("Player") as Player
	assert(level.call(&"get_entity", B1_ID) != null)
	assert(level.call(&"get_entity", B2_ID) != null)
	assert(level.call(&"get_entity", B3_ID) != null)
	assert(level.call(&"get_entity", B4_ID) != null)
	assert(level.call(&"get_entity", B4_ID).global_position.is_equal_approx(Vector2(-16.0, 160.0)))
	assert(level.call(&"get_entity", C1_ID) != null)
	assert(level.call(&"get_entity", C2_ID) != null)
	assert(level.call(&"get_entity", C3_ID) != null)
	assert(level.call(&"get_entity", C4_ID) != null)
	assert(level.call(&"get_entity", C5_ID) != null)
	assert(level.call(&"get_entity", C6_ID) != null)

	var wind := level.call(&"get_entity", BIG_WIND_ID) as Area2D
	assert(wind != null)
	assert((wind.get(&"zone_size") as Vector2).is_equal_approx(Vector2(976.0, 144.0)))
	assert(wind.global_position.is_equal_approx(Vector2(-256.0, 176.0)))

	var c3 := level.call(&"get_entity", C3_ID) as Node2D
	var c4 := level.call(&"get_entity", C4_ID) as Node2D
	var c3_ring := level.call(&"get_entity", "e638aaf0-96d0-11f1-9ec0-47d36b46fa53") as Node2D
	var b4 := level.call(&"get_entity", B4_ID) as Area2D
	assert(c3_ring.get_parent() == c3)
	assert(c3_ring.global_position.is_equal_approx(Vector2(168.0, -88.0)), "C3's Ring must remain hidden with C3.")
	assert(c3.global_position.is_equal_approx(Vector2(160.0, -160.0)))
	assert(c4.global_position.is_equal_approx(Vector2(48.0, -160.0)))
	await _press_button_with_player(player, b4, Vector2(-8.0, 176.0))
	await _wait_for_motion(c3)
	await _wait_for_motion(c4)
	assert(c3.global_position.is_equal_approx(Vector2(160.0, 0.0)))
	assert(c4.global_position.is_equal_approx(Vector2(48.0, 0.0)))
	assert(c3_ring.global_position.is_equal_approx(Vector2(168.0, 72.0)), "C3's Ring must descend with the cube.")

	var c5 := level.call(&"get_entity", C5_ID) as Node2D
	assert(c5.global_position.is_equal_approx(Vector2(176.0, 160.0)))
	await _press_button_with_player(player, level.call(&"get_entity", B3_ID) as Area2D, Vector2(680.0, 152.0))
	await _wait_for_motion(c5)
	assert(c5.global_position.is_equal_approx(Vector2(176.0, 288.0)))

	var c1 := level.call(&"get_entity", C1_ID) as Node2D
	await _press_button_with_player(player, level.call(&"get_entity", B1_ID) as Area2D, Vector2(456.0, 312.0))
	await _wait_for_motion(c1)
	assert(c1.global_position.is_equal_approx(Vector2(576.0, 272.0)))
	assert(is_equal_approx(c1.global_rotation, PI * 0.5))

	var c2 := level.call(&"get_entity", C2_ID) as Node2D
	var c6 := level.call(&"get_entity", C6_ID) as Node2D
	player.global_position = Vector2(580.0, 250.0)
	player.velocity = Vector2.ZERO
	wind.call(&"apply_to_actor", player, 0.5)
	assert(is_zero_approx(player.velocity.x), "C2/C6 must block wind before B2 is pressed.")
	var c2_c6_distance := c2.global_position.distance_to(c6.global_position)
	await _press_button_with_player(player, level.call(&"get_entity", B2_ID) as Area2D, Vector2(152.0, 312.0))
	for _step: int in range(4):
		await physics_frame
	assert(is_equal_approx(c2.global_position.distance_to(c6.global_position), c2_c6_distance), "C2 and C6 must remain rigidly linked while rotating.")
	await _wait_for_motion(c2)
	await _wait_for_motion(c6)
	assert(c2.global_position.is_equal_approx(Vector2(592.0, 176.0)))
	assert(c6.global_position.is_equal_approx(Vector2(528.0, 144.0)))
	player.global_position = Vector2(580.0, 250.0)
	player.velocity = Vector2.ZERO
	wind.call(&"apply_to_actor", player, 0.5)
	assert(player.velocity.x < 0.0, "Opened C2/C6 path must restore wind at the same height.")

	player.global_position = Vector2(168.0, 120.0)
	player.velocity = Vector2.ZERO
	assert(player.form_controller.restore_form(&"mature"))
	assert(player.abilities.toggle_primary(), "A mature player must be able to hook C3's descended Ring.")
	assert(player.abilities.is_vine_attached())
	var checkpoint := level.call(&"get_entity", CHECKPOINT_ID) as Area2D
	assert(checkpoint != null)
	checkpoint.call(&"activate", player)
	player.global_position = Vector2(0.0, 0.0)
	level.call(&"_on_hazard_actor_killed", player)
	assert(player.global_position.is_equal_approx(checkpoint.global_position), "A lethal hit must respawn at the activated checkpoint.")

	level.queue_free()
	quit()


func _wait_for_motion(node: Node) -> void:
	for _step: int in range(180):
		if not bool(node.call(&"is_moving")):
			return
		await physics_frame
	assert(false, "Whitebox moving cube did not reach its target within three seconds.")


func _press_button_with_player(player: Player, button: Area2D, position: Vector2) -> void:
	player.global_position = position
	player.velocity = Vector2.ZERO
	for _step: int in range(3):
		await physics_frame
	assert(button.call(&"is_pressed"), "The player must be able to activate the mapped button.")


func _assert_source_entities_built(level: Node2D) -> void:
	var source_text := FileAccess.get_file_as_string(SOURCE_PATH)
	var parser := JSON.new()
	assert(parser.parse(source_text) == OK)
	var data := parser.data as Dictionary
	var mapped_count := 0
	for raw_level: Variant in data.get("levels", []):
		var source_level := raw_level as Dictionary
		for raw_layer: Variant in source_level.get("layerInstances", []):
			var layer := raw_layer as Dictionary
			if layer.get("__identifier", "") != "Entities":
				continue
			for raw_entity: Variant in layer.get("entityInstances", []):
				var entity := raw_entity as Dictionary
				var identifier := String(entity.get("__identifier", ""))
				match identifier:
					"Start", "Camera":
						continue
					"GrowDrug", "UnGrowDrug", "Frog", "Door", "Button", "DamageMachine", "Wind", "Ring", "MoveableCube", "Checkpoint":
						mapped_count += 1
						var runtime_entity := level.call(&"get_entity", String(entity.get("iid", ""))) as Node
						assert(runtime_entity != null, "Missing source entity: %s" % identifier)
						_assert_instance_size(identifier, entity, runtime_entity)
					_:
						assert(false, "Unhandled source entity type: %s" % identifier)
	assert(mapped_count > 0)


func _assert_instance_size(identifier: String, source_entity: Dictionary, runtime_entity: Node) -> void:
	var expected_size := Vector2(float(source_entity.get("width", 0)), float(source_entity.get("height", 0)))
	if identifier == "Button":
		assert((runtime_entity.get(&"button_size") as Vector2).is_equal_approx(expected_size))
		return
	if identifier == "Door" or identifier == "MoveableCube":
		assert(runtime_entity is AnimatableBody2D)
		var cube_collision := runtime_entity.get_node("CollisionShape2D") as CollisionShape2D
		assert((cube_collision.shape as RectangleShape2D).size.is_equal_approx(expected_size))
		return
	if not identifier in ["GrowDrug", "UnGrowDrug", "Frog", "Wind", "Checkpoint"]:
		return
	assert(runtime_entity is Area2D)
	var collision := runtime_entity.get_node("CollisionShape2D") as CollisionShape2D
	assert((collision.shape as RectangleShape2D).size.is_equal_approx(expected_size), "Instance size mismatch: %s" % identifier)
