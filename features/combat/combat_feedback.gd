class_name CombatFeedback
extends Node2D
@export var light_stop: float = 0.035
@export var heavy_stop: float = 0.06
var camera: Camera2D
var sounds: SoundEmitter
var _sparks: Array[Dictionary] = []
var _shake: float = 0.0
var _stop_until_ms: int = 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func cue(kind: StringName, point: Vector2, strength: float = 1.0, play_sound: bool = true) -> void:
	if sounds != null and play_sound:
		sounds.play_at(kind, point)
	if kind in [&"swing", &"warning", &"danger", &"dash"]:
		return
	var color := Color("#eff2ad")
	if kind == &"hurt":
		color = Color("#f39080")
	elif kind == &"guard":
		color = Color("#86b1bc")
	# Parry impact is carried by the vine sweep, recoil, sound and hit-stop.
	if kind != &"parry":
		for i in range(7):
			var angle := TAU * float(i) / 7.0 + 0.3
			_sparks.append({"p": point, "v": Vector2.from_angle(angle) * (50.0 + i * 11.0), "life": 0.26, "color": color})
	_shake = maxf(_shake, 2.0 * strength if kind != &"parry" else 3.5)
	var duration := heavy_stop if kind in [&"parry", &"heavy_hit"] else light_stop
	_stop_until_ms = maxi(_stop_until_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = 0.0
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _stop_until_ms > 0 and now >= _stop_until_ms:
		Engine.time_scale = 1.0
		_stop_until_ms = 0
	if get_tree().paused:
		return
	var step := delta if Engine.time_scale > 0.0 else 0.0
	for i in range(_sparks.size() - 1, -1, -1):
		var spark: Dictionary = _sparks[i]
		spark["life"] = float(spark["life"]) - step
		spark["p"] = Vector2(spark["p"]) + Vector2(spark["v"]) * step
		spark["v"] = Vector2(spark["v"]) + Vector2(0.0, 140.0) * step
		if float(spark["life"]) <= 0.0:
			_sparks.remove_at(i)
	_shake = move_toward(_shake, 0.0, step * 22.0)
	if is_instance_valid(camera):
		camera.offset = Vector2(sin(now * 0.071), cos(now * 0.097)) * _shake
	queue_redraw()
func _draw() -> void:
	for spark: Dictionary in _sparks:
		var tint: Color = spark["color"]
		tint.a *= clampf(float(spark["life"]) / float(spark.get("duration", 0.26)), 0.0, 1.0)
		var point := to_local(Vector2(spark["p"]))
		draw_line(point, point - Vector2(spark["v"]).normalized() * float(spark.get("length", 5.0)), tint, float(spark.get("width", 1.7)), true)
func clear() -> void:
	_sparks.clear()
	_stop_until_ms = 0
	Engine.time_scale = 1.0
	_shake = 0.0
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
func _exit_tree() -> void:
	clear()
