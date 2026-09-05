extends RefCounted
## Visual spring chain in world space. The hand pins the first span;
## length constraints transfer its pull down the vine without stretching leaves.
var _points := PackedVector2Array()
var _velocity := PackedVector2Array()
var _targets := PackedVector2Array()
var _clock: float = -1.0
var _length: float = 0.0
var _direction := Vector2.RIGHT
const MAX_STEP: float = 1.0 / 120.0

func clear() -> void:
	_points.clear()
	_velocity.clear()
	_targets.clear()
	_clock = -1.0

func sample(targets: PackedVector2Array, hand_direction: Vector2, segment_length: float, clock: float, profile: VineWhipProfile) -> PackedVector2Array:
	var direction := hand_direction.normalized()
	var length := maxf(segment_length, 0.01)
	var elapsed := clock - _clock
	if _points.size() != targets.size() or elapsed < -0.00001 or elapsed > 0.1:
		_points = targets.duplicate()
		_velocity.resize(targets.size())
		_velocity.fill(Vector2.ZERO)
		_constrain(_points, targets[0], direction, length, profile.max_joint_bend)
		_targets = targets.duplicate()
		_clock = clock
		_length = length
		_direction = direction
	elif elapsed > 0.00001:
		var steps := maxi(1, int(ceil(elapsed / MAX_STEP)))
		var step := elapsed / float(steps)
		for iteration in range(steps):
			var blend := float(iteration + 1) / float(steps)
			var goals := PackedVector2Array()
			for index in range(targets.size()):
				goals.append(_targets[index].lerp(targets[index], blend))
			var root_direction := Vector2.from_angle(lerp_angle(_direction.angle(), direction.angle(), blend))
			var span := lerpf(_length, length, blend)
			var before := _points.duplicate()
			for index in range(2, _points.size()):
				var along := float(index) / float(_points.size() - 1)
				var stiffness := lerpf(profile.root_spring, profile.tip_spring, along)
				_velocity[index] += ((goals[index] - _points[index]) * stiffness + Vector2.DOWN * profile.motion_gravity) * step
				_velocity[index] *= exp(-profile.motion_damping * step)
				_points[index] += _velocity[index] * step
				# Keep the visual close enough to its authored attack to read the hit window.
				_points[index] = goals[index] + (_points[index] - goals[index]).limit_length(profile.max_motion_lag * along)
			_constrain(_points, goals[0], root_direction, span, profile.max_joint_bend)
			for index in range(2, _points.size()):
				_velocity[index] = ((_points[index] - before[index]) / step).limit_length(1800.0)
		_targets = targets.duplicate()
		_clock = clock
		_length = length
		_direction = direction
	# Render callbacks at an unchanged combat clock may supply a refined hand pose.
	# Project a copy, never integrate or modify the cached simulation a second time.
	var displayed := _points.duplicate()
	_constrain(displayed, targets[0], direction, length, profile.max_joint_bend)
	return displayed

func _constrain(points: PackedVector2Array, root: Vector2, direction: Vector2, length: float, max_bend: float) -> void:
	points[0] = root
	points[1] = root + direction * length
	for iteration in range(6):
		for index in range(points.size() - 1, 1, -1):
			var offset := points[index] - points[index - 1]
			var distance := offset.length()
			if distance <= 0.0001:
				continue
			var correction := offset * ((distance - length) / distance)
			if index == 2:
				points[index] -= correction
			else:
				points[index] -= correction * 0.5
				points[index - 1] += correction * 0.5
	# A final forward pass pins every span exactly and prevents a sharp root kink.
	var previous_direction := direction
	for index in range(2, points.size()):
		var offset := points[index] - points[index - 1]
		var next_direction := offset.normalized() if not offset.is_zero_approx() else previous_direction
		var bend := clampf(previous_direction.angle_to(next_direction), -max_bend, max_bend)
		next_direction = previous_direction.rotated(bend)
		points[index] = points[index - 1] + next_direction * length
		previous_direction = next_direction
