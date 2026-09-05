class_name VineRing
extends VineAnchor
## Reusable hanging vine ring.
## The scene root is the vine's bottom tip and remains the hook target.

signal hook_prompt_changed(visible: bool)

@export_group("Vine Ring")
@export_range(16.0, 320.0, 1.0) var vine_length: float = 112.0
@export_range(8.0, 40.0, 1.0) var ring_radius: float = 16.0
@export_range(2.0, 24.0, 1.0) var ring_thickness: float = 5.0
@export_range(2.0, 24.0, 1.0) var hook_radius: float = 10.0

@export_group("Mature Prompt")
@export_range(32.0, 320.0, 1.0) var prompt_radius: float = 180.0
@export var hook_prompt_text: String = "成熟期 · 左键连接藤蔓"

@onready var hook_area: Area2D = %HookArea
@onready var hook_collision: CollisionShape2D = %HookCollision
@onready var proximity_area: Area2D = %PromptProximity
@onready var proximity_collision: CollisionShape2D = %PromptCollision
@onready var hook_prompt: Label = %HookPrompt

var _nearby_player: Player


func _ready() -> void:
	super._ready()
	_update_collision_shapes()
	proximity_area.body_entered.connect(_on_proximity_body_entered)
	proximity_area.body_exited.connect(_on_proximity_body_exited)
	hook_prompt.text = hook_prompt_text
	_refresh_hook_prompt()
	queue_redraw()


func set_available(available: bool) -> void:
	super.set_available(available)
	if not is_node_ready():
		return
	hook_area.monitoring = available
	proximity_area.monitoring = available
	_refresh_hook_prompt()


func is_hook_prompt_visible() -> bool:
	return hook_prompt.visible


func _draw() -> void:
	var top := Vector2(0.0, -vine_length)
	var control_a := Vector2(10.0, -vine_length * 0.64)
	var control_b := Vector2(-8.0, -vine_length * 0.28)
	var vine_points := PackedVector2Array()
	for index: int in range(13):
		var t := float(index) / 12.0
		vine_points.append(_cubic_point(top, control_a, control_b, Vector2.ZERO, t))
	draw_polyline(vine_points, Color("#344b29"), 7.0, true)
	draw_polyline(vine_points, Color("#87a853"), 4.0, true)

	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color("#344b29"), ring_thickness + 3.0, true)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color("#b5cb67"), ring_thickness, true)
	draw_circle(Vector2.ZERO, hook_radius * 0.42, Color("#d9ed8a", 0.55))
	draw_circle(Vector2.ZERO, hook_radius * 0.16, Color("#f5f7c5", 0.9))

	# Small leaves make the procedural vine readable without adding an asset dependency.
	_draw_leaf(Vector2(4.0, -vine_length * 0.58), Vector2(17.0, -vine_length * 0.69))
	_draw_leaf(Vector2(-3.0, -vine_length * 0.31), Vector2(-17.0, -vine_length * 0.22))


func _cubic_point(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var inverse_t := 1.0 - t
	return (
		a * inverse_t * inverse_t * inverse_t
		+ b * 3.0 * inverse_t * inverse_t * t
		+ c * 3.0 * inverse_t * t * t
		+ d * t * t * t
	)


func _draw_leaf(base: Vector2, tip: Vector2) -> void:
	var middle := base.lerp(tip, 0.5)
	var normal := (tip - base).normalized().orthogonal() * 3.0
	var outline := PackedVector2Array([base, middle + normal, tip, middle - normal])
	draw_colored_polygon(outline, Color("#79aa46"))
	draw_polyline(outline, Color("#344b29"), 1.0, true)


func _update_collision_shapes() -> void:
	var hook_shape := hook_collision.shape as CircleShape2D
	if hook_shape == null:
		hook_shape = CircleShape2D.new()
		hook_collision.shape = hook_shape
	hook_shape.radius = hook_radius

	var prompt_shape := proximity_collision.shape as CircleShape2D
	if prompt_shape == null:
		prompt_shape = CircleShape2D.new()
		proximity_collision.shape = prompt_shape
	prompt_shape.radius = prompt_radius


func _on_proximity_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_nearby_player = player
	if not player.form_controller.form_changed.is_connected(_on_player_form_changed):
		player.form_controller.form_changed.connect(_on_player_form_changed)
	_refresh_hook_prompt()


func _on_proximity_body_exited(body: Node2D) -> void:
	if body != _nearby_player:
		return
	_disconnect_player()
	_refresh_hook_prompt()


func _on_player_form_changed(_form_id: StringName) -> void:
	_refresh_hook_prompt()


func _refresh_hook_prompt() -> void:
	var should_show := (
		is_available()
		and is_instance_valid(_nearby_player)
		and _nearby_player.current_form_id() == &"mature"
	)
	hook_prompt.visible = should_show
	hook_prompt_changed.emit(should_show)


func _disconnect_player() -> void:
	if is_instance_valid(_nearby_player):
		var callback := Callable(self, "_on_player_form_changed")
		if _nearby_player.form_controller.form_changed.is_connected(callback):
			_nearby_player.form_controller.form_changed.disconnect(callback)
	_nearby_player = null


func _exit_tree() -> void:
	_disconnect_player()
