class_name BeetleVisual
extends EnemyVisual
## Six articulated legs, thorax, head and hinged wing case, using the existing art.
var _thorax: Node2D
var _head: Sprite2D
var _shell: Sprite2D
var _upper_legs: Array[Sprite2D] = []
var _lower_legs: Array[Sprite2D] = []
var _feet: Array[Vector2] = []
var _hips: Array[Vector2] = []
var _pose := BeetlePose.new()
var _from_pose := BeetlePose.new()
var _last_state: StringName = &""
var _blend_elapsed: float = 1.0
var _stride: float = 0.0
var _last_position := Vector2.ZERO
var _gait_weight: float = 0.0

func configure(enemy: CombatEnemy) -> void:
	# Historical atlas review scripts also reuse the beetle scene for other species.
	if enemy.definition.kind != EnemyDefinition.Kind.BEETLE:
		super.configure(enemy)
		return
	actor = enemy
	_rig = Node2D.new()
	_rig.name = "BeetleRig"
	add_child(_rig)
	for i: int in range(6):
		_upper_legs.append(_make_sprite(Rect2(170, 634, 288, 213), Vector2(60, 28), _rig))
		_lower_legs.append(_make_sprite(Rect2(270, 790, 225, 438), Vector2(148, 30), _rig))
		_feet.append(Vector2.ZERO)
		_hips.append(Vector2.ZERO)
		var tint := Color("#89917b") if i < 3 else Color.WHITE
		_upper_legs[i].modulate = tint
		_lower_legs[i].modulate = tint
		# Shoulder sockets tuck beneath the carapace; foreground shins overlap it.
		_upper_legs[i].z_index = -1
		_lower_legs[i].z_index = -1 if i < 3 else 2
	_thorax = Node2D.new()
	_thorax.name = "Thorax"
	_rig.add_child(_thorax)
	var body := _make_sprite(Rect2(8, 8, 611, 611), Vector2(305, 350), _thorax)
	body.scale = Vector2.ONE * 0.055
	_head = _make_sprite(Rect2(635, 8, 611, 611), Vector2(128, 345), _thorax)
	_head.position = Vector2(15, -2)
	_head.scale = Vector2.ONE * 0.046
	_shell = _make_sprite(Rect2(635, 635, 611, 611), Vector2(530, 245), _thorax)
	_shell.position = Vector2(6, -10)
	_shell.scale = Vector2.ONE * 0.05
	_last_position = actor.global_position
	_process(0.0)

func _make_sprite(region: Rect2, pivot: Vector2, host: Node2D) -> Sprite2D:
	var part := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = actor.definition.atlas
	atlas.region = region
	atlas.filter_clip = true
	part.texture = atlas
	part.centered = false
	part.offset = -pivot
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(part)
	return part

func _process(delta: float) -> void:
	if actor == null:
		return
	if actor.definition.kind != EnemyDefinition.Kind.BEETLE:
		super._process(delta)
		return
	_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	modulate = Color(1.65, 1.5, 1.35) if flash_left > 0.0 else Color.WHITE
	var moved := actor.global_position.x - _last_position.x
	_last_position = actor.global_position
	var walking := actor.state in [&"idle", &"patrol"] or (actor.state == &"strike" and actor.attack_kind == &"charge")
	_gait_weight = move_toward(_gait_weight, 1.0 if walking and absf(actor.velocity.x) > 3.0 else 0.0, delta * 12.0)
	# A foot's support stroke travels exactly opposite to actual body displacement.
	if walking:
		_stride += moved * actor.facing / 28.0
	if actor.state != _last_state:
		_from_pose = _pose
		_blend_elapsed = 0.0
		_last_state = actor.state
	_blend_elapsed += delta
	var target_pose := BeetlePose.sample(actor, _time)
	var blend_seconds := 0.035 if actor.state in [&"strike", &"stun"] else 0.09
	_pose = _from_pose.blended(target_pose, smoothstep(0.0, blend_seconds, _blend_elapsed))
	_rig.scale = Vector2(actor.facing, 1.0)
	if actor.state == &"turn":
		_rig.scale.x *= 1.0 - sin(clampf(actor.elapsed / actor.beetle_behavior.tuning.turn_duration, 0.0, 1.0) * PI) * 0.82
	_thorax.position = Vector2(-5.0, -20.0) + _pose.body
	_thorax.rotation = _pose.pitch
	_thorax.scale = Vector2(1.0 + _pose.squash, 1.0 - _pose.squash)
	_head.rotation = _pose.head
	_shell.rotation = _pose.shell
	for i: int in range(6):
		_pose_leg(i)
	_rig.modulate.a = 1.0 - smoothstep(actor.definition.death_duration * 0.72, actor.definition.death_duration, actor.elapsed) if actor.state == &"dead" else 1.0
	queue_redraw()

