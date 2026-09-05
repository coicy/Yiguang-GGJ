extends SceneTree

const PART1_DATA := preload("res://assets/runtime/characters/part1/m10067_skeleton_data.tres")
const PART2_DATA := preload("res://assets/runtime/characters/part2/p0003_skeleton_data.tres")
const PART3_DATA := preload("res://assets/runtime/characters/part3/part3_skeleton_data.tres")
const PART1_SCENE := preload("res://features/player/visuals/part1_spine_visual.tscn")
const PART2_SCENE := preload("res://features/player/visuals/part2_spine_visual.tscn")
const PART3_SCENE := preload("res://features/player/visuals/part3_spine_visual.tscn")
const PLAYER_SCENE := preload("res://features/player/player.tscn")

const PART1_ANIMATIONS: Array[StringName] = [
	&"death",
	&"idle",
	&"move",
]
const PART2_ANIMATIONS: Array[StringName] = [
	&"death",
	&"idle",
	&"jump_down",
	&"jump_end",
	&"jump_start",
	&"jump_up",
	&"move",
	&"skill",
]
const PART3_ANIMATIONS: Array[StringName] = [
	&"death",
	&"idle",
	&"jump_down",
	&"jump_end",
	&"jump_start",
	&"jump_up",
	&"move",
	&"skill",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_character(PART1_DATA, PART1_ANIMATIONS)
	await _verify_character(PART2_DATA, PART2_ANIMATIONS)
	await _verify_character(PART3_DATA, PART3_ANIMATIONS)
	await _verify_visual_scene(PART1_SCENE, PART1_ANIMATIONS)
	await _verify_visual_scene(PART2_SCENE, PART2_ANIMATIONS)
	await _verify_visual_scene(PART3_SCENE, PART3_ANIMATIONS)
	await _verify_skill_event(PART2_SCENE, 1.2)
	await _verify_skill_event(PART3_SCENE, 1.15)
	await _verify_glide_leaf_rig()
	await _verify_animation_machine()
	await _verify_player_form_visuals()
	await _verify_player_grounding()
	quit()


func _verify_character(data: SpineSkeletonDataResource, animation_names: Array[StringName]) -> void:
	assert(data != null)
	var sprite := SpineSprite.new()
	sprite.skeleton_data_res = data
	root.add_child(sprite)
	await process_frame
	assert(sprite.get_skeleton() != null)
	var skeleton_data: Object = sprite.get_skeleton().get_data()
	assert(skeleton_data != null)
	for animation_name: StringName in animation_names:
		assert(skeleton_data.find_animation(animation_name) != null, "Missing Spine animation: %s" % animation_name)
		assert(sprite.get_animation_state().set_animation(animation_name, false, 0) != null)
		await process_frame
	sprite.free()


func _verify_visual_scene(scene: PackedScene, animation_names: Array[StringName]) -> void:
	var visual: Node = scene.instantiate()
	assert(visual != null)
	root.add_child(visual)
	await process_frame
	assert(visual.current_animation() == &"idle")
	for animation_name: StringName in animation_names:
		assert(visual.has_animation(animation_name))
		assert(visual.play_animation(animation_name, false))
		assert(visual.current_animation() == animation_name)
		await process_frame
	visual.free()


func _verify_skill_event(scene: PackedScene, update_time: float) -> void:
	var visual: Node = scene.instantiate()
	var emitted_events: Array[StringName] = []
	visual.animation_event_emitted.connect(
		func(event_name: StringName) -> void: emitted_events.append(event_name)
	)
	root.add_child(visual)
	await process_frame
	assert(visual.play_animation(&"skill", false))
	var sprite := visual.get_node("%SpineSprite") as SpineSprite
	assert(sprite != null)
	sprite.update_skeleton(update_time)
	assert(emitted_events.has(&"skill"), "The skill animation must emit its Spine skill event.")
	visual.free()


func _verify_glide_leaf_rig() -> void:
	var visual := PART3_SCENE.instantiate() as SpineCharacterVisual
	root.add_child(visual)
	await process_frame
	var skeleton: Object = visual.spine_sprite.get_skeleton()
	var left_leaf: Object = skeleton.find_bone(&"z21")
	var right_leaf: Object = skeleton.find_bone(&"z24")
	assert(left_leaf != null and right_leaf != null)
	var left_setup: float = left_leaf.get_transform().get_rotation()
	var right_setup: float = right_leaf.get_transform().get_rotation()
	visual.set_gliding(true)
	await create_timer(0.25).timeout
	visual.spine_sprite.update_skeleton(0.0)
	assert(absf(left_leaf.get_transform().get_rotation() - left_setup) > deg_to_rad(20.0))
	assert(absf(right_leaf.get_transform().get_rotation() - right_setup) > deg_to_rad(20.0))
	visual.set_gliding(false)
	await create_timer(0.25).timeout
	visual.spine_sprite.update_skeleton(0.0)
	assert(is_equal_approx(left_leaf.get_transform().get_rotation(), left_setup))
	assert(is_equal_approx(right_leaf.get_transform().get_rotation(), right_setup))
	visual.free()


func _verify_animation_machine() -> void:
	var visual := PART2_SCENE.instantiate() as SpineCharacterVisual
	var machine := PlayerAnimationMachine.new()
	root.add_child(visual)
	root.add_child(machine)
	await process_frame
	machine.set_visual(visual)
	assert(machine.current_animation_state() == &"idle")
	machine.set_locomotion_state(StateMachine.STATE_RUN)
	assert(machine.current_animation_state() == &"move")
	machine.set_locomotion_state(StateMachine.STATE_JUMP)
	assert(machine.current_animation_state() == &"jump_start")
	await create_timer(0.55).timeout
	assert(machine.current_animation_state() == &"jump_up")
	machine.set_locomotion_state(StateMachine.STATE_FALL)
	assert(machine.current_animation_state() == &"jump_down")
	machine.set_locomotion_state(StateMachine.STATE_IDLE)
	assert(machine.current_animation_state() == &"jump_end")
	await create_timer(0.55).timeout
	assert(machine.current_animation_state() == &"idle")
	assert(machine.play_skill())
	assert(machine.current_animation_state() == &"skill")
	await create_timer(2.25).timeout
	assert(machine.current_animation_state() == &"idle")
	assert(machine.play_death())
	assert(machine.current_animation_state() == &"death")
	machine.free()
	visual.free()


func _verify_player_form_visuals() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await process_frame
	var visual_host := player.get_node("%VisualHost") as Node2D
	var machine := player.get_node("%AnimationMachine") as PlayerAnimationMachine
	assert(visual_host != null and visual_host.get_child_count() == 1)
	assert(visual_host.get_child(0).name == &"Part1SpineVisual")
	assert(machine.current_animation_state() == &"idle")
	assert(player.form_controller.switch_to(&"humanoid"))
	await process_frame
	assert(visual_host.get_child_count() == 1)
	assert(visual_host.get_child(0).name == &"Part2SpineVisual")
	assert(player.form_controller.switch_to(&"mature"))
	await process_frame
	assert(visual_host.get_child_count() == 1)
	assert(visual_host.get_child(0).name == &"Part3SpineVisual")
	player.free()


func _verify_player_grounding() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await process_frame
	for form_id: StringName in [&"sprout", &"humanoid", &"mature"]:
		if player.current_form_id() != form_id:
			assert(player.form_controller.switch_to(form_id))
			await process_frame
		var form := player.form_controller.get_current()
		var collision := player.collision_shape
		var collision_bottom := collision.position.y
		if collision.shape is CircleShape2D:
			collision_bottom += (collision.shape as CircleShape2D).radius
		else:
			collision_bottom += (collision.shape as CapsuleShape2D).height * 0.5
		assert(is_zero_approx(collision_bottom), "%s collision bottom must align to player origin: %s" % [form_id, collision_bottom])
		var visual_host := player.get_node("%VisualHost") as Node2D
		var visual := visual_host.get_child(0) as SpineCharacterVisual
		assert(visual != null)
		assert(visual.play_animation(&"idle", false))
		visual.spine_sprite.update_skeleton(0.0)
		var bounds: Rect2 = visual.spine_sprite.get_skeleton().get_bounds()
		var visual_bottom := visual_host.position.y + visual.scale.y * bounds.end.y
		assert(absf(visual_bottom) <= 0.05, "%s visual bottom must align to player origin: %s" % [form_id, visual_bottom])
	player.free()
