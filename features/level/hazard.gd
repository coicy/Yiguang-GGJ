class_name Hazard
extends Area2D

@export var visual_size: Vector2 = Vector2(128.0, 32.0)
@export var visual_color: Color = Color("#be4a2f")
@export var visual_label: String = "DAMAGE"
@export var show_whitebox_visual: bool = false

signal actor_hurt(actor: Node2D)
signal actor_killed(actor: Node2D)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func kill(actor: Node2D) -> void:
	actor_killed.emit(actor)


func _on_body_entered(actor: Node2D) -> void:
	actor_hurt.emit(actor)
	kill(actor)


func _draw() -> void:
	if not show_whitebox_visual:
		return
	draw_rect(Rect2(-visual_size * 0.5, visual_size), visual_color)
	if not visual_label.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-visual_size.x * 0.5 + 4.0, 5.0),
			visual_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color.WHITE
		)
