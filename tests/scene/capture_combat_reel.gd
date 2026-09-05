extends SceneTree
## Editable-pose review reel on the production level. This is an animation
## timeline inspection, not input-driven playtest or combat timing evidence.
const MAIN := preload("res://scenes/app/main.tscn")
const ACTIONS := [&"light_1",&"light_2",&"light_3",&"heavy",&"air",&"dash",&"parry",&"parry_success",&"hurt"]
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var actor := level._player
	await process_frame
	level.set_process(false)
	actor.set_physics_process(false)
	level._camera.global_position = Vector2(1100,325)
	level._camera.zoom = Vector2(2.1,2.1)
	level._camera.force_update_scroll()
	for form: StringName in [&"humanoid",&"mature"]:
		actor.form_controller.restore_form(form)
		actor.global_position = Vector2(1030,400)
		for action: StringName in ACTIONS:
			actor.combat.cancel()
			actor.combat.attack = actor.combat.tuning.find_attack(action)
			actor.combat.state = &"attack" if actor.combat.attack != null else action
			actor.combat.facing = 1.0
			var duration := actor.combat.attack.duration()*actor.combat.time_scale_for_form() if actor.combat.attack != null else (0.16 if action == &"dash" else 0.42)
			level.combat_hud.set_progress("动作审查 / "+String(form),String(action)+" · 慢放 / 左右朝向 / 收招恢复",0,0)
			for direction: float in [1.0,-1.0]:
				actor.combat.facing = direction
				# 48 frames per pose gives a slowed motion view for frame inspection.
				for frame in range(48):
					actor.combat.elapsed = duration*float(frame)/47.0
					actor.visuals.set_combat_state(actor.combat)
					await process_frame
			actor.combat.cancel()
			actor.visuals.set_combat_state(actor.combat)
			for frame in range(10):
				await process_frame
	main.queue_free()
	await process_frame
	quit()