func _pose_leg(i: int) -> void:
	var index := i % 3
	var rear := i < 3
	var hip := _thorax.transform * Vector2(-10.0 + index * 9.5, 3.0 + (0.0 if rear else 2.0))
	var foot := Vector2(-22.0 + index * 21.0 + (3.0 if rear else 0.0), -1.0 if rear else 0.0)
	var phase := fposmod(_stride + (0.5 if (index + (1 if rear else 0)) % 2 == 0 else 0.0), 1.0)
	var travel: float
	var lift: float
	if phase < 0.62:
		travel = 14.0 * 0.62 - phase * 28.0
		lift = 0.0
	else:
		var swing := (phase - 0.62) / 0.38
		travel = lerpf(-14.0 * 0.62, 14.0 * 0.62, smoothstep(0.0, 1.0, swing))
		lift = sin(swing * PI) * 6.0
	foot += Vector2(travel, -lift) * _gait_weight
	foot.x += (index - 1.0) * _pose.spread
	if index == 2:
		foot.y -= _pose.front_lift
	# Rear pair scrapes soil during charge preparation; forelegs bear the load.
	if actor.state == &"windup" and actor.attack_kind == &"charge" and index == 0:
		var scrape := sin(actor.elapsed * 25.0 + (PI if rear else 0.0))
		foot += Vector2(scrape * 3.0, -maxf(0.0, scrape) * 2.0)
	if _pose.curl > 0.0:
		foot = foot.lerp(hip + Vector2((index - 1.0) * 4.0, -7.0), _pose.curl)
	var span := foot - hip
	var distance := clampf(span.length(), 1.0, 26.8)
	var direction := span.normalized()
	var upper_length := 13.0
	var lower_length := 15.0
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var knee := hip + direction * along + Vector2(direction.y, -direction.x) * bend * (-1.0 if index == 0 else 1.0)
	_hips[i] = hip
	_feet[i] = foot
	_segment(_upper_legs[i], hip, knee, Vector2(188, 158))
	_segment(_lower_legs[i], knee, foot, Vector2(-25, 383))

func _segment(part: Sprite2D, start: Vector2, end: Vector2, painted_axis: Vector2) -> void:
	var span := end - start
	part.position = start
	part.rotation = span.angle() - painted_axis.angle()
	part.scale = Vector2.ONE * span.length() / painted_axis.length()

func pose_snapshot() -> Dictionary:
	return {"body": _thorax.transform, "head": _head.transform, "shell": _shell.transform, "feet": _feet.duplicate(), "hips": _hips.duplicate()}

func _draw() -> void:
	if actor == null:
		return
	if actor.definition.kind != EnemyDefinition.Kind.BEETLE:
		super._draw()
		return
	var alpha := _rig.modulate.a
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.19))
	draw_circle(Vector2.ZERO, 25.0, Color(0.03, 0.06, 0.045, 0.32 * alpha))
	draw_set_transform(Vector2.ZERO)
	if actor.state == &"dead":
		return
	_draw_status_bars(-51.0)
	if actor.state == &"windup":
		var point := Vector2(0, -62)
		var tint := Color("#ffe4a1")
		var progress := clampf(actor.elapsed / actor.beetle_behavior.windup_duration(), 0.0, 1.0)
		draw_circle(point, 6.0, Color("#243830"))
		draw_line(point + Vector2(0, -4), point + Vector2(0, 1), tint, 2.0, true)
		draw_circle(point + Vector2(0, 4), 1.0, tint)
		draw_arc(point, 9.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, tint, 1.2, true)
	if (actor.state == &"strike" and actor.attack_kind == &"charge") or (actor.state == &"recover" and absf(actor.velocity.x) > 10.0):
		for i: int in range(5):
			var age := fposmod(actor.elapsed * 3.5 + i * 0.2, 1.0)
			var p := Vector2(actor.facing * (-19.0 - age * 23.0), -2.0 - sin(age * PI) * 5.0)
			draw_circle(p, 0.7 + age, Color(0.68, 0.61, 0.36, (1.0 - age) * 0.45))
