class_name ExitDevice
extends Node

const WhiteboxSwitch = preload("res://features/level/whitebox_switch.gd")

signal opened

var _required_switches: int = 0
var _registered_switches: Array[WhiteboxSwitch] = []
var _open: bool = false

func set_required_switches(count: int) -> void:
	_required_switches = maxi(count, 0)
	_update_open_state()

func register_switch(switch: WhiteboxSwitch) -> void:
	if _registered_switches.has(switch):
		return
	_registered_switches.append(switch)
	switch.activated.connect(_update_open_state)
	switch.deactivated.connect(_update_open_state)
	_update_open_state()

func is_open() -> bool:
	return _open

func _update_open_state() -> void:
	var active_switch_count: int = 0
	for switch in _registered_switches:
		if is_instance_valid(switch) and switch.is_active():
			active_switch_count += 1

	var should_be_open: bool = active_switch_count >= _required_switches
	if should_be_open and not _open:
		_open = true
		opened.emit()
	elif not should_be_open:
		_open = false
