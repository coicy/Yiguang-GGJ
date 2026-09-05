extends SceneTree
## Exercise the actual player and Spine scenes with retired attack inputs.

const PLAYER: PackedScene = preload("res://features/player/player.tscn")
var _checks: int = 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(InputMap.has_action(&"attack"), "Legacy attack action remains queryable")
	_expect(InputMap.action_get_events(&"attack").is_empty(), "Attack has no bound events")
	var key := InputEventKey.new()
	key.keycode = KEY_J
	key.physical_keycode = KEY_J
	key.pressed = true
	_expect(not key.is_action(&"attack"), "J no longer maps to attack")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	_expect(not left.is_action(&"attack") and not right.is_action(&"attack"), "Neither mouse button maps to attack")
	_expect(left.is_action_pressed(&"ability_primary"), "Left click still maps to the primary ability")

	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000.0, 40.0)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = 40.0
	root.add_child(floor_body)
	var player := PLAYER.instantiate() as Player
	player.position = Vector2(0.0, 20.0)
	root.add_child(player)
	_expect(player.find_children("*Combat*", "", true, false).is_empty(), "Player has no combat nodes")
	_expect(player.find_children("*Attack*", "", true, false).is_empty(), "Player has no attack nodes")
	_expect(not player.has_method(&"attack") and not player.has_method(&"receive_damage"), "Player exposes no combat commands")
	var animation: PlayerAnimationMachine = player.visuals.animation_machine
	for form_id: StringName in [&"sprout", &"humanoid", &"mature"]:
		player.form_controller.restore_form(form_id)
		await _frames(60)
		_expect(player.is_on_floor() and player.current_state() == StateMachine.STATE_IDLE, "%s settles in normal idle" % form_id)
		var sprites := player.find_children("*", "SpineSprite", true, false)
		_expect(sprites.size() == 1, "%s uses its real Spine sprite" % form_id)
		_expect(animation.current_animation_state() == PlayerAnimationMachine.STATE_IDLE, "%s plays the real idle animation" % form_id)
		var position_before := player.position
		Input.action_press(&"attack")
		Input.parse_input_event(key)
		await _frames(8)
		_expect(player.current_state() == StateMachine.STATE_IDLE, "%s ignores attack and J in idle" % form_id)
		_expect(player.position.distance_to(position_before) < 0.1 and player.velocity.is_zero_approx(), "%s attack input does not move the player" % form_id)
		_expect(animation.current_animation_state() == PlayerAnimationMachine.STATE_IDLE, "%s does not enter an attack animation" % form_id)
		Input.action_release(&"attack")
		key.pressed = false
		Input.parse_input_event(key)
		Input.action_press(&"move_right")
		await _frames(30)
		var running_speed := player.velocity.x
		position_before = player.position
		Input.action_press(&"attack")
		key.pressed = true
		Input.parse_input_event(key)
		await _frames(8)
		_expect(player.current_state() == StateMachine.STATE_RUN and player.position.x > position_before.x, "%s keeps moving while attack is held" % form_id)
		_expect(is_equal_approx(player.velocity.x, running_speed), "%s attack input leaves running speed unchanged" % form_id)
		_expect(animation.current_animation_state() == PlayerAnimationMachine.STATE_MOVE, "%s retains the movement animation" % form_id)
		Input.action_release(&"attack")
		Input.action_release(&"move_right")
		key.pressed = false
		Input.parse_input_event(key)
		key.pressed = true
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	print("ATTACK DISABLED: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for step: int in range(count):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
