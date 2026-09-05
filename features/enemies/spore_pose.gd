class_name SporePose
extends RefCounted
## Shared body mechanics for rendering and the physics-time muzzle position.
var body: Vector2 = Vector2.ZERO
var pitch: float = 0.0
var squash: float = 0.0
var nozzle: float = 0.0
var extension: float = 0.0
var leaf: float = 0.0
var spread: float = 0.0
var lift: float = 0.0
var wilt: float = 0.0

static func sample(enemy: CombatEnemy, clock_time: float) -> SporePose:
	var result := SporePose.new()
	var brain: SporeBehavior = enemy.spore_behavior
	var tuning: SporeTuning = brain.tuning
	var time: float = enemy.elapsed
	var breath: float = sin(clock_time * 2.5)
	result.squash = breath * 0.018
	result.pitch = sin(clock_time * 1.5) * 0.025
	result.nozzle = brain.aim_angle * 0.4 + breath * 0.035
	result.leaf = sin(clock_time * 2.5 - 0.8) * 0.07
	result.spread = -breath * 0.25
	if enemy.state == &"recover" and brain.parry_recovery_pose != null:
		return brain.parry_recovery_pose.blended(result, smoothstep(0.0, brain.recovery_duration, time))
	if enemy.state in [&"windup", &"strike", &"recover"]:
		var windup: float = brain.windup_duration()
		var strike: float = tuning.spit_duration if enemy.attack_kind == &"spit" else tuning.lash_duration
		var recover: float = tuning.spit_recovery if enemy.attack_kind == &"spit" else tuning.lash_recovery
		var progress: float = clampf(time / windup, 0.0, 1.0)
		if enemy.state == &"strike":
			progress = 1.0 + clampf(time / strike, 0.0, 1.0)
		elif enemy.state == &"recover":
			progress = 2.0 + clampf(time / recover, 0.0, 1.0)
		# phase, body x/y, stem pitch, squash, nozzle pitch, leaf lag, root spread/lift, neck extension
		var keys: Array[Array]
		if enemy.attack_kind == &"spit":
			keys = [
				[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
				[0.42, -2, 2, -0.06, 0.10, -0.12, 0.15, 1.8, 0, -1],
				[1.0, -6, 3, -0.18, 0.21, -0.14, 0.30, 4.0, 0, -3],
				[1.33, 5, -3, 0.22, -0.14, -0.22, -0.36, 5.0, 0, 3],
				[1.63, -4, 1, -0.16, 0.07, 0.28, 0.35, 4.3, 1.0, -2],
				[2.0, -2, 2, -0.05, 0.055, 0.13, 0.20, 2.5, 0, -1],
				[2.30, 1, 0, 0.045, -0.025, -0.07, -0.13, 1.0, 0, 0],
				[3.0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			]
		else:
			keys = [
				[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
				[0.5, -3, 3, -0.10, 0.10, -0.18, 0.15, 2.5, 0, -2],
				[1.0, -9, 5, -0.32, 0.20, -0.36, 0.38, 5.0, 0, -3],
				[1.36, 9, -1, 0.52, -0.12, -0.22, -0.55, 6.0, 0, 4],
				[1.68, 6, 2, 0.34, 0.08, 0.20, -0.10, 5.5, 0, 2],
				[2.0, 3, 3, 0.20, 0.07, 0.15, 0.25, 4.0, 0, 0],
				[2.35, -2, 0, -0.10, -0.04, -0.12, 0.16, 1.5, 0, -1],
				[3.0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			]
		result = _sample_keys(keys, progress)
		if enemy.attack_kind == &"spit":
			result.nozzle += brain.aim_angle - result.pitch
			if enemy.state in [&"windup", &"strike"]:
				result.aim_at(enemy.to_local(brain.aim_point) * Vector2(enemy.facing, 1.0))
	elif enemy.state == &"notice":
		var alert: float = sin(clampf(time / tuning.notice_duration, 0.0, 1.0) * PI)
		result.body = Vector2(-1.0, -3.0) * alert
		result.squash = -0.07 * alert
		result.nozzle = -0.18 * alert
		result.leaf = -0.25 * alert
		result.spread = 1.5 * alert
	elif enemy.state == &"turn":
		var turn: float = sin(clampf(time / tuning.turn_duration, 0.0, 1.0) * PI)
		result.body.y = 3.0 * turn
		result.squash = 0.1 * turn
		result.leaf = 0.25 * turn
		result.spread = 2.0 * turn
	elif enemy.state == &"stun":
		var strength: float = 1.0 if brain.reaction == &"light" else 1.65
		var side: float = brain.hit_direction * enemy.facing
		var catch: float = smoothstep(0.0, 0.045, time)
		var decay: float = 1.0 - smoothstep(0.08, brain.stun_duration, time)
		if brain.reaction == &"parry":
			catch = 1.0
			decay = 1.0 - smoothstep(brain.stun_duration * 0.6, brain.stun_duration, time)
		var recoil: float = strength * catch * decay
		result.body = Vector2(side * 7.0, 2.0) * recoil
		result.pitch = side * 0.34 * recoil
		result.squash = 0.12 * recoil
		result.nozzle = -side * 0.32 * recoil
		result.leaf = -side * 0.50 * recoil
		result.spread = 4.5 * recoil
		result.lift = 2.0 * recoil
		if brain.reaction == &"parry":
			result.body.y -= 5.0 * recoil
			result.nozzle -= 0.40 * recoil
			result.squash = -0.10 * recoil
			if brain.parry_pose != null:
				var opened := result
				result = brain.parry_pose.blended(opened, smoothstep(0.0, 0.075, time))
				result.nozzle = lerpf(brain.parry_pose.nozzle, opened.nozzle, smoothstep(0.0, 0.04, time))
	elif enemy.state == &"dead":
		var fall: float = smoothstep(0.0, enemy.definition.death_duration * 0.7, time)
		var side: float = brain.hit_direction * enemy.facing
		result.body = Vector2(side * 11.0, 7.0) * fall
		result.pitch = side * 1.12 * fall
		result.squash = 0.22 * fall
		result.nozzle = 0.45 * fall
		result.leaf = 0.8 * fall
		result.spread = 2.0 * sin(fall * PI)
		result.wilt = fall
	return result

static func _sample_keys(keys: Array[Array], time: float) -> SporePose:
	for i: int in range(1, keys.size()):
		if time <= float(keys[i][0]):
			var blend: float = smoothstep(float(keys[i - 1][0]), float(keys[i][0]), time)
			return _from_key(keys[i - 1]).blended(_from_key(keys[i]), blend)
	return _from_key(keys.back())

static func _from_key(key: Array) -> SporePose:
	var pose := SporePose.new()
	pose.body = Vector2(key[1], key[2])
	pose.pitch = key[3]
	pose.squash = key[4]
	pose.nozzle = key[5]
	pose.leaf = key[6]
	pose.spread = key[7]
	pose.lift = key[8]
	pose.extension = key[9]
	return pose

func blended(other: SporePose, weight: float) -> SporePose:
	var pose := SporePose.new()
	pose.body = body.lerp(other.body, weight)
	pose.pitch = lerpf(pitch, other.pitch, weight)
	pose.squash = lerpf(squash, other.squash, weight)
	pose.nozzle = lerpf(nozzle, other.nozzle, weight)
	pose.extension = lerpf(extension, other.extension, weight)
	pose.leaf = lerpf(leaf, other.leaf, weight)
	pose.spread = lerpf(spread, other.spread, weight)
	pose.lift = lerpf(lift, other.lift, weight)
	pose.wilt = lerpf(wilt, other.wilt, weight)
	return pose

func body_transform() -> Transform2D:
	return Transform2D(pitch, Vector2(1.0 + squash, 1.0 - squash * 0.65), 0.0, Vector2(0.0, -10.0) + body)

func neck_transform() -> Transform2D:
	return Transform2D(nozzle, Vector2(5.0 + extension, -25.0))

func muzzle_local() -> Vector2:
	return body_transform() * neck_transform() * Vector2(25.0, 0.0)

func aim_at(local_point: Vector2) -> void:
	# Invert the complete body transform, including its nonuniform squash. Subtracting
	# body pitch alone leaves the painted nozzle axis tilted away from the launch ray.
	var target_in_body: Vector2 = body_transform().affine_inverse() * local_point
	nozzle = (target_in_body - neck_transform().origin).angle()

func muzzle_direction_local() -> Vector2:
	return (body_transform() * neck_transform()).x.normalized()
