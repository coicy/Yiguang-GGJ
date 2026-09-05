class_name GreenhouseLevel
extends HandbuiltLevel
const SECTION_STARTS := [0.0, 760.0, 2200.0, 3640.0, 5080.0, 6480.0, 7440.0]
const SECTION_NAMES := ["01 / 培养室","02 / 苔藓步道","03 / 孢子廊","04 / 修枝车间","05 / 树冠通路","06 / 隔离庭院","07 / 温室核心"]
const SECTION_GOALS := [
	"按住 E 吸收营养，成长后前往温室深处",
	"左键连击 · Shift 闪避 · 空中左键斜劈",
	"靠近孢子囊，或用 F 将孢子弹回去",
	"右键破防 · 观察抬刃，用 F 弹反",
	"成长为成熟形态 · Q 连接藤蔓 · 按住空格滑翔",
	"依次处理远程与近战威胁，清理隔离庭院",
	"击败守圃者，开启温室出口"
]
@export_range(0.0, 200.0, 1.0) var fall_out_margin: float = 34.0
var room_regions: Array[RoomRegion] = []
var current_room: RoomRegion
var _room_cameras: Dictionary[RoomRegion, PhantomCamera2D] = {}
@onready var _encounter_camera: PhantomCamera2D = %EncounterCamera2D
@onready var _camera_host: PhantomCameraHost = %PhantomCameraHost
var _instant_camera_tween := PhantomCameraTween.new()
@onready var combat_hud: CombatHud = %CombatHud
@onready var feedback: CombatFeedback = %CombatFeedback
@onready var sounds: SoundEmitter = %LevelSounds
@onready var exit_goal: ExitGoal = %ExitGoal
var encounters: Array[EncounterController] = []
var current_encounter: EncounterController
var elapsed_seconds: float = 0.0
var death_count: int = 0
var soundscape: GreenhouseSoundscape
var finished: bool = false
var dead: bool = false
var _checkpoint_state: Dictionary = {}
var _section: int = -1
var _death_delay: float = -1.0
var _pause_open: bool = false
func _ready() -> void:
	super._ready()
	sounds.configure_world_pool(16)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for branch: String in ["Geometry","Areas","Actors","Encounters","Checkpoints","NurseryRoom","Rooms"]:
		var node := get_node_or_null(branch)
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	_configure_phantom_bounds(_encounter_camera)
	_register_room_regions()
	_update_room_context()
	_instant_camera_tween.duration = 0.0
	_initialize_camera()
	feedback.camera = _camera
	feedback.sounds = sounds
	_player.combat.feedback_requested.connect(_on_player_feedback)
	_player.died.connect(_on_player_died)
	combat_hud.bind_player(_player)
	combat_hud.pause_requested.connect(_pause)
	combat_hud.resume_requested.connect(_resume)
	combat_hud.retry_requested.connect(retry_checkpoint)
	combat_hud.restart_requested.connect(_restart)
	for node: Node in %Encounters.get_children():
		var encounter := node as EncounterController
		if encounter == null:
			continue
		encounter.player = _player
		encounter.encounter_started.connect(_on_encounter_started)
		encounter.encounter_completed.connect(_on_encounter_completed)
		encounter.enemy_spawned.connect(_on_enemy_spawned)
		encounter.feedback_requested.connect(_on_encounter_feedback)
		encounters.append(encounter)
	exit_goal.set_unlocked(false)
	exit_goal.player_completed.connect(_on_completed)
	_checkpoint_state = _player.capture_state()
	_checkpoint_state["position"] = _spawn_point.global_position
	_checkpoint_state["room_id"] = _room_id_at(_spawn_point.global_position)
	soundscape = GreenhouseSoundscape.new()
	soundscape.name = "Soundscape"
	add_child(soundscape)
	soundscape.setup(self)
