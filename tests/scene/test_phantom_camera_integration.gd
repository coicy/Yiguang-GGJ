extends SceneTree
## Camera contract on the production greenhouse. Player placement isolates camera
## lifecycle cases; enemies are frozen only while checking framing, not for combat
## acceptance. All transforms/zoom below are read from the real Phantom Host.
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")
var level: GreenhouseLevel
var player: Player
var camera: Camera2D
var host: PhantomCameraHost
var exploration: PhantomCamera2D
var encounter_camera: PhantomCamera2D
var checks: int = 0
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	level = LEVEL_SCENE.instantiate() as GreenhouseLevel
	root.add_child(level)
	await process_frame # Host intentionally initializes on the first idle frame.
	await _frames(3)
	player = level.get_node("Actors/Player") as Player
	camera = level.get_node("Camera2D") as Camera2D
	host = camera.get_node("PhantomCameraHost") as PhantomCameraHost
	exploration = level.get_node("PhantomCamera2D") as PhantomCamera2D
	encounter_camera = level.get_node("EncounterCamera2D") as PhantomCamera2D
	var bounds := level.get_node("CameraBounds") as CameraBounds
	_expect(Engine.has_singleton("PhantomCameraManager"), "Plugin registers its engine singleton")
	_expect(root.get_node_or_null("PhantomCameraManager") != null, "Plugin manager autoload exists")
	_expect(host != null, "Production Camera2D has its Phantom Host")
	_expect(level.find_children("*", "Camera2D", true, false).size() == 1, "One physical Camera2D owns the viewport")
	_expect(exploration.follow_mode == PhantomCamera2D.FollowMode.FRAMED, "Exploration retains framed follow")
	_expect(exploration.follow_target == player, "Framed follow targets the production player")
	_expect(is_equal_approx(exploration.dead_zone_width, 0.6), "Horizontal deadzone remains adjustable at 0.6")
	_expect(is_equal_approx(exploration.dead_zone_height, 0.52), "Vertical deadzone remains adjustable at 0.52")
	_expect(exploration.lookahead, "Exploration retains look-ahead")
	_expect(exploration.lookahead_time.is_equal_approx(Vector2(0.2, 0.0)), "Look-ahead is horizontal only")
	_expect(exploration.zoom.is_equal_approx(Vector2(2.5, 2.5)), "Production exploration uses zoom 2.5")
	_expect(encounter_camera.follow_mode == PhantomCamera2D.FollowMode.NONE, "Combat uses a separate fixed Phantom")
	for phantom: PhantomCamera2D in [exploration, encounter_camera]:
		var rect := bounds.get_world_rect()
		_expect(phantom.limit_left == int(rect.position.x), "%s left limit comes from CameraBounds" % phantom.name)
		_expect(phantom.limit_top == int(rect.position.y), "%s top limit comes from CameraBounds" % phantom.name)
		_expect(phantom.limit_right == int(rect.end.x), "%s right limit comes from CameraBounds" % phantom.name)
		_expect(phantom.limit_bottom == int(rect.end.y), "%s bottom limit comes from CameraBounds" % phantom.name)
	_expect(not camera.position_smoothing_enabled, "Camera2D does not add a second smoothing system")
	_expect(level.current_room != null and host.get_active_pcam() == level._room_cameras[level.current_room], "Authored nursery view initially owns the Host")
	await _exploration_motion()
	var first := await _enter_room(0)
	# Pause during the transition itself, then allow the real Host to finish it.
	var paused_transform := camera.global_transform
	var paused_zoom := camera.zoom
	var paused_exploration := exploration.global_transform
	var paused_time := level.elapsed_seconds
	level._pause()
	await _frames(8)
	_expect(camera.global_transform.is_equal_approx(paused_transform), "Pause freezes the physical camera during a transition")
	_expect(camera.zoom.is_equal_approx(paused_zoom), "Pause freezes transition zoom")
	_expect(exploration.global_transform.is_equal_approx(paused_exploration), "Pause freezes inactive exploration follow")
	_expect(is_equal_approx(level.elapsed_seconds, paused_time), "Pause still excludes run time")
	level._resume()
	await _frames(32)
	_assert_room_frame(first)
	var fixed_position := camera.global_position
	Input.action_press(&"move_right")
	await _frames(18)
	Input.action_release(&"move_right")
	await _frames(8)
	_expect(camera.global_position.distance_to(fixed_position) < 0.1, "Player motion cannot drag the fixed encounter frame")
	await _finish_room(first)
	_expect(host.get_active_pcam() == exploration, "Room completion returns priority to exploration")
	# Retry while the completion transition is still running: no previous-room
	# interpolation, zoom, velocity or look-ahead may survive the restore.
	level._on_actor_killed(player)
	level.retry_checkpoint()
	_assert_retry_camera("ordinary")
	await _frames(32)
	_expect(camera.zoom.is_equal_approx(exploration.zoom), "Old completion tween cannot overwrite retry zoom")
	_expect(first.completed, "Camera reset preserves completed encounters")
	var boss := await _enter_room(7)
	await _frames(32)
	_assert_room_frame(boss)
	level._on_actor_killed(player)
	await _frames(55)
	_expect(paused and level.dead, "Elite death reaches the paused retry overlay")
	level.retry_checkpoint()
	_assert_retry_camera("elite")
	await _frames(8)
	_expect(player.global_position.x < boss.global_position.x and not boss.active, "Elite retry keeps preparation outside its trigger")
	_expect(host.get_active_pcam() == exploration, "Elite preparation keeps exploration active")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	paused = false
	level.feedback.clear()
	level.queue_free()
	await process_frame
	print("PHANTOM CAMERA: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _exploration_motion() -> void:
	player.form_controller.restore_form(&"humanoid")
	player.global_position = Vector2(5160, 398)
	player.velocity = Vector2.ZERO
	level._on_checkpoint_reached(player, player.global_position)
	level.retry_checkpoint()
	await _frames(12)
	var start := camera.global_position
	Input.action_press(&"move_right")
	await _frames(8)
	Input.action_release(&"move_right")
	await _frames(12)
	_expect(camera.global_position.distance_to(start) < 3.0, "Small movement inside the deadzone keeps the frame steady")
	Input.action_press(&"move_right")
	await _frames(55)
	Input.action_release(&"move_right")
	await _frames(8)
	_expect(camera.global_position.x > start.x + 10.0, "Crossing the deadzone moves the real Host camera")

func _enter_room(index: int) -> EncounterController:
	player.cancel_actions()
	var room := level.encounters[index]
	player.global_position = room.global_position + Vector2(72, -2)
	player.velocity = Vector2.ZERO
	await _frames(3)
	_expect(room.active, "%s triggers through the production encounter manager" % room.encounter_id)
	for enemy: CombatEnemy in room.enemies:
		enemy.set_physics_process(false)
	_expect(host.get_active_pcam() == encounter_camera, "%s gives the fixed Phantom priority" % room.encounter_id)
	return room

func _assert_room_frame(room: EncounterController) -> void:
	_expect(camera.global_position.distance_to(room.camera_center()) < 0.2, "%s settles on its authored arena center" % room.encounter_id)
	_expect(camera.zoom.is_equal_approx(Vector2.ONE * room.camera_zoom), "%s settles on its authored zoom" % room.encounter_id)

func _finish_room(room: EncounterController) -> void:
	for enemy: CombatEnemy in room.enemies.duplicate():
		var request := DamageRequest.new()
		request.amount = 100
		request.breaks_guard = true
		request.origin = enemy.global_position - Vector2(enemy.facing * 20, 0)
		enemy.receive_damage(request)
		# Death cleanup needs its ordinary physics tick after camera-only isolation.
		enemy.set_physics_process(true)
	for tick in range(100):
		if room.completed:
			break
		await _frames(1)
	_expect(room.completed, "Real encounter completion emits the camera handoff")

func _assert_retry_camera(label: String) -> void:
	_expect(not paused and not level.dead, "%s retry resumes gameplay" % label)
	_expect(host.get_active_pcam() == exploration, "%s retry immediately restores exploration ownership" % label)
	_expect(camera.zoom.is_equal_approx(exploration.zoom), "%s retry immediately restores exploration zoom" % label)
	_expect(camera.global_position.distance_to(player.global_position + exploration.follow_offset) < 2.0, "%s retry snaps to the restored checkpoint through the Host" % label)
	_expect(player.velocity == Vector2.ZERO and player.combat.health.current == 5, "%s retry retains movement and health reset" % label)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("CAMERA FAILURE: " + message)
