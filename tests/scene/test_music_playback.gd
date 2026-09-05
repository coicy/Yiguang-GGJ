extends SceneTree
## Real decoder regression through the production scene; run with a window/audio driver.
const MAIN := preload("res://scenes/app/main.tscn")
var checks: int = 0
var failures: Array[String] = []
var transitions: Array[Dictionary] = []
var soundscape: GreenhouseSoundscape
func _init() -> void:
	call_deferred("_run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func change(next: StringName) -> void:
	soundscape.set_mode(next)
	var player: AudioStreamPlayer = soundscape._music[soundscape.current_track]
	transitions.append({"mode": next, "track": soundscape.current_track, "position": player.get_playback_position()})
func _run() -> void:
	# Ignore desktop key events; the harness drives actions explicitly.
	root.set_disable_input(true)
	if DisplayServer.get_name() == "headless":
		push_error("Music cursor regression requires actual audio playback, not headless.")
		quit(1)
		return
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	# Keep production soundscape active while making player/encounter simulation stationary.
	level.process_mode = Node.PROCESS_MODE_DISABLED
	soundscape = level.soundscape
	await create_timer(1.6).timeout
	var explore: AudioStreamPlayer = soundscape._music[&"explore"]
	expect(explore.get_playback_position() > 1.0, "Exploration decoder advances")
	change(&"battle")
	var first := soundscape.current_track
	var first_player: AudioStreamPlayer = soundscape._music[first]
	await create_timer(2.0).timeout
	expect(first_player.playing and not first_player.stream_paused, "Previously unused battle track starts after initial fade")
	var decoder := first_player.get_stream_playback()
	var first_position := first_player.get_playback_position()
	expect(first_position > 1.5, "Battle audio actually advances")
	change(&"explore")
	await create_timer(1.5).timeout
	var parked_position := first_player.get_playback_position()
	expect(first_player.stream_paused, "Inactive music parks after fade")
	await create_timer(0.3).timeout
	expect(absf(first_player.get_playback_position() - parked_position) < 0.1, "Parked decoder retains its position")
	change(&"battle")
	expect(soundscape.current_track == first, "Brief reentry keeps the same musical phrase")
	await create_timer(0.4).timeout
	expect(first_player.get_stream_playback() == decoder and first_player.get_playback_position() > parked_position, "Reentry resumes the same decoder beyond its parked cursor")
	# A stale outgoing fade must not pause a rapidly restored active player.
	change(&"explore")
	await create_timer(0.1).timeout
	change(&"battle")
	await create_timer(1.4).timeout
	expect(not first_player.stream_paused and first_player.volume_db > -0.5, "Cancelled fade cannot stop current music")
	var before_pause := first_player.get_playback_position()
	paused = true
	await create_timer(1.4).timeout
	expect(soundscape.current_track == first and first_player.volume_db < -11.0, "Pause ducks music without selecting a new variant")
	expect(first_player.get_playback_position() > before_pause, "Quiet menu preserves music continuity")
	paused = false
	await create_timer(1.4).timeout
	expect(soundscape.current_track == first and first_player.volume_db > -0.5, "Resume restores volume without restarting")
	var round_tracks: Array[StringName] = [first]
	for encounter: int in range(2):
		change(&"explore")
		await create_timer(3.2).timeout
		change(&"battle")
		expect(not round_tracks.has(soundscape.current_track), "All three combat variants play before bag refill")
		round_tracks.append(soundscape.current_track)
		await create_timer(0.4).timeout
		var stable := soundscape.current_track
		change(&"battle")
		expect(soundscape.current_track == stable, "Repeated battle state does not advance the playlist")
	var previous := soundscape.current_track
	var restored_first := false
	for encounter: int in range(3):
		change(&"explore")
		await create_timer(3.2).timeout
		change(&"battle")
		expect(soundscape.current_track != previous, "New shuffle bag has no adjacent repeats")
		previous = soundscape.current_track
		await create_timer(0.3).timeout
		if soundscape.current_track == first:
			restored_first = first_player.get_stream_playback() == decoder and first_player.get_playback_position() > first_position + 3.0
			break
	expect(restored_first, "A reused variant continues beyond its earlier encounter, not zero")
	# Seek close to the authored loop end to verify prolonged-fight rotation.
	var ending: AudioStreamPlayer = soundscape._music[soundscape.current_track]
	var ending_key := soundscape.current_track
	ending.seek(ending.stream.get_length() - 0.35)
	await create_timer(1.8).timeout
	expect(soundscape.current_track != ending_key, "A complete battle loop advances to another variant")
	change(&"boss")
	await create_timer(1.6).timeout
	var boss: AudioStreamPlayer = soundscape._music[&"boss"]
	expect(boss.playing and not boss.stream_paused, "Dedicated replacement boss score plays")
	var boss_cursor := boss.get_playback_position()
	change(&"explore")
	await create_timer(1.4).timeout
	change(&"boss")
	await create_timer(0.3).timeout
	expect(boss.get_playback_position() > boss_cursor, "Boss retries also resume instead of restarting")
	expect(soundscape._music.size() == 5, "Five bounded soundtrack players")
	var log := FileAccess.open("res://build/audio/music_playback_report.json", FileAccess.WRITE)
	log.store_string(JSON.stringify({"checks": checks, "failures": failures, "transitions": transitions}, "  "))
	log.close()
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("MUSIC PLAYBACK: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