func _process(delta: float) -> void:
	if get_tree().paused or finished:
		return
	if dead:
		_death_delay -= delta
		if _death_delay <= 0.0:
			combat_hud.show_death()
			get_tree().paused = true
		return
	elapsed_seconds += delta
	_update_room_context()
	_section = 0
	for index in range(SECTION_STARTS.size()):
		if _player.global_position.x >= SECTION_STARTS[index]:
			_section = index
	_section = maxi(_section,0)
	var objective := current_encounter.objective if is_instance_valid(current_encounter) and current_encounter.active else _section_objective()
	combat_hud.set_progress(_section_name(),objective,elapsed_seconds,death_count)
	if current_encounter == null or not current_encounter.active:
		for encounter: EncounterController in encounters:
			if encounter.can_trigger():
				encounter.begin()
				break
	if _player.global_position.y > _camera_bounds.get_world_rect().end.y + fall_out_margin:
		_on_actor_killed(_player)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") and not event.is_echo():
		_restart()
	elif event.is_action_pressed(&"pause") and not event.is_echo() and not dead and not finished:
		if _pause_open:
			_resume()
		else:
			_pause()
func _on_encounter_started(encounter: EncounterController) -> void:
	soundscape.set_mode(&"boss" if encounter.encounter_id == &"warden" else &"battle")
	sounds.play_at(&"gate_close", encounter.global_position)
	current_encounter = encounter
	_encounter_camera.global_position = encounter.camera_center()
	_encounter_camera.zoom = Vector2.ONE * encounter.camera_zoom
	_encounter_camera.priority = _phantom_camera.priority + 2
	_player.combat.health.reset_health()
	_checkpoint_state = _player.capture_state()
	_checkpoint_state["position"] = encounter.checkpoint_position()
	_checkpoint_state["velocity"] = Vector2.ZERO
	_checkpoint_state["room_id"] = _room_id_at(_checkpoint_state["position"])
	sounds.play_cue(&"checkpoint")
func _on_encounter_completed(encounter: EncounterController) -> void:
	if encounter == current_encounter:
		current_encounter = null
		_encounter_camera.priority = 0
	combat_hud.set_boss(null)
	sounds.play_cue(&"encounter_clear")
	sounds.play_at(&"gate_open", encounter.global_position)
	soundscape.set_mode(&"explore")
	if encounter.encounter_id == &"warden":
		exit_goal.set_unlocked(true)
func _on_enemy_spawned(enemy: CombatEnemy) -> void:
	enemy.audio.use_pool(sounds)
	if enemy.definition.kind == EnemyDefinition.Kind.WARDEN:
		combat_hud.set_boss(enemy)
func _on_actor_killed(actor: Node2D) -> void:
	if actor != _player or dead or finished:
		return
	var damage := DamageRequest.new()
	damage.amount = _player.combat.health.maximum
	damage.parryable = false
	_player.combat.health.protection_left = 0.0
	_player.combat.health.take_damage(damage)
func _on_player_died() -> void:
	if dead or finished:
		return
	dead = true
	death_count += 1
	sounds.stop_all()
	_player.audio.sounds.stop_all()
	sounds.play_cue(&"death")
	soundscape.stop_transients()
	soundscape.set_mode(&"explore")
	combat_hud.set_progress(_section_name(), _section_objective(), elapsed_seconds, death_count)
	_death_delay = 0.7
	feedback.clear()
func retry_checkpoint() -> void:
	sounds.stop_all()
	_player.audio.sounds.stop_all()
	soundscape.stop_transients()
	soundscape.set_mode(&"explore")
	sounds.play_cue(&"respawn")
	get_tree().paused = false
	_pause_open = false
	feedback.clear()
	if is_instance_valid(current_encounter):
		current_encounter.reset_encounter()
	current_encounter = null
	combat_hud.set_boss(null)
	_player.restore_state(_checkpoint_state)
	_player.velocity = Vector2.ZERO
	_player.combat.reset()
	_player.revive_animation()
	_player.visuals.set_combat_state(_player.combat)
	dead = false
	_death_delay = -1.0
	combat_hud.hide_overlay()
	_reset_exploration_camera()
func _initialize_camera() -> void:
	# PhantomCameraHost registers its signals after the first process frame.
	await get_tree().process_frame
	_reset_exploration_camera()
