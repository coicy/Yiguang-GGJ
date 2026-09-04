extends Node
## Cross-scene lifecycle events only. Keep feature-local events on feature nodes.

signal run_started
signal run_reset
signal level_started(level_id: StringName)
signal level_completed(level_id: StringName)
signal player_died
signal player_form_changed(form_id: StringName)
signal player_health_changed(current: int, maximum: int)
