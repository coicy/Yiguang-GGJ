class_name PlayerVisuals
extends Node2D
## Uses optional form SpriteFrames when provided; otherwise draws a readable whitebox.

const GlowFeedback = preload("res://features/ui/glow_feedback.gd")
const FALLBACK_ANIMATION := &"idle"
const STATE_IDLE := &"idle"
const STATE_RUN := &"run"
const STATE_JUMP := &"jump"
const STATE_FALL := &"fall"
const STATE_GLIDE := &"glide"
const LEG_EXTENSION_HEIGHT := 72.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var glow_feedback: GlowFeedback = get_node_or_null("GlowFeedback") as GlowFeedback

var _default_frames: SpriteFrames
var _current_form: FormDefinition
var _current_state: StringName = STATE_IDLE
var _rooted: bool = false
var _legs_extended: bool = false
var _vine_attached: bool = false
var _vine_anchor: Node2D
var _leg_direction := Vector2.UP
var _stability: float = 100.0
var _toxin_active: bool = false
var _feedback_pulse: float = 0.0
var _feedback_flash: float = 0.0
var _feedback_elapsed: float = 0.0


func _ready() -> void:
	_default_frames = animated_sprite.sprite_frames
	_apply_frames()
	queue_redraw()


func _process(delta: float) -> void:
	_feedback_elapsed = fmod(_feedback_elapsed + delta, 120.0)
	_feedback_pulse = move_toward(_feedback_pulse, 0.0, delta * 2.2)
	_feedback_flash = move_toward(_feedback_flash, 0.0, delta * 3.5)
	# The anchor is in world space while this canvas item follows the player.
	# Rebuild the local endpoint every frame so the line stays pinned at both ends.
	if _vine_attached:
		queue_redraw()


func set_form(form: FormDefinition) -> void:
	_current_form = form
	if form != null:
		glow_feedback.set_glow_color(form.body_color)
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
	if anchor != null and anchor != _vine_anchor and anchor.has_method(&"highlight"):
		anchor.call(&"highlight")
	_vine_anchor = anchor
	queue_redraw()


func set_resource_state(stability: float, toxin_active: bool) -> void:
	_stability = clampf(stability, 0.0, 100.0)
	_toxin_active = toxin_active
	glow_feedback.set_active(true)
	glow_feedback.set_glow_color(Color("#da4b8c") if toxin_active else (_current_form.body_color if _current_form != null else Color("#66c2a5")))
	queue_redraw()


func play_nutrition_feedback() -> void:
	_feedback_pulse = maxf(_feedback_pulse, 0.65)
	glow_feedback.pulse(0.7)
	queue_redraw()


func play_growth_feedback() -> void:
	_feedback_pulse = 1.0
	glow_feedback.pulse(1.0)
	_feedback_flash = 0.0
	queue_redraw()


func play_wither_feedback() -> void:
	_feedback_flash = 1.0
	_feedback_pulse = 0.8
	glow_feedback.set_glow_color(Color("#da4b8c"))
	glow_feedback.pulse(1.0)
	queue_redraw()


func play_stability_hit_feedback() -> void:
	_feedback_flash = maxf(_feedback_flash, 0.55)
	glow_feedback.pulse(0.45)
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
	var body_size := _current_form.collision_size if _current_form != null else Vector2(28.0, 40.0)
	var body_offset_y := -LEG_EXTENSION_HEIGHT if _legs_extended else 0.0
	var body_color := _current_form.body_color if _current_form != null else Color("#66c2a5")
	_draw_feedback_aura(body_size, body_offset_y, body_color)
	if animated_sprite.sprite_frames != null:
		_draw_vine(Vector2(0.0, -body_size.y * 0.5 + body_offset_y))
		return

	_draw_vine(Vector2(0.0, -body_size.y * 0.5 + body_offset_y))
	draw_rect(Rect2(-body_size.x * 0.5, -body_size.y + body_offset_y, body_size.x, body_size.y), body_color)
	draw_circle(Vector2(0.0, -body_size.y + 5.0 + body_offset_y), minf(6.0, body_size.x * 0.25), Color.WHITE)
	if _rooted:
		draw_line(Vector2.ZERO, Vector2(-16.0, 10.0), Color("#b58a52"), 4.0)
		draw_line(Vector2.ZERO, Vector2(16.0, 10.0), Color("#b58a52"), 4.0)
	if _legs_extended:
		var hip_offset := body_size.x * 0.22
		draw_line(Vector2(-hip_offset, body_offset_y), Vector2(-hip_offset, 0.0), Color("#ffe083"), 8.0)
		draw_line(Vector2(hip_offset, body_offset_y), Vector2(hip_offset, 0.0), Color("#ffe083"), 8.0)
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


func _draw_vine(attachment_point: Vector2) -> void:
	if not _vine_attached or not is_instance_valid(_vine_anchor):
		return
	draw_line(
		attachment_point,
		to_local(_vine_anchor.global_position),
		Color("#8de06f"),
		3.0,
		true
	)
	draw_circle(attachment_point, 4.0, Color.WHITE)


func _draw_feedback_aura(body_size: Vector2, body_offset_y: float, body_color: Color) -> void:
	var center := Vector2(0.0, -body_size.y * 0.55 + body_offset_y)
	var base_strength := 0.05 + (100.0 - _stability) / 100.0 * 0.08
	if _toxin_active:
		base_strength += 0.08
	var pulse_radius := maxf(body_size.x, body_size.y) * 0.55 + _feedback_pulse * 12.0
	for layer: int in range(4, 0, -1):
		var radius := pulse_radius + float(layer) * 5.0
		var alpha := base_strength * (5.0 - float(layer)) + _feedback_pulse * 0.035
		draw_circle(center, radius, Color(body_color, alpha))
	if _feedback_pulse > 0.01:
		draw_arc(center, pulse_radius + 14.0, -PI * 0.7, PI * 0.7, 24, Color(0.9, 1.0, 0.78, _feedback_pulse * 0.7), 2.0)
	if _feedback_flash > 0.01:
		draw_circle(center, pulse_radius + 4.0, Color(1.0, 0.32, 0.36, _feedback_flash * 0.2), false, 3.0)