func _reset_exploration_camera() -> void:
	# Resolve the restored position before selecting a view: no stale room or
	# deferred Area overlap survives retry. Only the Host writes Camera2D.
	_update_room_context()
	var cameras: Array[PhantomCamera2D] = [_phantom_camera, _encounter_camera]
	cameras.append_array(_room_cameras.values())
	var saved_tweens: Array[PhantomCameraTween] = []
	for phantom: PhantomCamera2D in cameras:
		saved_tweens.append(phantom.tween_resource)
		phantom.tween_resource = _instant_camera_tween
	# Re-select even during an unfinished previous transition.
	_encounter_camera.priority = _phantom_camera.priority + 3
	_phantom_camera.global_position = _player.global_position + _phantom_camera.follow_offset
	_phantom_camera.teleport_position()
	_encounter_camera.priority = 0
	_camera_host.process(1.0 / Engine.physics_ticks_per_second)
	for index in range(cameras.size()):
		cameras[index].tween_resource = saved_tweens[index]

func _register_room_regions() -> void:
	for node: Node in find_children("*", "Node2D", true, false):
		var room := node as RoomRegion
		if room == null:
			continue
		room_regions.append(room)
		var phantom := PhantomCamera2D.new()
		phantom.name = String(room.room_id) + "View"
		phantom.process_mode = Node.PROCESS_MODE_PAUSABLE
		phantom.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		phantom.priority = 0
		phantom.follow_mode = PhantomCamera2D.FollowMode.NONE
		phantom.zoom = Vector2.ONE * room.camera_zoom
		phantom.tween_on_load = false
		phantom.tween_resource = _phantom_camera.tween_resource
		add_child(phantom)
		phantom.owner = self
		phantom.global_position = room.get_camera_center()
		_configure_phantom_bounds(phantom)
		_room_cameras[room] = phantom

func resolve_room_at(point: Vector2) -> RoomRegion:
	var selected: RoomRegion
	for room: RoomRegion in room_regions:
		if room.contains_point(point) and (selected == null or room.selection_priority > selected.selection_priority):
			selected = room
	return selected

func _room_id_at(point: Vector2) -> StringName:
	var room := resolve_room_at(point)
	return room.room_id if room != null else &""

func _update_room_context() -> void:
	current_room = resolve_room_at(_player.global_position)
	for room: RoomRegion in room_regions:
		_room_cameras[room].priority = _phantom_camera.priority + 1 if room == current_room else 0

func _section_name() -> String:
	return current_room.room_name if current_room != null else String(SECTION_NAMES[maxi(_section, 0)])

func _section_objective() -> String:
	return current_room.objective if current_room != null else String(SECTION_GOALS[maxi(_section, 0)])

func _on_checkpoint_reached(actor: Node2D, point: Vector2) -> void:
	super._on_checkpoint_reached(actor,point)
	if actor == _player:
		sounds.play_cue(&"checkpoint")
		_checkpoint_state = _player.capture_state()
		_checkpoint_state["position"] = point
		_checkpoint_state["velocity"] = Vector2.ZERO
		_checkpoint_state["room_id"] = _room_id_at(point)
		_player.combat.health.reset_health()
func _pause() -> void:
	if dead or finished:
		return
	sounds.play_cue(&"ui_open")
	_pause_open = true
	feedback.clear()
	get_tree().paused = true
	combat_hud.show_pause()
func _resume() -> void:
	sounds.play_cue(&"ui_confirm")
	_pause_open = false
	get_tree().paused = false
	combat_hud.hide_overlay()
func _restart() -> void:
	get_tree().paused = false
	feedback.clear()
	get_tree().reload_current_scene()
func _on_completed(_actor: Player) -> void:
	if finished:
		return
	finished = true
	sounds.play_cue(&"victory")
	soundscape.set_mode(&"explore")
	soundscape.stop_transients()
	feedback.clear()
	combat_hud.show_complete(elapsed_seconds,death_count)
	get_tree().paused = true
func _on_player_feedback(kind: StringName, point: Vector2, strength: float) -> void:
	if kind == &"swing" and _player.combat.attack != null:
		var key := StringName(String(_player.current_form_id()) + "_" + String(_player.combat.attack.id))
		_player.audio.sounds.play_cue(key if AudioPalette.CUES.has(key) else &"swing")
		feedback.cue(kind, point, strength, false)
	else:
		feedback.cue(kind, point, strength)
func _on_encounter_feedback(kind: StringName, point: Vector2, strength: float) -> void:
	# EnemyAudio owns creature timbres. Keep existing impact visuals and hit-stop.
	if kind in [&"spore_burst", &"spore_reflect"]:
		sounds.play_at(kind, point)
		return
	feedback.cue(kind, point, strength, false)
