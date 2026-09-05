class_name VineAnchor
extends Node2D
## Visible whitebox grapple point discovered through the vine_anchor group.

const GlowFeedback = preload("res://features/ui/glow_feedback.gd")

@onready var glow: GlowFeedback = get_node_or_null("GlowFeedback") as GlowFeedback


func _ready() -> void:
	add_to_group("vine_anchor")
	if glow != null:
		glow.set_glow_color(Color("#f3cf55"))
	queue_redraw()


func highlight() -> void:
	if glow != null:
		glow.pulse(1.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#f3cf55"))
	draw_circle(Vector2.ZERO, 6.0, Color("#574519"))
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), Color.WHITE, 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), Color.WHITE, 2.0)
