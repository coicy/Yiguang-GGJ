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

	var body_color := Color("#66c2a5")
	if _current_form != null:
		match _current_form.id:
			&"sprout": body_color = Color("#7fc97f")
			&"humanoid": body_color = Color("#80b1d3")
			&"mature": body_color = Color("#fdb462")

	draw_circle(Vector2(0.0, -22.0), 9.0, body_color)
	draw_rect(Rect2(-10.0, -13.0, 20.0, 25.0), body_color)
	draw_line(Vector2(-10.0, -6.0), Vector2(-17.0, 2.0), body_color, 4.0)
	draw_line(Vector2(10.0, -6.0), Vector2(17.0, 2.0), body_color, 4.0)

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
