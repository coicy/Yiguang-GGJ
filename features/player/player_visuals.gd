class_name PlayerVisuals
extends Node2D
## Uses optional form SpriteFrames when provided; otherwise draws a readable whitebox.

const SPROUT_POSES: CombatPoseLibrary = preload("res://features/combat/data/sprout_poses.tres")
const HUMAN_POSES: CombatPoseLibrary = preload("res://features/combat/data/humanoid_poses.tres")
const MATURE_POSES: CombatPoseLibrary = preload("res://features/combat/data/mature_poses.tres")
var _combat_active: bool = false
const VINE_WHIP_SCENE: PackedScene = preload("res://features/combat/visuals/vine_whip_visual.tscn")
var _combat_drawing: CombatVisual
var _vine_whip: VineWhipVisual
var _combat_controller: CombatController
signal vine_latched

const FALLBACK_ANIMATION := &"idle"
const STATE_IDLE := &"idle"
const STATE_RUN := &"run"
const STATE_JUMP := &"jump"
const STATE_FALL := &"fall"
const STATE_GLIDE := &"glide"

@onready var vine_visual: VineVisual = %VineVisual
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var visual_host: Node2D = %VisualHost
@onready var animation_machine: PlayerAnimationMachine = %AnimationMachine

var _default_frames: SpriteFrames
var _current_form: FormDefinition
var _current_state: StringName = STATE_IDLE
var _rooted: bool = false
var _legs_extended: bool = false
var _vine_attached: bool = false
var _vine_anchor: Node2D
var _leg_direction := Vector2.UP
var _leg_path := PackedVector2Array([Vector2.ZERO])
var _spine_visual: SpineCharacterVisual
var _ability_active: bool = false
var _root_reveal: float = 0.0
var _root_anchor_world := Vector2.ZERO


func _ready() -> void:
	vine_visual.latched.connect(func() -> void: vine_latched.emit())
	_combat_drawing = CombatVisual.new()
	add_child(_combat_drawing)
	_vine_whip = VINE_WHIP_SCENE.instantiate() as VineWhipVisual
	_vine_whip.name = "VineWhipVisual"
	add_child(_vine_whip)
	_default_frames = animated_sprite.sprite_frames
	_apply_frames()
	queue_redraw()


func _process(delta: float) -> void:
	vine_visual.set_hand_position(_vine_hand_world_position())
	# The anchor is in world space while this canvas item follows the player.
	# Rebuild the local endpoint every frame so the line stays pinned at both ends.
	_root_reveal = move_toward(_root_reveal, 1.0 if _rooted else 0.0, delta * 6.0)
	if _vine_attached or _rooted or _root_reveal > 0.0:
		queue_redraw()


func set_form(form: FormDefinition) -> void:
	if is_instance_valid(_vine_whip):
		_vine_whip.clear_attack()
	vine_visual.clear()
	_root_reveal = 0.0
	_combat_active = false
	modulate = Color.WHITE
	_current_form = form
	_apply_frames()
	queue_redraw()


func set_state(state: StringName) -> void:
	_current_state = state
	if _spine_visual != null:
		_spine_visual.set_gliding(state == STATE_GLIDE and not _combat_active)
		animation_machine.set_locomotion_state(STATE_IDLE if _rooted else state)
	else:
		_apply_animation()
	queue_redraw()


func set_ability_state(rooted: bool, legs_extended: bool, vine_attached: bool) -> void:
	if rooted and not _rooted:
		_root_anchor_world = global_position
	var ability_active := rooted or legs_extended or vine_attached
	if ability_active and not _ability_active and not vine_attached:
		animation_machine.play_skill()
	_ability_active = ability_active
	_rooted = rooted
	_legs_extended = legs_extended
	_vine_attached = vine_attached
	animation_machine.set_locomotion_state(STATE_IDLE if rooted else _current_state)
	queue_redraw()


func set_motion(velocity: Vector2) -> void:
	if _combat_active:
		return
	if not _rooted and vine_visual.phase() != VineVisual.FLYING and absf(velocity.x) > 1.0:
		animation_machine.set_facing(velocity.x)


func play_death() -> bool:
	_combat_active = false
	if _current_form != null:
		visual_host.transform = Transform2D(0.0, _current_form.visual_offset)
	if is_instance_valid(_vine_whip):
		_vine_whip.clear_attack()
	if _spine_visual != null:
		_spine_visual.combat_pose = {}
		_spine_visual.combat_offsets = {}
	vine_visual.clear()
	return animation_machine.play_death()


