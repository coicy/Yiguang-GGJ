extends Node
## Mutable run data that must survive level scene changes.

var current_level_id: StringName = &""
var selected_form_id: StringName = &"base"
var death_count: int = 0

func reset() -> void:
	current_level_id = &""
	selected_form_id = &"base"
	death_count = 0
