class_name EnemyAudio
extends Node
## A creature's audio identity listens to real transitions; it never advances combat.
var actor: CombatEnemy
var sounds: SoundEmitter
var family: StringName
var _step_left: float = 0.0
var _local_sounds: SoundEmitter
func setup(enemy: CombatEnemy) -> void:
	actor = enemy
	family = [&"beetle", &"spore", &"pruner", &"warden"][actor.definition.kind]
	_local_sounds = SoundEmitter.new()
	_local_sounds.voice_count = 1
	_local_sounds.spatial_voice_count = 4
	add_child(_local_sounds)
	sounds = _local_sounds
	actor.audio_state_changed.connect(_on_state)
	actor.feedback_requested.connect(_on_feedback)
	actor.health.damaged.connect(_on_hurt)
	actor.projectile_requested.connect(_on_projectile)
func use_pool(pool: SoundEmitter) -> void:
	sounds = pool
	_local_sounds.queue_free()
func _play(suffix: StringName, gain: float = 0.0) -> void:
	sounds.play_at(StringName(String(family) + "_" + String(suffix)), actor.global_position + Vector2(0, -24), gain)
func _on_state(value: StringName) -> void:
	match value:
		&"notice": _play(&"notice")
		&"overload": _play(&"phase")
		&"dead": _play(&"death")
		&"strike":
			if family == &"spore" and actor.attack_kind == &"spit":
				return # Fire at the visible muzzle release, not at preparation end.
			var key := StringName(String(family) + "_" + String(actor.attack_kind))
			# Slams make a movement sound here; contact comes from the impact callback.
			_play(actor.attack_kind if AudioPalette.CUES.has(key) and actor.attack_kind != &"slam" else &"attack")
func _on_feedback(kind: StringName, point: Vector2, _strength: float) -> void:
	if kind in [&"warning", &"danger"]:
		if actor.state != &"overload":
			_play(kind)
	elif kind == &"heavy_hit":
		if family in [&"pruner", &"warden"]:
			_play(&"slam")
		else:
			sounds.play_at(&"heavy_hit", point, -3.0)
	elif kind == &"block":
		sounds.play_at(&"block", point)
func _on_hurt(_request: DamageRequest) -> void:
	if actor.health.current > 0:
		_play(&"hurt")
func _on_projectile(_enemy: CombatEnemy, point: Vector2, _direction: Vector2, wave: bool) -> void:
	if not wave:
		sounds.play_at(&"spore_shot", point)
func _physics_process(delta: float) -> void:
	if actor == null or actor.state == &"dead":
		return
	_step_left -= delta
	if actor.is_on_floor() and absf(actor.velocity.x) > 22.0 and _step_left <= 0.0:
		_step_left = 0.48 if family == &"warden" else 0.30
		_play(&"step")
