extends SceneTree

const WhiteboxSwitch = preload("res://features/level/whitebox_switch.gd")
const ExitDevice = preload("res://features/level/exit_device.gd")

var _opened_count: int = 0

func _init() -> void:
	var switch_node := WhiteboxSwitch.new()
	var exit_device := ExitDevice.new()
	exit_device.opened.connect(_on_exit_opened)
	exit_device.set_required_switches(1)
	exit_device.register_switch(switch_node)
	assert(not exit_device.is_open())
	switch_node.activate()
	assert(exit_device.is_open())
	assert(_opened_count == 1)
	exit_device.register_switch(switch_node)
	assert(_opened_count == 1)
	switch_node.deactivate()
	assert(not exit_device.is_open())
	switch_node.activate()
	assert(exit_device.is_open())
	assert(_opened_count == 2)
	exit_device.free()
	switch_node.free()
	quit()

func _on_exit_opened() -> void:
	_opened_count += 1
