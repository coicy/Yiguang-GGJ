class_name WhiteboxSwitch
extends Node

signal activated
signal deactivated

var _active: bool = false

func activate() -> void:
	if _active:
		return
	_active = true
	activated.emit()

func deactivate() -> void:
	if not _active:
		return
	_active = false
	deactivated.emit()

func is_active() -> bool:
	return _active
