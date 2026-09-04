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

var _default_frames: SpriteFrames
var _current_form: FormDefinition
var _current_state: StringName = STATE_IDLE
var _rooted: bool = false
var _legs_extended: bool = false
var _vine_attached: bool = false
var _vine_anchor: Node2D
var _leg_direction := Vector2.UP


func _ready() -> void:
	_default_frames = animated_sprite.sprite_frames
	_apply_frames()
	queue_redraw()


func set_form(form: FormDefinition) -> void:
	_current_form = form
	_apply_frames()
	queue_redraw()


func set_state(state: StringName) -> void:
	_current_state = state
	_apply_animation()
	queue_redraw()


func set_ability_state(rooted: bool, legs_extended: bool, vine_attached: bool) -> void:
	_rooted = rooted
	_legs_extended = legs_extended
	_vine_attached = vine_attached
	queue_redraw()


func set_leg_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_leg_direction = direction.normalized()
	queue_redraw()


func set_vine_anchor(anchor: Node2D) -> void:
	_vine_anchor = anchor
	queue_redraw()


func _apply_frames() -> void:
	var frames := _default_frames
	if _current_form != null and _current_form.sprite_frames != null:
		frames = _current_form.sprite_frames
	animated_sprite.sprite_frames = frames
	_apply_animation()


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
	if animated_sprite.sprite_frames != null:
		return

	var body_color := _current_form.body_color if _current_form != null else Color("#66c2a5")
	var body_size := _current_form.collision_size if _current_form != null else Vector2(28.0, 40.0)
	draw_rect(Rect2(-body_size.x * 0.5, -body_size.y, body_size.x, body_size.y), body_color)
	draw_circle(Vector2(0.0, -body_size.y + 5.0), minf(6.0, body_size.x * 0.25), Color.WHITE)
	if _rooted:
		draw_line(Vector2.ZERO, Vector2(-16.0, 10.0), Color("#b58a52"), 4.0)
		draw_line(Vector2.ZERO, Vector2(16.0, 10.0), Color("#b58a52"), 4.0)
	if _legs_extended:
		draw_line(Vector2.ZERO, _leg_direction * 72.0, Color("#ffe083"), 10.0)
	if _vine_attached:
		draw_circle(Vector2(0.0, -body_size.y * 0.5), 4.0, Color.WHITE)
		if is_instance_valid(_vine_anchor):
			draw_line(
				Vector2(0.0, -body_size.y * 0.5),
				to_local(_vine_anchor.global_position),
				Color("#8de06f"),
				3.0
			)

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