func revive() -> void:
	animation_machine.revive()


func set_leg_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_leg_direction = direction
		if _rooted and not is_zero_approx(direction.x):
			animation_machine.set_facing(direction.x)
	queue_redraw()


func set_leg_path(path: PackedVector2Array) -> void:
	_leg_path = path
	queue_redraw()


func set_vine_anchor(anchor: Node2D) -> void:
	_vine_anchor = anchor
	vine_visual.set_anchor(anchor)
	queue_redraw()


func _apply_frames() -> void:
	var frames := _default_frames
	if _current_form != null and _current_form.sprite_frames != null:
		frames = _current_form.sprite_frames
	animated_sprite.sprite_frames = frames
	_replace_spine_visual()
	_apply_animation()


func _replace_spine_visual() -> void:
	animation_machine.set_visual(null)
	if _spine_visual != null:
		visual_host.remove_child(_spine_visual)
		_spine_visual.queue_free()
		_spine_visual = null
	visual_host.position = Vector2.ZERO
	if _current_form == null or _current_form.visual_scene == null:
		animated_sprite.visible = true
		return
	var instance := _current_form.visual_scene.instantiate()
	_spine_visual = instance as SpineCharacterVisual
	if _spine_visual == null:
		push_warning("PlayerVisuals: form visual scene must use SpineCharacterVisual.")
		instance.queue_free()
		animated_sprite.visible = true
		return
	visual_host.transform = Transform2D(0.0, _current_form.visual_offset)
	_spine_visual.scale = Vector2.ONE * _current_form.visual_scale
	_spine_visual.combat_hand_transform_updated.connect(_on_combat_hand_transform_updated)
	visual_host.add_child(_spine_visual)
	animated_sprite.visible = false
	animation_machine.set_visual(_spine_visual)
	_spine_visual.set_gliding(_current_state == STATE_GLIDE)


func _apply_animation() -> void:
	if animated_sprite.sprite_frames == null:
		animated_sprite.stop()
		return
	var animation := _current_state
	if not animated_sprite.sprite_frames.has_animation(animation):
		animation = FALLBACK_ANIMATION
	if animated_sprite.sprite_frames.has_animation(animation):
		animated_sprite.play(animation)


func _draw() -> void:
	var body_size := _current_form.collision_size if _current_form != null else Vector2(28.0, 40.0)
	_draw_root_anchor()
	_draw_leg_path()
	if _spine_visual != null or animated_sprite.sprite_frames != null:
		return

	var body_color := _current_form.body_color if _current_form != null else Color("#66c2a5")
	draw_rect(Rect2(-body_size.x * 0.5, -body_size.y, body_size.x, body_size.y), body_color)
	draw_circle(Vector2(0.0, -body_size.y + 5.0), minf(6.0, body_size.x * 0.25), Color.WHITE)
	if _rooted:
		draw_line(Vector2.ZERO, Vector2(-16.0, 10.0), Color("#b58a52"), 4.0)
		draw_line(Vector2.ZERO, Vector2(16.0, 10.0), Color("#b58a52"), 4.0)
	if _legs_extended:
		return

	match _current_state:
		STATE_RUN:
			draw_line(Vector2(-5.0, 12.0), Vector2(-9.0, 22.0), body_color, 4.0)
			draw_line(Vector2(5.0, 12.0), Vector2(9.0, 20.0), body_color, 4.0)
		STATE_JUMP:
			draw_line(Vector2(-8.0, -29.0), Vector2(0.0, -37.0), Color.WHITE, 2.0)
			draw_line(Vector2(0.0, -37.0), Vector2(8.0, -29.0), Color.WHITE, 2.0)
		STATE_FALL:
			draw_line(Vector2(-8.0, -35.0), Vector2(0.0, -27.0), Color.WHITE, 2.0)
			draw_line(Vector2(0.0, -27.0), Vector2(8.0, -35.0), Color.WHITE, 2.0)
		STATE_GLIDE:
			draw_arc(Vector2(-12.0, -10.0), 13.0, PI, TAU, 12, Color.WHITE, 2.0)
			draw_arc(Vector2(12.0, -10.0), 13.0, PI, TAU, 12, Color.WHITE, 2.0)


