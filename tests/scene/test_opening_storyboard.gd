extends SceneTree
## Verify the production storyboard without creating a separate playable level.

var _finished_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://features/ui/opening_storyboard.tscn") as PackedScene
	assert(scene != null, "Opening storyboard must load independently.")
	var storyboard := scene.instantiate() as Control
	root.add_child(storyboard)
	storyboard.connect(&"finished", func() -> void: _finished_count += 1)
	paused = true
	storyboard.call(&"play")
	await process_frame
	assert(storyboard.visible and storyboard.can_process(), "Opening must operate while gameplay is paused.")
	assert(int(storyboard.get(&"slide_index")) == 0, "Playback must begin on image one.")
	storyboard.call(&"advance")
	assert(int(storyboard.get(&"slide_index")) == 0,
		"A click during fade-in must reveal the current image without skipping it.")
	for expected_index: int in range(1, 5):
		storyboard.call(&"advance")
		assert(int(storyboard.get(&"slide_index")) == expected_index, "Images must advance in supplied order.")
		assert(_finished_count == 0 and storyboard.visible, "All five images must remain playable.")
		storyboard.call(&"advance")
		assert(int(storyboard.get(&"slide_index")) == expected_index,
			"A rapid second click must finish the new image fade, not skip the image.")
	storyboard.call(&"advance")
	assert(_finished_count == 1 and not storyboard.visible, "The final image must complete playback once.")
	storyboard.call(&"advance")
	storyboard.call(&"skip")
	assert(_finished_count == 1, "Input after completion must not emit duplicate completion.")
	storyboard.call(&"play")
	assert(int(storyboard.get(&"slide_index")) == 0 and storyboard.visible, "Replay must reset to image one.")
	await create_timer(0.4).timeout
	storyboard.call(&"advance")
	assert(int(storyboard.get(&"slide_index")) == 1, "A completed fade must permit one-click advancement.")
	storyboard.call(&"skip")
	storyboard.call(&"skip")
	assert(_finished_count == 2 and not storyboard.visible, "Skip must finish exactly once, including during a fade.")
	paused = false
	storyboard.queue_free()
	await process_frame
	print("PASS: opening image order, fade completion, rapid clicks, replay, skip and single completion")
	quit()
