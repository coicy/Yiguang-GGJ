class_name GreenhouseSoundscape
extends Node
## Scene-owned soundtrack and module sounds, mixed from actual gameplay state.
const MUSIC := {
	&"explore": preload("res://assets/runtime/audio/designed/music_explore.ogg"),
	&"battle_roots": preload("res://assets/runtime/audio/designed/music_battle_roots.ogg"),
	&"battle_pursuit": preload("res://assets/runtime/audio/designed/music_battle_pursuit.ogg"),
	&"battle_resolve": preload("res://assets/runtime/audio/designed/music_battle_resolve.ogg"),
	&"boss": preload("res://assets/runtime/audio/designed/music_boss.ogg"),
}
const PLAYLISTS := {
	&"explore": [&"explore"],
	&"battle": [&"battle_roots", &"battle_pursuit", &"battle_resolve"],
	&"boss": [&"boss"],
}
const MUSIC_FADE_SECONDS: float = 1.2
const MUSIC_SILENCE_DB: float = -60.0
const MUSIC_QUIET_DB: float = -12.0
const REENTRY_GRACE_SECONDS: float = 3.0
const AMBIENCE := {
	&"room": preload("res://assets/runtime/audio/designed/amb_greenhouse.wav"),
	&"canopy": preload("res://assets/runtime/audio/designed/amb_canopy.wav"),
	&"machine": preload("res://assets/runtime/audio/designed/amb_machine.wav"),
	&"water": preload("res://assets/runtime/audio/designed/amb_water.wav"),
	&"toxin": preload("res://assets/runtime/audio/designed/amb_toxin.wav"),
	&"glide": preload("res://assets/runtime/audio/designed/glide_loop.wav"),
}
var mode: StringName = &""
var current_track: StringName = &""
var _bags: Dictionary = {}
var _last_tracks: Dictionary[StringName, StringName] = {}
var _loop_counts: Dictionary[StringName, int] = {}
var _battle_left_at_msec: int = -1
var level: GreenhouseLevel
var _music: Dictionary[StringName, AudioStreamPlayer] = {}
var _fades: Dictionary = {}
var _ambience: Dictionary[StringName, AudioStreamPlayer] = {}
var _points: Array[Node2D] = []
var _platforms: Dictionary = {}
var _tick_left: float = 0.0
var _quiet: bool = false
func setup(owner_level: GreenhouseLevel) -> void:
	level = owner_level
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: StringName in MUSIC:
		var player := AudioStreamPlayer.new()
		player.name = String(key).capitalize() + "Music"
		var stream := MUSIC[key].duplicate() as AudioStreamOggVorbis
		stream.loop = true
		player.stream = stream
		player.bus = &"Music"
		player.volume_db = -60.0
		add_child(player)
		_music[key] = player
	for key: StringName in AMBIENCE:
		var player := AudioStreamPlayer.new()
		player.name = String(key).capitalize() + "Ambience"
		player.stream = _loop_stream(AMBIENCE[key])
		player.bus = &"SFX" if key == &"glide" else &"Ambience"
		player.volume_db = -60.0
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_ambience[key] = player
	for node: Node in level.find_children("*", "Node", true, false):
		_connect_module(node)
	set_mode(&"explore")
