extends SceneTree
## Captures the production room, not a separate playable map.
const MAIN = preload("res://scenes/app/main.tscn")
func _init() -> void:
 call_deferred("_run")
func _run() -> void:
 var args := OS.get_cmdline_user_args()
 var shot: String = args[0] if not args.is_empty() else "chamber"
 var guide := shot == "guide"
 root.size = Vector2i(1840,1088) if guide else Vector2i(1280,720)
 root.content_scale_size = root.size
 var scene := MAIN.instantiate()
 root.add_child(scene)
 current_scene = scene
 var level := scene.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
 await process_frame
 await process_frame
 level.set_process(false)
 level._player.set_physics_process(false)
 level._camera_host.process_mode = Node.PROCESS_MODE_DISABLED
 level._phantom_camera.process_mode = Node.PROCESS_MODE_DISABLED
 level._encounter_camera.process_mode = Node.PROCESS_MODE_DISABLED
 level._camera.limit_left = -100000
 level._camera.limit_top = -100000
 level._camera.limit_right = 100000
 level._camera.limit_bottom = 100000
 if guide:
  for branch: String in ["Actors","Areas","Checkpoints","Interface","CombatHud","Geometry/Mechanisms"]:
   level.get_node(branch).hide()
  level._camera.global_position = Vector2(300,432)
  level._camera.zoom = Vector2(2,2)
 else:
  level._player.form_controller.switch_to(&"sprout" if shot == "entry" else &"humanoid")
  level._player.global_position = Vector2(65,530) if shot == "entry" else Vector2(390,530)
  level._camera.global_position = Vector2(154,433) if shot == "entry" else Vector2(472,426)
  level._camera.zoom = Vector2(2.5,2.5) if shot == "entry" else Vector2(2.25,2.25)
  level.combat_hud.set_progress("01 / 培养室", "穿过根洞 · 按住 E 吸收营养 · 跳跃向上",0,0)
 level._camera.reset_smoothing()
 level._camera.force_update_scroll()
 await process_frame
 if not guide: await create_timer(3.2).timeout
 await RenderingServer.frame_post_draw
 var dir := ProjectSettings.globalize_path("res://build/qa/room-sample")
 DirAccess.make_dir_recursive_absolute(dir)
 var output := dir.path_join("nursery_%s.%s" % [shot, "png" if guide else "webp"])
 var capture := root.get_texture().get_image()
 if guide: capture.save_png(output)
 else: capture.save_webp(output)
 print("ROOM_CAPTURE ", output)
 scene.queue_free()
 await process_frame
 await process_frame
 quit()
