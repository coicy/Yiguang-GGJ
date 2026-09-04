class_name FormController
extends Node
## Owns the current form and switches between FormDefinition resources.
## Runtime data is deep-duplicated; the shared .tres assets are never mutated.

signal form_changed(form_id: StringName)

@export var forms: Array[FormDefinition] = []
@export var default_form_id: StringName = &"humanoid"

var current_form: FormDefinition


func _ready() -> void:
	if forms.is_empty():
		push_warning("FormController: no forms assigned, using a default FormDefinition.")
		forms.append(FormDefinition.new())
	if not _switch_to_internal(default_form_id, true):
		var fallback := _first_valid_form()
		if fallback == null:
			current_form = FormDefinition.new()
			forms.append(current_form)
		else:
			current_form = fallback.duplicate(true) as FormDefinition
		push_warning("FormController: default form '%s' is not configured, using '%s'." % [default_form_id, current_form.id])


func get_current() -> FormDefinition:
	return current_form


func switch_to(form_id: StringName) -> bool:
	return _switch_to_internal(form_id, false)


func cycle_next() -> void:
	if forms.is_empty():
		return
	var current_id: StringName = current_form.id if current_form != null else default_form_id
	var index := _find_index(current_id)
	var first_index := 0 if index < 0 else (index + 1) % forms.size()
	for offset in forms.size():
		var next_index := (first_index + offset) % forms.size()
		var next_form := _form_at(next_index)
		if next_form != null:
			_switch_to_internal(next_form.id, false)
			return


func _switch_to_internal(form_id: StringName, silent: bool) -> bool:
	for definition in forms:
		if definition == null:
			continue
		if definition.id == form_id:
			current_form = definition.duplicate(true) as FormDefinition
			if not silent:
				form_changed.emit(form_id)
			return true
	if silent:
		push_warning("FormController: unknown default form id '%s'." % form_id)
	else:
		push_error("FormController: unknown form id '%s'" % form_id)
	return false


func _find_index(form_id: StringName) -> int:
	for i in forms.size():
		var definition := _form_at(i)
		if definition != null and definition.id == form_id:
			return i
	return -1


func _form_at(index: int) -> FormDefinition:
	return forms[index]


func _first_valid_form() -> FormDefinition:
	for definition in forms:
		if definition != null:
			return definition
	return null
