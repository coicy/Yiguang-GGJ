extends SceneTree
const HUMAN: PackedScene = preload("res://features/player/visuals/part2_spine_visual.tscn")
const MATURE: PackedScene = preload("res://features/player/visuals/part3_spine_visual.tscn")
const HUMAN_POSES: CombatPoseLibrary = preload("res://features/combat/data/humanoid_poses.tres")
const MATURE_POSES: CombatPoseLibrary = preload("res://features/combat/data/mature_poses.tres")
const ACTIONS: Array[StringName] = [&"light_1", &"light_2", &"light_3", &"heavy", &"air", &"dash", &"parry", &"parry_success", &"hurt"]
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	_verify_sprout_rig()
	_verify_sprout_body()
	_verify_rig(HUMAN, HUMAN_POSES)
	_verify_rig(MATURE, MATURE_POSES)
	print("PASS combat visual poses: sprout bump plus 18 evolved actions; finite transforms; no accumulation; locomotion and death restoration")
	quit()
func _verify_rig(scene: PackedScene, library: CombatPoseLibrary) -> void:
	var visual := scene.instantiate() as SpineCharacterVisual
	var reference := scene.instantiate() as SpineCharacterVisual
	root.add_child(visual)
	root.add_child(reference)
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	reference.process_mode = Node.PROCESS_MODE_DISABLED
	visual.play_animation(&"move", true)
	reference.play_animation(&"move", true)
	var skeleton: Object = visual.spine_sprite.get_skeleton()
	for action: StringName in ACTIONS:
		assert(library.poses.has(String(action)), "Missing action: %s" % action)
		for progress: float in [0.0, 0.2, 0.4, 0.6, 0.85, 1.0]:
			visual.combat_pose = library.rotations(action, progress)
			visual.combat_offsets = library.offsets(action, progress)
			for bone_name: String in visual.combat_pose:
				assert(skeleton.find_bone(bone_name) != null, "Pose references missing bone: %s" % bone_name)
			visual.spine_sprite.update_skeleton(0.0)
			var first: Transform2D = skeleton.find_bone(&"hand_L_2").get_transform()
			for repeat_index in range(30):
				visual.spine_sprite.update_skeleton(0.0)
			_assert_transform(first, skeleton.find_bone(&"hand_L_2").get_transform(), "Combat pose accumulated")
		visual.combat_pose = {}
		visual.combat_offsets = {}
		visual.spine_sprite.update_skeleton(0.0)
		reference.spine_sprite.update_skeleton(0.0)
		_compare_bones(visual, reference, "Locomotion restoration")
	# Attacking must not freeze the running feet.
	visual.combat_pose = library.rotations(&"light_1", 0.4)
	visual.spine_sprite.update_skeleton(0.17)
	reference.spine_sprite.update_skeleton(0.17)
	_assert_transform(skeleton.find_bone(&"leg_L3").get_transform(), reference.spine_sprite.get_skeleton().find_bone(&"leg_L3").get_transform(), "Combat changed locomotion feet")
	visual.combat_pose = {}
	visual.play_animation(&"death", false)
	reference.play_animation(&"death", false)
	visual.spine_sprite.update_skeleton(0.2)
	reference.spine_sprite.update_skeleton(0.2)
	_compare_bones(visual, reference, "Death restoration")
	visual.free()
	reference.free()
func _compare_bones(visual: SpineCharacterVisual, reference: SpineCharacterVisual, message: String) -> void:
	for bone_name: StringName in [&"z2", &"leg_L3", &"leg_R3", &"z3", &"z4", &"head_2", &"hand_L_2", &"hand_L_1", &"hand_L_3", &"hand_R", &"hand_R2"]:
		_assert_transform(visual.spine_sprite.get_skeleton().find_bone(bone_name).get_transform(), reference.spine_sprite.get_skeleton().find_bone(bone_name).get_transform(), message + " / " + bone_name)
func _assert_transform(a: Transform2D, b: Transform2D, message: String) -> void:
	assert(a.is_finite() and b.is_finite(), message + " non-finite transform")
	assert(a.origin.distance_to(b.origin) < 0.001 and absf(angle_difference(a.get_rotation(), b.get_rotation())) < 0.001, message)

