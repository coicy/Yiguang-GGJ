class_name WardenVisual
extends EnemyVisual
## Jointed reuse of the painted atlas: planted feet -> hips -> core -> head and arms.
var _core: Node2D
var _head: Polygon2D
var _blade: Polygon2D
var _shield: Sprite2D
var _thighs: Array[Sprite2D] = []
var _shins: Array[Sprite2D] = []
var _arms: Array[Sprite2D] = []
var _forearms: Array[Sprite2D] = []
var _feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _knees: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _pose := WardenPose.new()
var _from_pose := WardenPose.new()
var _last_state: StringName = &""
var _last_kind: StringName = &""
var _blend_elapsed: float = 1.0
var _last_position := Vector2.ZERO
var _stride: float = 0.0
var _gait_weight: float = 0.0
var _strike_start_x: float = 0.0

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	_rig = Node2D.new()
	_rig.name = "WardenRig"
	add_child(_rig)
	for index: int in range(2):
		_thighs.append(_sprite(Rect2(169, 634, 305, 250), Vector2(105, 45), _rig))
		_shins.append(_sprite(Rect2(200, 856, 326, 388), Vector2(145, 24), _rig))
		_thighs[index].z_index = -2 if index == 0 else -1
		_shins[index].z_index = -2 if index == 0 else 1
		_arms.append(_sprite(Rect2(680, 122, 211, 257), Vector2(135, 57), _rig))
		_forearms.append(_sprite(Rect2(725, 330, 279, 286), Vector2(45, 35), _rig))
		_arms[index].z_index = -1
		_forearms[index].z_index = -1 if index == 0 else 2
	_core = Node2D.new()
	_core.name = "Core"
	_rig.add_child(_core)
	# Polygon cutouts remove the head from the chest without generating replacement art.
	var chest_outline := PackedVector2Array([Vector2(8,258), Vector2(35,137), Vector2(52,64), Vector2(81,82), Vector2(74,137), Vector2(164,114), Vector2(201,148), Vector2(288,109), Vector2(321,191), Vector2(387,191), Vector2(409,222), Vector2(447,246), Vector2(480,227), Vector2(494,187), Vector2(554,143), Vector2(576,225), Vector2(616,284), Vector2(618,375), Vector2(579,414), Vector2(549,486), Vector2(501,544), Vector2(445,620), Vector2(337,620), Vector2(298,546), Vector2(284,484), Vector2(269,460), Vector2(152,462), Vector2(80,409)])
	var chest := _cutout(chest_outline, Vector2(365, 603), _core)
	chest.scale = Vector2.ONE * 0.103
	var head_outline := PackedVector2Array([Vector2(295,5), Vector2(335,15), Vector2(367,62), Vector2(399,111), Vector2(421,111), Vector2(420,68), Vector2(451,9), Vector2(474,2), Vector2(470,69), Vector2(483,116), Vector2(497,156), Vector2(491,194), Vector2(469,233), Vector2(446,247), Vector2(410,223), Vector2(396,194), Vector2(364,193), Vector2(337,153), Vector2(336,105), Vector2(315,81)])
	_head = _cutout(head_outline, Vector2(440, 237), _core)
	_head.position = Vector2(7.7, -37.7)
	_head.scale = Vector2.ONE * 0.103
	var blade_outline := PackedVector2Array([Vector2(919,110), Vector2(981,110), Vector2(1038,128), Vector2(1082,166), Vector2(1104,221), Vector2(1147,281), Vector2(1176,312), Vector2(1235,307), Vector2(1218,383), Vector2(1240,426), Vector2(1233,519), Vector2(1190,598), Vector2(1171,617), Vector2(1178,558), Vector2(1169,516), Vector2(1134,449), Vector2(1093,414), Vector2(1081,374), Vector2(1044,330), Vector2(1011,290), Vector2(974,273), Vector2(934,271), Vector2(920,218), Vector2(904,188)])
	_blade = _cutout(blade_outline, Vector2(961, 187), _rig)
	_blade.z_index = 3
	_shield = _sprite(Rect2(635, 635, 609, 609), Vector2(290, 276), _rig)
	_shield.z_index = 4
	_shield.scale = Vector2.ONE * 0.088
	for part: Sprite2D in [_thighs[0], _shins[0], _arms[0], _forearms[0]]:
		part.modulate = Color("#929b81")
	_last_position = actor.global_position
	_process(0.0)

func _sprite(region: Rect2, pivot: Vector2, host: Node2D) -> Sprite2D:
	var part := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = actor.definition.atlas
	texture.region = region
	texture.filter_clip = true
	part.texture = texture
	part.centered = false
	part.offset = -pivot
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(part)
	return part

