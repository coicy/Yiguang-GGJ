class_name CombatVisual
extends Node2D
## Defensive combat feedback. Attacks are rendered by the independent VineWhipVisual.
var combat: CombatController

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if combat == null or combat.player == null:
		return
	var face := combat.facing
	if combat.state == &"dash":
		var alpha := sin(combat.progress() * PI)
		for i in range(4):
			var x := -face * (10.0 + i * 7.0)
			draw_line(Vector2(x, -10.0 - i * 6.0), Vector2(x - face * 17.0, -10.0 - i * 6.0), Color(0.7, 0.9, 0.62, alpha * (0.48 - i * 0.08)), 1.8, true)
