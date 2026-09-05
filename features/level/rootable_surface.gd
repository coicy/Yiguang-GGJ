class_name RootableSurface
extends StaticBody2D
## A solid whitebox surface that explicitly describes whether humanoid rooting is allowed.

@export var allows_rooting: bool = true


func can_root() -> bool:
	return allows_rooting
