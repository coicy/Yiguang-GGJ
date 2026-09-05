class_name PlayerVisuals
extends Node2D
## Uses optional form SpriteFrames when provided; otherwise draws a readable whitebox.

const FALLBACK_ANIMATION := &"idle"
const STATE_IDLE := &"idle"
const STATE_RUN := &"run"
const STATE_JUMP := &"jump"
const STATE_FALL := &"fall"
const STATE_GLIDE := &"glide"

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
	_default_frames = animated_sprite.sprite_frames
	_apply_frames()
	queue_redraw()


func _process(delta: float) -> void:
	# The anchor is in world space while this canvas item follows the player.
	# Rebuild the local endpoint every frame so the line stays pinned at both ends.
	_root_reveal = move_toward(_root_reveal, 1.0 if _rooted else 0.0, delta * 6.0)
	if _vine_attached or _rooted or _root_reveal > 0.0:
		queue_redraw()


func set_form(form: FormDefinition) -> void:
	_root_reveal = 0.0
	_current_form = form
	_apply_frames()
	queue_redraw()


func set_state(state: StringName) -> void:
	_current_state = state
	if _spine_visual != null:
		_spine_visual.set_gliding(state == STATE_GLIDE)
		animation_machine.set_locomotion_state(STATE_IDLE if _rooted else state)
	else:
		_apply_animation()
	queue_redraw()


func set_ability_state(rooted: bool, legs_extended: bool, vine_attached: bool) -> void:
	if rooted and not _rooted:
		_root_anchor_world = global_position
	var ability_active := rooted or legs_extended or vine_attached
	if ability_active and not _ability_active:
		animation_machine.play_skill()
	_ability_active = ability_active
	_rooted = rooted
	_legs_extended = legs_extended
	_vine_attached = vine_attached
	animation_machine.set_locomotion_state(STATE_IDLE if rooted else _current_state)
	queue_redraw()


func set_motion(velocity: Vector2) -> void:
	if not is_zero_approx(velocity.x):
		animation_machine.set_facing(velocity.x)


func play_death() -> bool:
	return animation_machine.play_death()


func revive() -> void:
	animation_machine.revive()


func set_leg_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_leg_direction = direction
	queue_redraw()


func set_leg_path(path: PackedVector2Array) -> void:
	_leg_path = path
	queue_redraw()


func set_vine_anchor(anchor: Node2D) -> void:
	_vine_anchor = anchor
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
	visual_host.position = _current_form.visual_offset
	_spine_visual.scale = Vector2.ONE * _current_form.visual_scale
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
		_draw_vine(_bone_point(&"hand_L_3", Vector2(0.0, -body_size.y * 0.5)))
		return

	var body_color := _current_form.body_color if _current_form != null else Color("#66c2a5")
	_draw_vine(Vector2(0.0, -body_size.y * 0.5))
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
	if _leg_path.size() < 2:
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


func _draw_vine(attachment_point: Vector2) -> void:
	if not _vine_attached or not is_instance_valid(_vine_anchor):
		return
	var end := to_local(_vine_anchor.global_position)
	_draw_stem(attachment_point, end, 3.0)
	draw_arc(end, 5.0, -0.7, TAU - 0.3, 20, Color("#8caf55"), 2.0, true)
	_draw_leaf(end, end + Vector2(8.0, -7.0), 3.0)


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
	if not _legs_extended:
		for bone in [&"leg_L3", &"leg_R3"]:
			var foot := _bone_point(bone, Vector2.ZERO)
			_draw_stem(foot, foot.lerp(anchor, _root_reveal), 2.0)
	for side in [-1.0, 1.0]:
		for branch in range(3):
			var tip := anchor + Vector2(side * (7.0 + branch * 4.0), 2.0 + branch) * _root_reveal
			_draw_stem(anchor, tip, 2.0)
			_draw_stem(tip, tip + Vector2(side * 3.0, 2.0) * _root_reveal, 1.0)
