class_name PlayerAudio
extends Node
## Presentation-only listener for real player actions; never drives movement or resources.
@export_range(0.15, 0.7, 0.01) var footstep_interval: float = 0.32
@export_range(0.3, 2.0, 0.05) var absorption_interval: float = 0.75
@onready var sounds: SoundEmitter = %PlayerSounds
var _player: Player
var _last_form: StringName
var _last_ability: StringName = &"none"
var _step_timer: float = 0.0
var _absorption_timer: float = 0.0
func setup(player: Player) -> void:
	_player = player
	_last_form = player.current_form_id()
	player.movement.jumped.connect(func() -> void: sounds.play_cue(&"jump"))
	player.movement.landed.connect(func(speed: float) -> void: sounds.play_cue(&"land_heavy" if speed > 600.0 else &"land", clampf(speed / 160.0 - 3.0, -3.0, 2.0)))
	player.form_controller.form_changed.connect(_on_form_changed)
	player.abilities.ability_state_changed.connect(_on_ability_changed)
	player.state_machine.state_changed.connect(_on_state_changed)
	player.resource_absorbed.connect(_on_resource_absorbed)
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_absorption_timer = maxf(0.0, _absorption_timer - delta)
	var walking := _player.is_on_floor() and absf(_player.velocity.x) > 35.0 and not _player.abilities.is_rooted() and not _player.abilities.is_vine_attached()
	if not walking:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = footstep_interval * clampf(190.0 / maxf(absf(_player.velocity.x), 1.0), 0.65, 1.4)
		sounds.play_cue(_footstep_cue())
func _on_form_changed(form_id: StringName) -> void:
	if form_id == _last_form:
		return
	var stages := [&"sprout", &"humanoid", &"mature"]
	sounds.play_cue(&"grow" if stages.find(form_id) > stages.find(_last_form) else &"wither")
	_last_form = form_id
	_absorption_timer = absorption_interval
func _on_ability_changed(label: StringName) -> void:
	if label == &"none":
		match _last_ability:
			&"rooted": sounds.play_cue(&"unroot")
			&"legs": sounds.play_cue(&"retract")
			&"vine": sounds.play_cue(&"vine_release")
	_last_ability = label
	match label:
		&"rooted": sounds.play_cue(&"root")
		&"legs": sounds.play_cue(&"extend")
		&"vine": sounds.play_cue(&"vine")
func _on_state_changed(previous: StringName, current: StringName) -> void:
	if previous == &"glide" and current != &"glide":
		sounds.play_cue(&"glide_end")
	if current == &"glide":
		sounds.play_cue(&"glide")
func _on_resource_absorbed(kind: StringName, _amount: float) -> void:
	if _absorption_timer <= 0.0:
		_absorption_timer = absorption_interval
		sounds.play_cue(&"absorb_toxin" if kind == &"toxin" else &"absorb")

func _footstep_cue() -> StringName:
	for index: int in range(_player.get_slide_collision_count()):
		var collision := _player.get_slide_collision(index)
		if collision.get_normal().y > -0.5:
			continue
		var body := collision.get_collider() as Node
		if body == null:
			continue
		for child: Node in body.get_children():
			if child is TerrainSkin and (child as TerrainSkin).profile != null:
				match (child as TerrainSkin).profile.material_id:
					&"workshop", &"core": return &"step_metal"
					&"canopy", &"root_passage": return &"step_wood"
					&"courtyard": return &"step_hard"
					_: return &"step_grass"
	return &"step_grass" if _player.can_root_here() else &"step_hard"
