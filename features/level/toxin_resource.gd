class_name ToxinResource
extends Area2D
## A poisonous resource point that only changes form while the player actively absorbs it.

@export var toxin_per_second: float = 40.0

var _actors: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _physics_process(delta: float) -> void:
	for actor: Node in _actors.duplicate():
		if not is_instance_valid(actor):
			_actors.erase(actor)
			continue
		if actor.has_method(&"is_absorbing_resource") and actor.call(&"is_absorbing_resource"):
			if actor.has_method(&"absorb_toxin"):
				actor.call(&"absorb_toxin", toxin_per_second * delta)


func _on_body_entered(actor: Node) -> void:
	if not _actors.has(actor):
		_actors.append(actor)


func _on_body_exited(actor: Node) -> void:
	_actors.erase(actor)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#9861c8"))
	draw_string(ThemeDB.fallback_font, Vector2(-13.0, 5.0), "TOX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("#22122f"))
