extends HandbuiltLevel
## Keeps the LDtk spawn-room frame visible while reusing hand-built lifecycle rules.

@export var frame_padding := Vector2(24.0, 8.0)


func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_fit_room_camera)
	_fit_room_camera()


func _fit_room_camera() -> void:
	var room := _camera_bounds.get_world_rect()
	# The source Start sits on the left edge; leave room for the player's artwork.
	var padded_size := room.size + frame_padding.max(Vector2.ZERO) * 2.0
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var magnification := minf(viewport_size.x / padded_size.x, viewport_size.y / padded_size.y)
	var visible_size := viewport_size / magnification
	var visible_rect := Rect2(room.get_center() - visible_size * 0.5, visible_size)
	_phantom_camera.position = room.get_center()
	_phantom_camera.zoom = Vector2.ONE * magnification
	# Expand only the camera limits for letterboxing; the source room stays unchanged.
	_camera.limit_left = floori(visible_rect.position.x)
	_camera.limit_top = floori(visible_rect.position.y)
	_camera.limit_right = ceili(visible_rect.end.x)
	_camera.limit_bottom = ceili(visible_rect.end.y)
	_phantom_camera.limit_left = _camera.limit_left
	_phantom_camera.limit_top = _camera.limit_top
	_phantom_camera.limit_right = _camera.limit_right
	_phantom_camera.limit_bottom = _camera.limit_bottom
	_camera.reset_smoothing()
