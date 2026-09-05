class_name CombatPoseLibrary
extends Resource
## Editable anticipation, impact, follow-through angles (degrees) for each bone.
## The fourth key is an implicit return to the source animation at progress 1.
@export var poses: Dictionary = {}
@export var phase_times: Dictionary = {}
## Optional per-action/bone anticipation, impact and follow-through times.
## Staggering the torso, upper arm, forearm and wrist passes the impulse outward.
@export var bone_phase_times: Dictionary = {}
## Optional recoil, impact and settle transforms for the visual body only.
@export var body_transforms: Dictionary = {}
## Local offsets for IK targets and other translated bones, in Spine rig units.
@export var bone_offsets: Dictionary = {}

func rotations(action: StringName, progress: float) -> Dictionary:
	var pose: Dictionary = poses.get(String(action), {})
	var action_phases: Vector3 = phase_times.get(String(action), Vector3(0.26, 0.44, 0.64))
	var bone_phases: Dictionary = bone_phase_times.get(String(action), {})
	var output: Dictionary = {}
	for bone: String in pose:
		var keys: Vector3 = pose[bone]
		var phases: Vector3 = bone_phases.get(bone, action_phases)
		var value: float
		if progress < phases.x:
			value = lerpf(0.0, keys.x, smoothstep(0.0, phases.x, progress))
		elif progress < phases.y:
			value = lerpf(keys.x, keys.y, smoothstep(phases.x, phases.y, progress))
		elif progress < phases.z:
			value = lerpf(keys.y, keys.z, smoothstep(phases.y, phases.z, progress))
		else:
			value = lerpf(keys.z, 0.0, smoothstep(phases.z, 1.0, progress))
		output[bone] = deg_to_rad(value)
	return output

func body_transform(action: StringName, progress: float) -> Transform2D:
	var keys: Array = body_transforms.get(String(action), [])
	if keys.size() != 3:
		return Transform2D.IDENTITY
	var phases: Vector3 = phase_times.get(String(action), Vector3(0.26, 0.44, 0.64))
	var from_pose := Transform2D.IDENTITY
	var to_pose: Transform2D = keys[0]
	var weight := smoothstep(0.0, phases.x, progress)
	if progress >= phases.z:
		from_pose = keys[2]
		to_pose = Transform2D.IDENTITY
		weight = smoothstep(phases.z, 1.0, progress)
	elif progress >= phases.y:
		from_pose = keys[1]
		to_pose = keys[2]
		weight = smoothstep(phases.y, phases.z, progress)
	elif progress >= phases.x:
		from_pose = keys[0]
		to_pose = keys[1]
		weight = smoothstep(phases.x, phases.y, progress)
	return from_pose.interpolate_with(to_pose, weight)

func offsets(action: StringName, progress: float) -> Dictionary:
	var pose: Dictionary = bone_offsets.get(String(action), {})
	var action_phases: Vector3 = phase_times.get(String(action), Vector3(0.26, 0.44, 0.64))
	var bone_phases: Dictionary = bone_phase_times.get(String(action), {})
	var output: Dictionary = {}
	for bone: String in pose:
		var keys: PackedVector2Array = pose[bone]
		if keys.size() != 3:
			continue
		var phases: Vector3 = bone_phases.get(bone, action_phases)
		var value: Vector2
		if progress < phases.x:
			value = Vector2.ZERO.lerp(keys[0], smoothstep(0.0, phases.x, progress))
		elif progress < phases.y:
			value = keys[0].lerp(keys[1], smoothstep(phases.x, phases.y, progress))
		elif progress < phases.z:
			value = keys[1].lerp(keys[2], smoothstep(phases.y, phases.z, progress))
		else:
			value = keys[2].lerp(Vector2.ZERO, smoothstep(phases.z, 1.0, progress))
		output[bone] = value
	return output