func _loop_stream(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
func _connect_module(node: Node) -> void:
	if node is NutritionTank or node is ToxinResource or node is ToxinZone or node is WindZone:
		_points.append(node as Node2D)
	if node is NutritionTank or node is ToxinResource:
		node.connect(&"absorption_changed", func(active: bool) -> void: level.sounds.play_at(&"tank_start" if active else &"tank_stop", (node as Node2D).global_position))
	elif node is TriggerButton:
		(node as TriggerButton).pressed.connect(func(_button: TriggerButton, _actor: Node2D) -> void: level.sounds.play_at(&"button", (node as Node2D).global_position))
	elif node is AbilitySwitch:
		(node as AbilitySwitch).activated.connect(func() -> void: level.sounds.play_at(&"button", (node as Node2D).global_position))
	elif node is MovingPlatform or node is MoveableCube:
		var loop := AudioStreamPlayer2D.new()
		loop.stream = _loop_stream(preload("res://assets/runtime/audio/designed/mechanism_loop.wav"))
		loop.bus = &"SFX"
		loop.volume_db = -25.0
		loop.max_distance = 700.0
		loop.process_mode = Node.PROCESS_MODE_PAUSABLE
		(node as Node2D).add_child(loop)
		_platforms[node] = loop
		node.connect(&"motion_started", func(_module: Node2D) -> void:
			level.sounds.play_at(&"mechanism_start", (node as Node2D).global_position)
			if DisplayServer.get_name() != "headless": loop.play()
		)
		node.connect(&"motion_completed", func(_module: Node2D) -> void:
			loop.stop()
			level.sounds.play_at(&"mechanism_stop", loop.global_position)
		)
	elif node is ThornDamage:
		(node as ThornDamage).actor_hurt.connect(func(actor: Node2D, _damage: float) -> void: level.sounds.play_at(&"thorn", actor.global_position))
	elif node is ToxinZone:
		(node as ToxinZone).actor_entered.connect(func(actor: Node2D) -> void:
			if actor == level._player: level.sounds.play_at(&"toxin_enter", actor.global_position)
		)
	elif node is Button:
		var button := node as Button
		button.focus_entered.connect(func() -> void: level.sounds.play_cue(&"ui_focus"))
		button.mouse_entered.connect(func() -> void: level.sounds.play_cue(&"ui_focus"))
func set_mode(next: StringName) -> void:
	if mode == next or not PLAYLISTS.has(next):
		return
	if mode == &"battle":
		_battle_left_at_msec = Time.get_ticks_msec()
	mode = next
	# An interrupted transition should continue its phrase, not spend another variant.
	var quick_reentry := mode == &"battle" and _battle_left_at_msec >= 0 and Time.get_ticks_msec() - _battle_left_at_msec < int(REENTRY_GRACE_SECONDS * 1000.0)
	if quick_reentry and _last_tracks.has(mode):
		current_track = _last_tracks[mode]
	else:
		current_track = _next_track(mode)
	_refresh_music()
func _next_track(playlist: StringName) -> StringName:
	var tracks: Array = PLAYLISTS[playlist]
	if tracks.size() == 1:
		return tracks[0]
	var bag: Array = _bags.get(playlist, [])
	if bag.is_empty():
		bag = tracks.duplicate()
		bag.shuffle()
		# Avoid a repeated track across two shuffled bags as well.
		if bag.back() == _last_tracks.get(playlist, &""):
			var previous: StringName = bag.back()
			bag[bag.size() - 1] = bag[0]
			bag[0] = previous
	var selected: StringName = bag.pop_back()
	_bags[playlist] = bag
	_last_tracks[playlist] = selected
	return selected
func set_quiet(value: bool) -> void:
	if _quiet == value:
		return
	_quiet = value
	_refresh_music()
func _refresh_music() -> void:
	for key: StringName in _music:
		var player: AudioStreamPlayer = _music[key]
		if _fades.has(key) and (_fades[key] as Tween).is_valid():
			(_fades[key] as Tween).kill()
		var active := key == current_track
		if active and DisplayServer.get_name() != "headless":
			if player.stream_paused:
				# Retain the decoder cursor, including on exploration and boss retries.
				player.stream_paused = false
			elif not player.playing:
				player.play()
		var tween := create_tween().set_ignore_time_scale(true)
		_fades[key] = tween
		var target_db := (MUSIC_QUIET_DB if _quiet else 0.0) if active else MUSIC_SILENCE_DB
		# Interpolate amplitude so the middle of a crossfade does not dip to -30 dB.
		tween.tween_property(player, "volume_linear", db_to_linear(target_db), MUSIC_FADE_SECONDS)
		if not active:
			tween.tween_callback(_park_music.bind(key))
func _park_music(key: StringName) -> void:
	if key != current_track and _music[key].playing:
		_music[key].stream_paused = true
		if _music[key].has_stream_playback():
			_loop_counts[key] = _music[key].get_stream_playback().get_loop_count()
func _process(delta: float) -> void:
	if level == null:
		return
	# Let a complete musical loop finish before varying a prolonged encounter.
	if mode == &"battle" and not _quiet and not get_tree().paused and not level.dead and not level.finished:
		var player: AudioStreamPlayer = _music[current_track]
		if player.has_stream_playback():
			var loops := player.get_stream_playback().get_loop_count()
			if loops > _loop_counts.get(current_track, 0):
				_loop_counts[current_track] = loops
				current_track = _next_track(mode)
				_refresh_music()
	for node: Node2D in _platforms:
		if is_instance_valid(node) and node is MovingPlatform:
			var loop: AudioStreamPlayer2D = _platforms[node]
			loop.position = (node as MovingPlatform)._body.position
	set_quiet(level.dead or level.finished or get_tree().paused)
	if get_tree().paused:
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = 0.15
	var water: float = 0.0
	var toxin: float = 0.0
	var wind: float = 0.0
	for point: Node2D in _points:
		var distance := point.global_position.distance_to(level._player.global_position)
		var proximity := clampf(1.0 - distance / 360.0, 0.0, 1.0)
		if point is NutritionTank: water = maxf(water, proximity)
		elif point is ToxinResource or point is ToxinZone: toxin = maxf(toxin, proximity)
		elif point is WindZone: wind = maxf(wind, proximity)
	var section := level._section
	_set_ambience(&"room", -33.0)
	_set_ambience(&"canopy", -31.0 if section == 4 else (-35.0 if wind > 0.1 else -60.0))
	_set_ambience(&"machine", -34.0 if section in [3, 6] else -60.0)
	_set_ambience(&"water", -29.0 + linear_to_db(water) if water > 0.02 else -60.0)
	_set_ambience(&"toxin", -30.0 + linear_to_db(toxin) if toxin > 0.02 else -60.0)
	_set_ambience(&"glide", -27.0 if level._player.state_machine.current_state == &"glide" else -60.0)
func _set_ambience(key: StringName, target: float) -> void:
	var player: AudioStreamPlayer = _ambience[key]
	if level.dead or level.finished: target = -60.0
	player.volume_db = move_toward(player.volume_db, target, 4.0)
	if target > -59.0 and not player.playing and DisplayServer.get_name() != "headless": player.play()
	elif player.volume_db <= -59.0: player.stop()
func stop_transients() -> void:
	for loop: AudioStreamPlayer2D in _platforms.values(): loop.stop()
	for player: AudioStreamPlayer in _ambience.values(): player.stop()
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _music.values():
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in _ambience.values():
		player.stop()
		player.stream = null