func _cutout(outline: PackedVector2Array, pivot: Vector2, host: Node2D) -> Polygon2D:
	var part := Polygon2D.new()
	var points := PackedVector2Array()
	for point: Vector2 in outline:
		points.append(point - pivot)
	part.polygon = points
	part.uv = outline
	part.texture = actor.definition.atlas
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(part)
	return part

func _process(delta: float) -> void:
	if actor == null or actor.warden_behavior == null: return
	_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	modulate = Color(1.6, 1.4, 1.15) if flash_left > 0.0 else Color.WHITE
	var moved := (actor.global_position.x - _last_position.x) * actor.facing
	_last_position = actor.global_position
	var walking := actor.state == &"idle" or (actor.state == &"strike" and actor.attack_kind == &"charge")
	_gait_weight = move_toward(_gait_weight, 1.0 if walking and absf(actor.velocity.x) > 3.0 else 0.0, delta * 12.0)
	if walking:
		_stride += moved / 48.0
	if actor.state != _last_state or actor.attack_kind != _last_kind:
		_from_pose = _pose
		_blend_elapsed = 0.0
		_last_state = actor.state
		_last_kind = actor.attack_kind
		if actor.state == &"strike": _strike_start_x = actor.global_position.x
	_blend_elapsed += delta
	var sampled := WardenPose.sample(actor, _time)
	var blend_time := actor.warden_behavior.tuning.transition_blend
	# Never smooth the weapon away from the physics contact during windup or strike.
	if actor.state in [&"strike", &"windup", &"recover"]:
		_pose = sampled
	else:
		_pose = _from_pose.blended(sampled, smoothstep(0.0, blend_time, _blend_elapsed))
	_rig.scale = Vector2(actor.facing, 1.0)
	if actor.state == &"turn":
		_rig.scale.x *= 1.0 - sin(clampf(actor.elapsed / actor.warden_behavior.tuning.turn_duration, 0, 1) * PI) * 0.83
	_core.position = _pose.hip
	_core.rotation = _pose.torso
	_core.scale = Vector2(1.0 + _pose.squash, 1.0 - _pose.squash)
	_head.rotation = _pose.head
	for index: int in range(2):
		_pose_leg(index)
	_blade.position = _pose.hand
	var blade_axis := Vector2(233, 426)
	_blade.rotation = _pose.blade - blade_axis.angle()
	_blade.scale = Vector2.ONE * actor.warden_behavior.tuning.blade_length / blade_axis.length()
	_shield.position = _pose.shield
	_shield.rotation = _pose.shield_angle
	_pose_arm(0, _pose.shield + Vector2(3, 2))
	_pose_arm(1, _pose.hand)
	_rig.modulate.a = 1.0 - smoothstep(actor.definition.death_duration * 0.78, actor.definition.death_duration, actor.elapsed) if actor.state == &"dead" else 1.0
	queue_redraw()

func _pose_leg(index: int) -> void:
	var hip := _core.transform * Vector2(-10 if index == 0 else 7, -1)
	var foot := _pose.back_foot if index == 0 else _pose.front_foot
	var phase := fposmod(_stride + index * 0.5, 1.0)
	var travel: float
	var lift: float = 0.0
	if phase < 0.6:
		travel = 14.4 - phase * 48.0
	else:
		var swing := (phase - 0.6) / 0.4
		travel = lerpf(-14.4, 14.4, smoothstep(0, 1, swing))
		lift = sin(swing * PI) * 10.0
	foot += Vector2(travel, -lift) * _gait_weight
	if actor.state == &"strike" and actor.attack_kind != &"charge":
		var move := actor.warden_behavior.current_move()
		var travel_from_start := (actor.global_position.x - _strike_start_x) * actor.facing
		# The rear foot anchors the drive; the lead foot clears the floor and catches it.
		if index == 0:
			foot.x -= minf(18.0, maxf(0.0, travel_from_start))
		else:
			foot.y -= sin(clampf(actor.elapsed / move.step_end, 0, 1) * PI) * 7.0
	var knee := _joint(hip, foot, 23.0, 25.0, -1.0 if index == 0 else 1.0)
	_feet[index] = foot
	_knees[index] = knee
	_segment(_thighs[index], hip, knee, Vector2(84, 168))
	_segment(_shins[index], knee, foot, Vector2(22, 312))

func _pose_arm(index: int, hand: Vector2) -> void:
	var shoulder := _core.transform * Vector2(-20 if index == 0 else 17, -31)
	var elbow := _joint(shoulder, hand, 23.0, 24.0, 1.0)
	_segment(_arms[index], shoulder, elbow, Vector2(-58, 163))
	_segment(_forearms[index], elbow, hand, Vector2(157, 156))

func _joint(start: Vector2, end: Vector2, upper: float, lower: float, bend: float) -> Vector2:
	var delta := end - start
	var distance := clampf(delta.length(), 1.0, upper + lower - 0.1)
	var direction := delta.normalized() if delta.length_squared() > 0.01 else Vector2.DOWN
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	return start + direction * along + Vector2(direction.y, -direction.x) * height * bend

