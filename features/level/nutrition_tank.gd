class_name NutritionTank
extends Area2D

@export var nutrition_per_second: float = 40.0
@export var accepted_form_id: StringName = &""

var _actors: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _physics_process(delta: float) -> void:
	for actor: Node in _actors.duplicate():
		if is_instance_valid(actor) and _is_absorbing(actor):
			absorb(actor, nutrition_per_second * delta)
		else:
			if not is_instance_valid(actor):
				_actors.erase(actor)


func absorb(actor: Node, amount: float) -> bool:
	if amount <= 0.0 or not actor.has_method(&"absorb_nutrition"):
		return false
	if not accepted_form_id.is_empty():
		if not actor.has_method(&"current_form_id") or actor.call(&"current_form_id") != accepted_form_id:
			return false

	return actor.call(&"absorb_nutrition", amount) == true


func _on_body_entered(actor: Node) -> void:
	if not _actors.has(actor):
		_actors.append(actor)


func _on_body_exited(actor: Node) -> void:
	_actors.erase(actor)


func _is_absorbing(actor: Node) -> bool:
	return actor.has_method(&"is_absorbing_resource") and actor.call(&"is_absorbing_resource") == true


func _draw() -> void:
	draw_rect(Rect2(-24.0, -24.0, 48.0, 48.0), Color("#65d46e"))
	draw_string(ThemeDB.fallback_font, Vector2(-18.0, 5.0), "NUT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#17351b"))