func _verify_sprout_rig() -> void:
	var scene: PackedScene = load("res://features/player/visuals/part1_spine_visual.tscn")
	var library: CombatPoseLibrary = load("res://features/combat/data/sprout_poses.tres")
	var visual := scene.instantiate() as SpineCharacterVisual
	var reference := scene.instantiate() as SpineCharacterVisual
	root.add_child(visual)
	root.add_child(reference)
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	reference.process_mode = Node.PROCESS_MODE_DISABLED
	var skeleton: Object = visual.spine_sprite.get_skeleton()
	var pose_bones: Array = library.poses["sprout_bump"].keys() + library.bone_offsets["sprout_bump"].keys()
	for face: float in [-1.0, 1.0]:
		visual.set_facing(face)
		for progress: float in [0.0, 0.235, 0.353, 0.588, 0.8, 1.0]:
			visual.combat_pose = library.rotations(&"sprout_bump", progress)
			visual.combat_offsets = library.offsets(&"sprout_bump", progress)
			visual.spine_sprite.update_skeleton(0.0)
			var first: Dictionary = {}
			for bone_name: String in pose_bones:
				assert(skeleton.find_bone(bone_name) != null, "Sprout pose references a missing bone")
				first[bone_name] = skeleton.find_bone(bone_name).get_transform()
			for repeat_index in range(30):
				visual.spine_sprite.update_skeleton(0.0)
			for bone_name: String in first:
				_assert_transform(first[bone_name], skeleton.find_bone(bone_name).get_transform(), "Sprout pose accumulated")
		visual.combat_pose = {}
		visual.combat_offsets = {}
		visual.spine_sprite.update_skeleton(0.0)
		reference.spine_sprite.update_skeleton(0.0)
		for bone_name: String in pose_bones:
			_assert_transform(skeleton.find_bone(bone_name).get_transform(), reference.spine_sprite.get_skeleton().find_bone(bone_name).get_transform(), "Sprout idle restoration")
	visual.combat_pose = library.rotations(&"sprout_bump", 0.353)
	visual.combat_offsets = library.offsets(&"sprout_bump", 0.353)
	visual.spine_sprite.update_skeleton(0.0)
	visual.combat_pose = {}
	visual.combat_offsets = {}
	visual.play_animation(&"death", false)
	reference.play_animation(&"death", false)
	visual.spine_sprite.update_skeleton(0.2)
	reference.spine_sprite.update_skeleton(0.2)
	for bone_name: String in pose_bones:
		_assert_transform(skeleton.find_bone(bone_name).get_transform(), reference.spine_sprite.get_skeleton().find_bone(bone_name).get_transform(), "Sprout death restoration")
	visual.free()
	reference.free()

func _verify_sprout_body() -> void:
	var scene: PackedScene = load("res://features/player/player.tscn")
	var actor := scene.instantiate() as Player
	root.add_child(actor)
	actor.set_physics_process(false)
	var library: CombatPoseLibrary = load("res://features/combat/data/sprout_poses.tres")
	var host := actor.visuals.visual_host
	var resting := host.transform
	var body_position := actor.position
	var shape_scale := actor.get_node("CollisionShape2D").scale as Vector2
	for face: float in [-1.0, 1.0]:
		actor.combat.state = &"attack"
		actor.combat.attack = actor.combat.tuning.find_attack(&"sprout_bump")
		actor.combat.facing = face
		for progress: float in [0.0, 0.235, 0.353, 0.588, 0.8, 1.0]:
			actor.combat.elapsed = progress * actor.combat.attack.duration()
			actor.visuals.set_combat_state(actor.combat)
			var pose := library.body_transform(&"sprout_bump", progress)
			assert(host.transform.is_finite(), "Bump body transform must stay finite")
			assert(absf(host.rotation - pose.get_rotation() * face) < 0.001, "Bump lean mirrors with facing")
			assert(absf(host.position.x - resting.origin.x - pose.origin.x * face) < 0.001, "Bump recoil mirrors with facing")
			assert(absf(host.scale.x * host.scale.y - 1.0) < 0.05, "Bump squash keeps apparent volume")
			assert(actor.position == body_position and actor.get_node("CollisionShape2D").scale == shape_scale, "Visual deformation must not move or scale physics")
		actor.combat.cancel()
		actor.visuals.set_combat_state(actor.combat)
		assert(host.transform.is_equal_approx(resting), "Bump cancellation restores body transform")
	actor.combat.state = &"attack"
	actor.combat.attack = actor.combat.tuning.find_attack(&"sprout_bump")
	actor.combat.elapsed = 0.12
	actor.visuals.set_combat_state(actor.combat)
	actor.visuals.play_death()
	assert(host.transform.is_equal_approx(resting), "Death immediately clears recoil and stretch")
	actor.form_controller.restore_form(&"humanoid")
	assert(host.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(host.rotation), "Growth never inherits sprout deformation")
	actor.free()
