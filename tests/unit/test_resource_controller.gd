extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var forms := FormController.new()
	forms.forms = [
		load("res://features/forms/sprout.tres"),
		load("res://features/forms/humanoid.tres"),
		load("res://features/forms/mature.tres"),
	]
	forms.default_form_id = &"sprout"
	root.add_child(forms)

	var resources := ResourceController.new()
	root.add_child(resources)
	resources.setup(forms)
	resources.stability = 75.0
	assert(resources.absorb_nutrition(20.0))
	assert(is_equal_approx(resources.stability, 100.0))
	assert(is_zero_approx(resources.growth_progress))
	resources.absorb_nutrition(100.0)
	assert(forms.get_current().id == &"humanoid")
	assert(resources.absorb_toxin(120.0))
	assert(forms.get_current().id == &"sprout")
	resources.absorb_nutrition(100.0)
	assert(forms.get_current().id == &"humanoid")
	resources.absorb_nutrition(120.0)
	assert(forms.get_current().id == &"mature")
	assert(resources.absorb_toxin(119.0))
	assert(forms.get_current().id == &"mature")
	assert(resources.absorb_toxin(1.0))
	assert(forms.get_current().id == &"humanoid")

	var toxin := Node.new()
	resources.enter_toxin(toxin)
	resources.enter_toxin(toxin)
	assert(is_equal_approx(resources.speed_multiplier(), 1.0))
	resources.tick(0.25)
	assert(resources.speed_multiplier() < 1.0 and resources.speed_multiplier() > 0.55)
	resources.tick(0.75)
	assert(is_equal_approx(resources.speed_multiplier(), 0.55))
	assert(is_equal_approx(resources.stability, 65.0))
	resources.tick(2.0)
	assert(forms.get_current().id == &"sprout")
	assert(is_equal_approx(resources.stability, 100.0))
	resources.exit_toxin(toxin)
	assert(is_equal_approx(resources.speed_multiplier(), 0.55))
	resources.tick(0.25)
	assert(resources.speed_multiplier() > 0.55 and resources.speed_multiplier() < 1.0)
	resources.tick(0.75)
	assert(is_equal_approx(resources.speed_multiplier(), 1.0))

	var saved := resources.snapshot()
	resources.reset()
	resources.restore(saved)
	assert(resources.snapshot() == saved)

	toxin.free()
	resources.free()
	forms.free()
	quit()
