@tool
extends Node2D
## Sparse ambient movement remains behind every gameplay silhouette.
var _time: float = 0.0
var _background: Sprite2D
var _base_position: Vector2
func _ready() -> void:
 _background = get_node_or_null("../BackgroundClip/DistantInterior") as Sprite2D
 if _background != null:
  _base_position = _background.position
func _process(delta: float) -> void:
 if Engine.is_editor_hint(): return
 _time += delta
 if _background != null:
  var camera := get_viewport().get_camera_2d()
  if camera != null:
   var drift := (camera.get_screen_center_position() - Vector2(448,413)) * 0.018
   _background.position = _base_position + drift.clamp(Vector2(-7,-4),Vector2(7,4))
 queue_redraw()
func _draw() -> void:
 for i: int in range(18):
  var x := 327.0 + fposmod(i * 67.37 + _time * (1.8 + i % 3),365.0)
  var y := 320.0 + fposmod(i * 29.9 - _time * 3.0,150.0)
  var alpha := 0.10 + 0.09 * sin(_time * 0.7 + i)
  draw_circle(Vector2(x,y),0.45 if i % 3 else 0.7,Color(0.79,0.91,0.68,alpha))
