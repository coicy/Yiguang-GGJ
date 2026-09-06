extends SceneTree
## Verify the combined level shares lifecycle, view and boundary collision.

const LEVEL_SCENE_PATH: String = "res://scenes/levels/Level_main.tscn"
const CAMERA_RECT := Rect2(-1024.0, -1216.0, 2816.0, 1920.0)
const SHARED_FLOOR_RECT := Rect2(-262.0, -3.0, 1344.0, 40.0)

var _checks: int = 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(main)
	var lifecycle_script: Script = load("res://features/level/handbuilt/handbuilt_level.gd") as Script
	var level := main.get_node_or_null("Level01") as Node2D
	var upper := main.get_node_or_null("Level01/Level02") as Node2D
	_expect(level != null and upper != null, "Level Main nests restored content under the playable Level01")
	if level == null or upper == null:
		main.queue_free()
		_finish()
		return
	_expect(level.scene_file_path == "res://scenes/levels/level_01.tscn", "Main loads the authoritative Level01 path despite legacy duplicate UIDs")
	var player := level.get_node("Actors/Player") as Player
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var counts: Dictionary = {"player": 0, "camera": 0, "phantom": 0, "hud": 0, "lifecycle": 0, "event_bus": 0, "light": 0}
	for node: Node in main.find_children("*", "", true, false):
		if node is Player:
			counts["player"] += 1
		if node is Camera2D:
			counts["camera"] += 1
		if node is PhantomCamera2D:
			counts["phantom"] += 1
		if node is MainLevelHud:
			counts["hud"] += 1
		if node.get_script() == lifecycle_script:
			counts["lifecycle"] += 1
		if node is LevelEventBus:
			counts["event_bus"] += 1
		if node is CanvasModulate:
			counts["light"] += 1
	for component: String in counts:
		_expect(int(counts[component]) == 1, "The combined level has exactly one %s owner" % component)
	_expect(upper.get_script() != lifecycle_script and upper.transform.is_equal_approx(Transform2D.IDENTITY), "Level02 is an unscaled content module in Level01 space")
	var spawn := level.get_node("SpawnPoint") as SpawnPoint
	_expect(player.global_position.is_equal_approx(spawn.global_position), "Level01 owns the combined player spawn")
	var floor := level.get_node("Geometry/Terrain/Floor2") as TerrainPiece
	var ground_left := upper.get_node("Geometry/Terrain/UpperTerrain/Ground13") as TerrainPiece
	var ground_right := upper.get_node("Geometry/Terrain/UpperTerrain/Ground14") as TerrainPiece
	var floor_rect: Rect2 = floor.global_transform * Rect2(Vector2.ZERO, floor.piece_size)
	var left_rect: Rect2 = ground_left.global_transform * Rect2(Vector2.ZERO, ground_left.piece_size)
	var right_rect: Rect2 = ground_right.global_transform * Rect2(Vector2.ZERO, ground_right.piece_size)
	_expect(floor_rect.is_equal_approx(SHARED_FLOOR_RECT) and left_rect.merge(right_rect).is_equal_approx(floor_rect), "Ground13 and Ground14 together span the reference Floor2 rectangle")
	_expect(left_rect.is_equal_approx(Rect2(-262.0, -3.0, 462.0, 40.0)) and right_rect.is_equal_approx(Rect2(284.0, -3.0, 798.0, 40.0)), "The two mapped sections retain the 84-pixel mechanism gap")
	_expect(not floor.is_visible_in_tree() and floor.collision_layer == 0 and floor.collision_mask == 0, "Main disables the full reference Floor2 so it cannot fill the gap")
	for ground: TerrainPiece in [ground_left, ground_right]:
		_expect(ground.is_visible_in_tree() and (ground.collision_layer & 1) != 0, "%s provides actual boundary collision" % ground.name)
		var polygon := ground.get_node("CollisionPolygon2D") as CollisionPolygon2D
		_expect(not polygon.disabled and is_equal_approx(ground.collision_top_inset, 6.5), "%s retains Level01 floor collision specifications" % ground.name)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	for point: Vector2 in [left_rect.get_center(), right_rect.get_center(), Vector2(242.0, 17.0)]:
		query.position = point
		var anchor_hits := 0
		for hit: Dictionary in level.get_world_2d().direct_space_state.intersect_point(query, 128):
			var collider := hit.get("collider") as Node
			if collider == floor or collider == ground_left or collider == ground_right:
				anchor_hits += 1
		_expect(anchor_hits == (0 if is_equal_approx(point.x, 242.0) else 1), "Boundary physics at %s has one floor or the authored gap" % point)
	var bounds := level.get_node("CameraBounds") as CameraBounds
	_expect(bounds.get_world_rect().is_equal_approx(CAMERA_RECT), "Main bounds include the upper and existing lower layout")
	var camera := player.get_node("Camera2D") as Camera2D
	_expect(not camera.limit_smoothed and camera.limit_left == -1024 and camera.limit_top == -1216 and camera.limit_right == 1792 and camera.limit_bottom == 704, "The sole player camera uses combined bounds")
	var phantom := level.get_node("PhantomCamera2D") as PhantomCamera2D
	_expect(phantom.follow_mode == PhantomCamera2D.FollowMode.FRAMED and phantom.get_follow_target() == player, "The sole phantom camera follows the shared player")
	_expect(phantom.zoom.is_equal_approx(Vector2(3.0, 3.0)), "Main preserves Level01 camera magnification")
	_expect(level.get_node_or_null("ForwardCameraFraming") is ForwardCameraFraming, "Main retains Level01 forward camera framing")
	var recovery := upper.get_node("Areas/FallRecovery") as HazardArea
	var deaths_before: int = int(level.call("death_count"))
	player.global_position = recovery.global_position + recovery.area_size * 0.5
	var recovered := false
	for frame_index: int in range(10):
		await physics_frame
		if int(level.call("death_count")) > deaths_before:
			recovered = true
			break
	_expect(recovered and int(level.call("death_count")) == deaths_before + 1, "Upper recovery reaches the single parent lifecycle exactly once")
	_expect(player.global_position.distance_to(spawn.global_position) < 0.1, "Combined recovery returns the player to Level01 spawn")
	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("LEVEL MAIN COMPOSITION: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