func _draw_leg_path() -> void:
	if not _legs_extended or _leg_path.size() < 2:
		return
	var foot_left := _bone_point(&"leg_L3", Vector2(-5.0, 0.0))
	var foot_right := _bone_point(&"leg_R3", Vector2(5.0, 0.0))
	_draw_stem(foot_left, _leg_path[0], 4.0)
	_draw_stem(foot_right, _leg_path[0], 4.0)
	for index in range(_leg_path.size() - 1):
		var start := _leg_path[index]
		var end := _leg_path[index + 1]
		_draw_stem(start, end, 6.0)
		var direction := (end - start).normalized()
		for section in range(1, int(start.distance_to(end) / 14.0)):
			var joint := start + direction * section * 14.0
			draw_line(joint - direction.orthogonal() * 3.0, joint + direction.orthogonal() * 3.0, Color("#b2cc69"), 1.0, true)
		if index > 0:
			_draw_leaf(start, start + Vector2(8.0, -9.0), 3.0)


func fire_vine(target_position: Vector2, will_attach: bool) -> void:
	animation_machine.set_facing(target_position.x - global_position.x)
	animation_machine.play_skill(true)
	vine_visual.set_hand_position(_vine_hand_world_position())
	vine_visual.fire(target_position, will_attach)


func cancel_vine_effect() -> void:
	vine_visual.clear()


func _vine_hand_world_position() -> Vector2:
	var height := _current_form.collision_size.y if _current_form != null else 40.0
	return to_global(_bone_point(&"hand_L_3", Vector2(0.0, -height * 0.5)))


func _bone_point(bone_name: StringName, fallback: Vector2) -> Vector2:
	if _spine_visual == null or not _spine_visual.is_node_ready():
		return fallback
	var sprite := _spine_visual.spine_sprite
	if sprite.get_skeleton().find_bone(bone_name) == null:
		return fallback
	return to_local(sprite.get_global_bone_transform(bone_name).origin)


func _draw_stem(start: Vector2, end: Vector2, width: float) -> void:
	draw_line(start, end, Color("#344b29"), width + 2.0, true)
	draw_line(start, end, Color("#87a853"), width, true)
	draw_circle(start, width * 0.5, Color("#87a853"))
	draw_circle(end, width * 0.5, Color("#87a853"))


func _draw_leaf(base: Vector2, tip: Vector2, width: float) -> void:
	var middle := base.lerp(tip, 0.45)
	var normal := (tip - base).normalized().orthogonal() * width
	var outline := PackedVector2Array([base, base.lerp(tip, 0.25) + normal * 0.7, middle + normal, base.lerp(tip, 0.72) + normal * 0.65, tip, base.lerp(tip, 0.72) - normal * 0.65, middle - normal, base.lerp(tip, 0.25) - normal * 0.7, base])
	draw_colored_polygon(outline, Color("#79aa46"))
	draw_polyline(outline, Color("#344b29"), 1.0, true)
	draw_line(base, tip, Color("#c0d477"), 1.0, true)


func _draw_root_anchor() -> void:
	if _root_reveal <= 0.0:
		return
	var anchor := to_local(_root_anchor_world)
	if _rooted and not _legs_extended:
		for bone in [&"leg_L3", &"leg_R3"]:
			var foot := _bone_point(bone, Vector2.ZERO)
			_draw_stem(foot, foot.lerp(anchor, _root_reveal), 2.0)
	for side in [-1.0, 1.0]:
		for branch in range(3):
			var tip := anchor + Vector2(side * (7.0 + branch * 4.0), 2.0 + branch) * _root_reveal
			_draw_stem(anchor, tip, 2.0)
			_draw_stem(tip, tip + Vector2(side * 3.0, 2.0) * _root_reveal, 1.0)