func _segment(part: Sprite2D, start: Vector2, end: Vector2, axis: Vector2) -> void:
	var delta := end - start
	part.position = start
	part.rotation = delta.angle() - axis.angle()
	part.scale = Vector2.ONE * delta.length() / axis.length()

func pose_snapshot() -> Dictionary:
	return {"core": _core.transform, "head": _head.transform, "hand": _blade.position, "tip": _pose.blade_tip(actor.warden_behavior.tuning.blade_length), "shield": _shield.transform, "feet": _feet.duplicate(), "knees": _knees.duplicate()}

func _draw() -> void:
	if actor == null or actor.warden_behavior == null: return
	var ai := actor.warden_behavior
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.15))
	draw_circle(Vector2.ZERO, 38, Color(0.025, 0.04, 0.025, 0.35 * _rig.modulate.a))
	draw_set_transform(Vector2.ZERO)
	if actor.state == &"dead": return
	if ai.poise > 0.0 or actor.state == &"stun":
		for index: int in range(6):
			var tint := Color("#ffdc8c") if ai.poise > index else Color("#456052")
			if actor.state == &"stun": tint = Color("#fff2b2")
			draw_line(Vector2(-17 + index * 6, -111), Vector2(-13 + index * 6, -111), tint, 2.0)
	if actor.state == &"windup":
		_draw_tell()
	if actor.state == &"strike":
		_draw_attack()
	if actor.state == &"overload":
		var p := clampf(actor.elapsed / ai.tuning.phase_notice_duration, 0, 1)
		draw_arc(Vector2(0, -48), 24 + p * 23, 0, TAU, 36, Color(1, 0.5, 0.18, sin(p * PI) * 0.65), 2, true)

func _draw_tell() -> void:
	var ai := actor.warden_behavior
	# Keep the tell beside the silhouette and below the production boss HUD.
	var point := Vector2(-44 * actor.facing, -119)
	var danger := not ai.current_move().parryable
	var tint := Color("#ff9875") if danger else Color("#ffe2a0")
	draw_circle(point, 7, Color("#20352d"))
	if danger:
		draw_line(point - Vector2(3, 3), point + Vector2(3, 3), tint, 2, true)
		draw_line(point + Vector2(-3, 3), point + Vector2(3, -3), tint, 2, true)
	else:
		draw_line(point + Vector2(0, -4), point + Vector2(0, 1), tint, 2, true)
		draw_circle(point + Vector2(0, 4), 1, tint)
	var p := clampf(actor.elapsed / ai.current_move().windup, 0, 1)
	draw_arc(point, 10, -PI * 0.5, -PI * 0.5 + TAU * p, 28, tint, 1.4, true)
	if ai.combo_planned or actor.attack_kind == &"backswing":
		for index: int in range(2):
			draw_line(point + Vector2(-4 + index * 6, 15), point + Vector2(-2 + index * 6, 18), tint, 2, true)
	if actor.attack_kind == &"slam":
		var impact := to_local(ai.impact_point())
		draw_line(impact + Vector2(-45, 9), impact + Vector2(45, 9), Color(tint, p * 0.5), 1.7, true)

func _draw_attack() -> void:
	var ai := actor.warden_behavior
	var move := ai.current_move()
	if actor.attack_kind == &"charge":
		for index: int in range(5):
			var age := fposmod(actor.elapsed * 4.0 + index * 0.2, 1.0)
			draw_circle(Vector2(actor.facing * (-28 - age * 32), -1 - age * 8), 1.0 + age * 2, Color(0.7, 0.6, 0.35, (1.0 - age) * 0.5))
	elif actor.attack_kind == &"slam" and actor.elapsed >= move.active_start:
		var p := clampf((actor.elapsed - move.active_start) / (move.duration - move.active_start), 0, 1)
		var point := to_local(ai.impact_point())
		for index: int in range(7):
			var x := (index - 3) * 11.0
			draw_line(point + Vector2(x, 10), point + Vector2(x * (1 + p), 8 - sin(p * PI) * (13 - absf(index - 3) * 2)), Color(1, 0.66, 0.27, (1 - p) * 0.6), 2, true)
	elif actor.elapsed >= move.active_start * 0.6 and actor.elapsed <= move.active_end + 0.04:
		var points := PackedVector2Array()
		for index: int in range(10):
			var t := maxf(0.0, actor.elapsed - index * 0.009)
			var pose := WardenPose.strike_pose(actor.attack_kind, t, move)
			points.append(pose.blade_tip(ai.tuning.blade_length) * Vector2(actor.facing, 1))
		draw_polyline(points, Color(1, 0.8, 0.4, 0.72), 3, true)
