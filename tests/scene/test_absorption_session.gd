extends SceneTree
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const NUTRITION: PackedScene = preload("res://features/level/nutrition_tank.tscn")
const TOXIN: PackedScene = preload("res://features/level/toxin_resource.tscn")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var player := PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var tank := NUTRITION.instantiate() as NutritionTank
	root.add_child(tank)
	tank.set_physics_process(false)
	tank._on_body_entered(player)
	Input.action_press("absorb_resource")
	for step: int in range(390):
		tank._physics_process(1.0 / 60.0)
	assert(player.current_form_id() == &"humanoid", "One held absorption must stop at the first growth threshold.")
	assert(is_zero_approx(player.resources.growth_progress))
	tank._on_body_exited(player)
	tank._on_body_entered(player)
	tank._physics_process(10.0)
	assert(player.current_form_id() == &"humanoid", "Leaving a resource must not bypass the release requirement.")
	Input.action_release("absorb_resource")
	assert(not player.is_absorbing_resource())
	Input.action_press("absorb_resource")
	for step: int in range(390):
		tank._physics_process(1.0 / 60.0)
	assert(player.current_form_id() == &"mature")
	Input.action_release("absorb_resource")
	assert(not player.is_absorbing_resource())
	tank.free()
	var toxin := TOXIN.instantiate() as ToxinResource
	root.add_child(toxin)
	toxin.set_physics_process(false)
	toxin._on_body_entered(player)
	Input.action_press("absorb_resource")
	for step: int in range(390):
		toxin._physics_process(1.0 / 60.0)
	assert(player.current_form_id() == &"humanoid", "One held absorption must stop at the first withering threshold.")
	assert(is_zero_approx(player.resources.toxin_progress))
	Input.action_release("absorb_resource")
	assert(not player.is_absorbing_resource())
	Input.action_press("absorb_resource")
	for step: int in range(390):
		toxin._physics_process(1.0 / 60.0)
	assert(player.current_form_id() == &"sprout")
	Input.action_release("absorb_resource")
	toxin.free()
	player.free()
	print("PASS: release-to-rearm nutrition and toxin absorption")
	# Let queued nodes and the audio mixer release stopped playback before shutdown.
	await process_frame
	await create_timer(0.1).timeout
	quit(0)