func set_combat_state(controller: CombatController) -> void:
	_combat_controller = controller
	_combat_drawing.combat = controller
	var was_active := _combat_active
	_combat_active = controller.is_busy() and controller.state != &"dead"
	var landing_recovery := controller.state == &"attack_landing"
	if controller.state not in [&"attack", &"attack_landing", &"parry", &"parry_success"]:
		_vine_whip.clear_attack()
	if _spine_visual == null:
		_sample_vine_whip()
		return
	if _combat_active and not was_active:
		animation_machine.begin_combat()
	var step_speed := controller.player.velocity.x
	if controller.attack != null and controller.attack.id == &"sprout_bump" and controller.elapsed >= controller.attack.windup:
		step_speed = 0.0 # The short body thrust owns the planted pose, not the walking cycle.
	var planted_parry := controller.state in [&"parry", &"parry_success"] and controller.player.is_on_floor()
	animation_machine.set_combat_context(controller.is_ground_attack() or planted_parry, landing_recovery, 0.0 if planted_parry else step_speed)
	var pose_id := controller.attack.id if controller.attack != null else controller.state
	var library := MATURE_POSES if _current_form.id == &"mature" else HUMAN_POSES
	if _current_form.id == &"sprout":
		library = SPROUT_POSES
	var pose_progress := controller.progress()
	if landing_recovery:
		pose_progress = controller.landing_from_progress
	elif controller.state == &"hurt":
		pose_progress = clampf(controller.elapsed / 0.22, 0.0, 1.0)

	var body_pose := library.body_transform(pose_id, pose_progress) if _combat_active else Transform2D.IDENTITY
	visual_host.position = _current_form.visual_offset + Vector2(body_pose.origin.x * controller.facing, body_pose.origin.y)
	visual_host.rotation = body_pose.get_rotation() * controller.facing
	visual_host.scale = body_pose.get_scale()
	_spine_visual.combat_pose = library.rotations(pose_id, pose_progress) if _combat_active else {}
	_spine_visual.combat_offsets = library.offsets(pose_id, pose_progress) if _combat_active else {}
	# The pose library already eases into anticipation; do not hide the first short windup with a second long fade.
	var blend_in := 0.045 if controller.attack != null else 0.12
	_spine_visual.combat_blend = smoothstep(0.0, blend_in, pose_progress) * (1.0 - smoothstep(0.84, 1.0, pose_progress))
	if controller.state in [&"parry", &"parry_success"]:
		# The authored pose owns its fade. Success starts at the exact caught pose.
		_spine_visual.combat_blend = 1.0
		if controller.state == &"parry_success":
			var transfer := smoothstep(0.0, controller.tuning.parry_pose_transfer, controller.elapsed)
			_spine_visual.combat_pose = _blend_pose_values(library.rotations(&"parry", controller.parry_from_progress), _spine_visual.combat_pose, transfer)
			_spine_visual.combat_offsets = _blend_pose_values(library.offsets(&"parry", controller.parry_from_progress), _spine_visual.combat_offsets, transfer)
	if landing_recovery:
		# Arms settle from the interrupted air pose; jump_end owns grounded legs.
		_spine_visual.combat_pose.erase("leg_L")
		_spine_visual.combat_pose.erase("leg_R")
		_spine_visual.combat_blend *= 1.0 - smoothstep(0.0, 1.0, controller.landing_progress())
	_spine_visual.set_gliding(_current_state == STATE_GLIDE and not _combat_active)
	if _combat_active:
		animation_machine.set_facing(controller.facing)
	# Spine emits the current hand transform after its world pose is evaluated.
	modulate = Color(1.0, 0.65, 0.6) if controller.state == &"hurt" else Color.WHITE
	if controller.health.protection_left > 0.0:
		modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.025))


func _on_combat_hand_transform_updated(global_hand_transform: Transform2D) -> void:
	if _combat_controller == null or _current_form == null or not is_instance_valid(_vine_whip):
		return
	var local_hand := global_transform.affine_inverse() * global_hand_transform
	_vine_whip.sample_combat(_combat_controller, _current_form.id, local_hand)


func _sample_vine_whip() -> void:
	if _spine_visual != null and _spine_visual.is_node_ready():
		_on_combat_hand_transform_updated(_spine_visual.combat_hand_global_transform())
	elif _combat_controller != null and _current_form != null:
		var fallback := Transform2D.IDENTITY
		fallback.origin = Vector2(8.0 * _combat_controller.facing, -24.0)
		_vine_whip.sample_combat(_combat_controller, _current_form.id, fallback)


func _blend_pose_values(from_pose: Dictionary, to_pose: Dictionary, weight: float) -> Dictionary:
	var result := from_pose.duplicate()
	for bone: String in to_pose:
		result[bone] = lerp(from_pose.get(bone, to_pose[bone] * 0.0), to_pose[bone], weight)
	return result


func parry_contact_world_position() -> Vector2:
	if _spine_visual != null:
		_spine_visual.spine_sprite.update_skeleton(0.0)
		if is_instance_valid(_vine_whip) and _vine_whip.visible:
			return to_global(_vine_whip.parry_contact_position)
		return _spine_visual.combat_hand_global_transform().origin
	return to_global(Vector2(_combat_controller.facing * 16.0, -22.0))
