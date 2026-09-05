class_name ResourceController
extends Node
## Owns the player's nutrition growth progress, stability, and toxin exposure.

signal values_changed(growth: float, threshold: float, stability: float)
signal toxin_changed(active: bool)
signal form_transitioned(form_id: StringName)

const MAX_STABILITY := 100.0
const TOXIN_DRAIN_PER_SECOND := 35.0
const STABILITY_RECOVERY_PER_SECOND := 20.0
const NUTRITION_STABILITY_MULTIPLIER := 1.25
const TOXIN_SPEED_MULTIPLIER := 0.55

var growth_progress: float = 0.0
var toxin_progress: float = 0.0
var stability: float = MAX_STABILITY

var _forms: FormController
var _toxin_sources: Dictionary = {}


func setup(form_controller: FormController) -> void:
	_forms = form_controller
	_emit_values()


func tick(delta: float) -> void:
	_prune_invalid_toxin_sources()
	if not _toxin_sources.is_empty():
		stability = maxf(0.0, stability - TOXIN_DRAIN_PER_SECOND * delta)
		if stability <= 0.0:
			if _forms != null and _forms.wither():
				growth_progress = 0.0
				form_transitioned.emit(_forms.get_current().id)
			stability = MAX_STABILITY
	else:
		stability = minf(MAX_STABILITY, stability + STABILITY_RECOVERY_PER_SECOND * delta)
	_emit_values()


func absorb_nutrition(amount: float) -> bool:
	if amount <= 0.0 or _forms == null:
		return false
	var nutrition_left := amount
	if stability < MAX_STABILITY:
		var needed := (MAX_STABILITY - stability) / NUTRITION_STABILITY_MULTIPLIER
		var used := minf(needed, nutrition_left)
		stability += used * NUTRITION_STABILITY_MULTIPLIER
		nutrition_left -= used

	var form := _forms.get_current()
	if form != null and form.growth_threshold > 0.0:
		growth_progress = minf(growth_progress + nutrition_left, form.growth_threshold)
		if growth_progress >= form.growth_threshold and _forms.grow():
			growth_progress = 0.0
			form_transitioned.emit(_forms.get_current().id)
	_emit_values()
	return true


func absorb_toxin(amount: float) -> bool:
	if amount <= 0.0 or _forms == null:
		return false
	var form := _forms.get_current()
	if form == null or form.id == &"sprout" or form.growth_threshold <= 0.0:
		return false
	toxin_progress = minf(toxin_progress + amount, form.growth_threshold)
	if toxin_progress >= form.growth_threshold and _forms.wither():
		toxin_progress = 0.0
		growth_progress = 0.0
		form_transitioned.emit(_forms.get_current().id)
	_emit_values()
	return true


func enter_toxin(source: Object) -> void:
	if source == null:
		return
	var was_active := not _toxin_sources.is_empty()
	_toxin_sources[source.get_instance_id()] = weakref(source)
	if not was_active:
		toxin_changed.emit(true)


func exit_toxin(source: Object) -> void:
	if source == null:
		return
	_toxin_sources.erase(source.get_instance_id())
	if _toxin_sources.is_empty():
		toxin_changed.emit(false)


func speed_multiplier() -> float:
	return TOXIN_SPEED_MULTIPLIER if not _toxin_sources.is_empty() else 1.0


func snapshot() -> Dictionary:
	return {
		"growth": growth_progress,
		"toxin": toxin_progress,
		"stability": stability,
	}


func restore(saved: Dictionary) -> void:
	growth_progress = maxf(0.0, float(saved.get("growth", 0.0)))
	toxin_progress = maxf(0.0, float(saved.get("toxin", 0.0)))
	stability = clampf(float(saved.get("stability", MAX_STABILITY)), 0.0, MAX_STABILITY)
	_toxin_sources.clear()
	toxin_changed.emit(false)
	_emit_values()


func reset() -> void:
	growth_progress = 0.0
	toxin_progress = 0.0
	stability = MAX_STABILITY
	_toxin_sources.clear()
	toxin_changed.emit(false)
	_emit_values()


func _emit_values() -> void:
	var threshold := 0.0
	if _forms != null and _forms.get_current() != null:
		threshold = _forms.get_current().growth_threshold
	values_changed.emit(growth_progress, threshold, stability)


func _prune_invalid_toxin_sources() -> void:
	var invalid_ids: Array = []
	for source_id: Variant in _toxin_sources:
		var source_ref: WeakRef = _toxin_sources[source_id]
		if source_ref.get_ref() == null:
			invalid_ids.append(source_id)
	for source_id: Variant in invalid_ids:
		_toxin_sources.erase(source_id)
