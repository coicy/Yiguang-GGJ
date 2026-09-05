class_name VineWhipProfile
extends Resource
## Shared visual data only. Reach changes the rig segment spacing, never leaf scale.
@export var form_id: StringName = &"humanoid"
@export var animation_library: AnimationLibrary
@export_group("Plant textures")
@export var texture_material: Material
@export var stem_texture: Texture2D
@export var leaf_a_texture: Texture2D
@export var leaf_b_texture: Texture2D
@export var node_texture: Texture2D
@export var sheath_texture: Texture2D
@export var tip_texture: Texture2D
@export_group("World sizes")
@export_range(1.0, 15.0, 0.1) var root_width: float = 6.4
@export_range(0.2, 5.0, 0.1) var tip_width: float = 1.3
@export var leaf_a_size := Vector2(13.0, 9.0)
@export var leaf_b_size := Vector2(11.0, 8.0)
@export var sheath_size := Vector2(13.0, 11.0)
@export var tip_size := Vector2(11.0, 9.0)
@export var node_size := Vector2(5.5, 6.5)
@export_range(2, 4) var leaf_count: int = 3
@export_group("Normalized attachment pivots")
@export var leaf_a_pivot := Vector2(0.04, 0.5)
@export var leaf_b_pivot := Vector2(0.04, 0.5)
@export var sheath_pivot := Vector2(0.12, 0.5)
@export var tip_pivot := Vector2(0.04, 0.5)
@export_group("Presentation")
@export var stem_tint := Color.WHITE
@export var trail_color := Color(0.53, 0.69, 0.28, 0.13)
@export_range(0.0, 1.0, 0.01) var hand_rotation_follow: float = 0.34

@export_group("Hand and elastic follow")
@export var root_spring: float = 2600.0
@export var tip_spring: float = 1500.0
@export var motion_damping: float = 24.0
@export var motion_gravity: float = 65.0
@export var max_motion_lag: float = 12.0
@export_range(0.4, 1.8, 0.05) var max_joint_bend: float = 0.95

@export_group("Deflection Sweep")
@export var parry_reach: float = 58.0
@export var parry_lift: float = 66.0
