class_name FormController
extends Node
## Owns the current form and switches between FormDefinition resources.
## Runtime data is deep-duplicated; the shared .tres assets are never mutated.

signal form_changed(form_id: StringName)

@export var forms: Array = []
@export var default_form_id: StringName = &"humanoid"

var current_form: FormDefinition


func _ready() -> void:
	if forms.is_empty():
		push_warning("FormController: no forms assigned, using a default FormDefinition.")
		forms.append(FormDefinition.new())
	_switch_to_internal(default_form_id, true)


func get_current() -> FormDefinition:
	return current_form


func switch_to(form_id: StringName) -> bool:
	return _switch_to_internal(form_id, false)


func cycle_next() -> void:
	if forms.is_empty():
		return
	var current_id: StringName = current_form.id if current_form != null else default_form_id
	var index := _find_index(current_id)
	var next_index := (index + 1) % forms.size()
	_switch_to_internal(_form_at(next_index).id, false)


func _switch_to_internal(form_id: StringName, silent: bool) -> bool:
	for definition in forms:
		if (definition as FormDefinition).id == form_id:
			current_form = (definition as FormDefinition).duplicate(true) as FormDefinition
			if not silent:
				form_changed.emit(form_id)
			return true
	push_error("FormController: unknown form id '%s'" % form_id)
	return false


func _find_index(form_id: StringName) -> int:
	for i in forms.size():
		if _form_at(i).id == form_id:
			return i
	return 0


func _form_at(index: int) -> FormDefinition:
	return forms[index] as FormDefinition
