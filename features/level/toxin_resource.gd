class_name ToxinResource
extends Area2D
## A poisonous resource point that only changes form while the player actively absorbs it.

signal absorption_changed(active: bool)
signal resource_absorbed(actor: Node2D, amount: float)
signal absorption_rejected(actor: Node2D)

@export var toxin_per_second: float = 40.0

@export var show_world_prompt: bool = true

var _actors: Array[Node] = []
var _absorbing_actor: Node2D
var _rejected_actor: Node2D
var _effect_time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_effect_time += delta
	var next_absorbing_actor: Node2D
	var next_rejected_actor: Node2D
	for actor: Node in _actors.duplicate():
		if not is_instance_valid(actor):
			_actors.erase(actor)
			continue
		if actor.has_method(&"is_absorbing_resource") and actor.call(&"is_absorbing_resource"):
			if absorb(actor, toxin_per_second * delta):
				next_absorbing_actor = actor as Node2D
			elif actor is Node2D:
				next_rejected_actor = actor as Node2D
	_set_absorbing_actor(next_absorbing_actor)
	_set_rejected_actor(next_rejected_actor)
	queue_redraw()


func absorb(actor: Node, amount: float) -> bool:
	if amount <= 0.0 or not actor.has_method(&"absorb_toxin"):
		return false
	var absorbed: bool = actor.call(&"absorb_toxin", amount) == true
	if absorbed and actor is Node2D:
		resource_absorbed.emit(actor as Node2D, amount)
	return absorbed


func _on_body_entered(actor: Node) -> void:
	if not _actors.has(actor):
		_actors.append(actor)


func _on_body_exited(actor: Node) -> void:
	_actors.erase(actor)
	if actor == _absorbing_actor:
		_set_absorbing_actor(null)
	if actor == _rejected_actor:
		_set_rejected_actor(null)


func _set_absorbing_actor(actor: Node2D) -> void:
	if _absorbing_actor == actor:
		return
	_absorbing_actor = actor
	absorption_changed.emit(_absorbing_actor != null)


func _set_rejected_actor(actor: Node2D) -> void:
	if _rejected_actor == actor:
		return
	_rejected_actor = actor
	if _rejected_actor != null:
		absorption_rejected.emit(_rejected_actor)


func _draw() -> void:
	var rect := _resource_rect()
	var center := rect.get_center()
	if _actors.is_empty():
		return
	var prompt := "E 吸收"
	for actor: Node in _actors:
		if is_instance_valid(actor) and actor.has_method(&"requires_absorption_release") and actor.call(&"requires_absorption_release"):
			prompt = "松开 E 后继续吸收"
			break
	var prompt_color := Color.WHITE
	if _absorbing_actor != null:
		prompt = "吸收中"
		_draw_absorption_stream(center, Color("#b391c2"))
	elif _rejected_actor != null:
		prompt = "当前形态无法枯萎"
	if show_world_prompt:
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x - 8.0, rect.position.y - 6.0), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, prompt_color)


func _resource_rect() -> Rect2:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	if rectangle != null:
		return Rect2(collision.position - rectangle.size * 0.5, rectangle.size)
	var circle := collision.shape as CircleShape2D if collision != null else null
	if circle != null:
		return Rect2(collision.position - Vector2.ONE * circle.radius, Vector2.ONE * circle.radius * 2.0)
	return Rect2(-12.0, -12.0, 24.0, 24.0)


func _draw_absorption_stream(center: Vector2, color: Color) -> void:
	if _absorbing_actor == null:
		return
	var target := to_local(_absorbing_actor.global_position + Vector2(0.0, -8.0))
	var stream_color := color
	stream_color.a = 0.45
	for index: int in range(3):
		var progress := fposmod(_effect_time * 2.5 + float(index) / 3.0, 1.0)
		var point := center.lerp(target, progress) + Vector2(0.0, -sin(progress * PI) * 3.0)
		draw_circle(point, 1.2 + progress * 0.5, color)
