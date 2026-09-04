# Whitebox Playable Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete Godot 4.7.2 whitebox level that the player can finish using all three forms, resource-driven transitions, root, leg extension, vine swinging, glide, checkpoints, hazards, switches, and an exit.

**Architecture:** Keep one reusable `Player` scene and extend it with focused form, resource, movement, and ability components. The level owns world interactions, checkpoint snapshots, reset, and completion; HUD nodes observe typed signals and never mutate gameplay state.

**Tech Stack:** Godot 4.7.2 Stable, typed GDScript, `.tscn` scenes, `.tres` resources, built-in `SceneTree` tests, GL Compatibility renderer.

**Spec:** `docs/superpowers/specs/2026-09-05-whitebox-playable-vertical-slice-design.md`

## Global Constraints

- Use Godot 4.7.2 and typed GDScript; keep file/method names `snake_case` and node/class names `PascalCase`.
- Keep one `CharacterBody2D` player; do not create one player scene per form.
- Do not add formal art, audio, enemies, combat, persistence, networking, or third-party addons.
- Use left mouse, `W/A/S/D`, `Space`, `R`, and `F3` as specified; normal gameplay must not use manual form cycling.
- Keep form tuning in `FormDefinition` resources and deep-duplicate mutable runtime resources.
- Run movement in `_physics_process()` with `velocity` and `move_and_slide()`.
- Every task follows red-green TDD and ends with a focused commit.
- Do not commit `.godot/`, local engine binaries, exports, generated build output, `.agents/`, or `skills-lock.json`.

## File Structure

### New files

- `features/resources/resource_controller.gd`: nutrition, growth, stability, toxin exposure, snapshots.
- `features/abilities/ability_controller.gd`: form-gated root, leg extension, vine, cancellation.
- `features/abilities/vine_anchor.gd` and `.tscn`: visible grapple target.
- `features/level/wind_zone.gd` and `.tscn`: warning/blowing cycle and wind commands.
- `features/level/ability_switch.gd` and `.tscn`: high-leg and low-sprout triggers.
- `features/level/whitebox_gate.gd` and `.tscn`: switch-driven visible collision gate.
- `features/level/exit_goal.gd` and `.tscn`: player overlap and locked feedback.
- `features/ui/game_hud.gd` and `.tscn`: read-only form/resource/ability/prompt display.
- `features/ui/completion_overlay.gd` and `.tscn`: completion state and elapsed time.
- `tests/unit/test_form_progression.gd`: form data and ordered transitions.
- `tests/unit/test_resource_controller.gd`: nutrition/toxin state machine.
- `tests/scene/test_player_abilities.gd`: root, leg, glide, vine, cancel behavior.
- `tests/scene/test_whitebox_interactions.gd`: wind, switches, gates, exit.
- `tests/scene/test_playable_whitebox.gd`: full level contracts, respawn, reset, completion.

### Modified files

- `features/forms/form_definition.gd` and the three form `.tres` files: collision, color, threshold, capability data.
- `features/forms/form_controller.gd`: non-wrapping grow/wither and guarded transitions.
- `features/player/player.gd`, `movement_controller.gd`, `state_machine.gd`, `player_visuals.gd`, `player.tscn`: component integration and whitebox presentation.
- `features/level/nutrition_tank.gd` and `.tscn`: continuous absorption while overlapping.
- `features/level/toxin_zone.gd`: expose typed enter/exit signals to the player.
- `features/level/checkpoint.gd`: add actor-aware checkpoint signal without breaking the existing API.
- `scenes/levels/whitebox_sandbox.gd` and `.tscn`: playable course, snapshots, reset, completion.
- `scenes/app/main.tscn`: attach HUD and completion overlay.
- `project.godot`: map `ability_primary` to left mouse and add `move_up`/`move_down`; preserve existing actions.
- `README.md`, `docs/api/level.md`, `docs/api/interactions.md`, `WIP.md`: describe the playable whitebox and implemented contracts.

---

### Task 1: Form Data and Ordered Progression

**Files:**
- Create: `tests/unit/test_form_progression.gd`
- Modify: `features/forms/form_definition.gd`
- Modify: `features/forms/form_controller.gd`
- Modify: `features/forms/sprout.tres`
- Modify: `features/forms/humanoid.tres`
- Modify: `features/forms/mature.tres`

**Interfaces:**
- Produces: `FormDefinition.collision_size`, `body_color`, `growth_threshold`, `can_root`, `can_extend_legs`, `can_use_vine`, `can_glide`.
- Produces: `FormController.set_switch_validator(validator: Callable)`, `peek_grown_form()`, `peek_withered_form()`, `grow()`, `wither()`, `restore_form(form_id)`.
- Consumes: existing `FormController.forms`, `default_form_id`, `form_changed`.

- [ ] **Step 1: Write the failing progression test**

```gdscript
extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller := FormController.new()
    controller.forms = [
        load("res://features/forms/sprout.tres"),
        load("res://features/forms/humanoid.tres"),
        load("res://features/forms/mature.tres"),
    ]
    controller.default_form_id = &"sprout"
    root.add_child(controller)
    await process_frame
    assert(controller.get_current().collision_size == Vector2(20.0, 24.0))
    assert(controller.peek_grown_form().id == &"humanoid")
    assert(controller.grow())
    assert(controller.get_current().id == &"humanoid")
    assert(controller.grow())
    assert(controller.get_current().id == &"mature")
    assert(not controller.grow())
    assert(controller.wither())
    assert(controller.get_current().id == &"humanoid")
    assert(controller.restore_form(&"sprout"))
    assert(controller.get_current().id == &"sprout")
    controller.free()
    quit()
```

- [ ] **Step 2: Run the test and verify the missing API fails**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_form_progression.gd
```

Expected: non-zero exit or parser error for `collision_size` / `peek_grown_form`.

- [ ] **Step 3: Add form fields and ordered non-wrapping transitions**

```gdscript
# form_definition.gd
@export var collision_size: Vector2 = Vector2(28.0, 40.0)
@export var body_color: Color = Color("80b1d3")
@export var growth_threshold: float = 0.0
@export var can_root: bool = false
@export var can_extend_legs: bool = false
@export var can_use_vine: bool = false
@export var can_glide: bool = false
```

```gdscript
# form_controller.gd
var _switch_validator: Callable

func set_switch_validator(validator: Callable) -> void:
    _switch_validator = validator

func grow() -> bool:
    return _switch_by_offset(1)

func wither() -> bool:
    return _switch_by_offset(-1)

func restore_form(form_id: StringName) -> bool:
    return _switch_to_internal(form_id, false)

func _switch_by_offset(offset: int) -> bool:
    var index := _find_index(current_form.id)
    var target_index := index + offset
    if target_index < 0 or target_index >= forms.size():
        return false
    var target := _form_at(target_index)
    if target == null:
        return false
    if _switch_validator.is_valid() and not _switch_validator.call(target):
        return false
    return _switch_to_internal(target.id, false)
```

Set resource values exactly as the spec table: sprout `20x24`, humanoid `28x40`, mature `38x54`; thresholds `100`, `120`, `0`; capability flags only on their owning form.

- [ ] **Step 4: Run the progression test and existing form-independent tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_form_progression.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_whitebox_switch.gd
```

Expected: both exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add tests/unit/test_form_progression.gd features/forms/form_definition.gd features/forms/form_controller.gd features/forms/sprout.tres features/forms/humanoid.tres features/forms/mature.tres
git commit -m "feat: add ordered form progression data"
```

---

### Task 2: Nutrition, Stability, and Toxin State

**Files:**
- Create: `features/resources/resource_controller.gd`
- Create: `tests/unit/test_resource_controller.gd`

**Interfaces:**
- Consumes: `FormController.grow()`, `wither()`, `get_current()`.
- Produces: signals `values_changed(growth, threshold, stability)`, `toxin_changed(active)`, `form_transitioned(form_id)`.
- Produces: `setup(form_controller)`, `tick(delta)`, `absorb_nutrition(amount)`, `enter_toxin(source)`, `exit_toxin(source)`, `speed_multiplier()`, `snapshot()`, `restore(snapshot)`, `reset()`.

- [ ] **Step 1: Write failing resource-state tests**

```gdscript
extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var forms := FormController.new()
    forms.forms = [load("res://features/forms/sprout.tres"), load("res://features/forms/humanoid.tres"), load("res://features/forms/mature.tres")]
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
    var toxin := Node.new()
    resources.enter_toxin(toxin)
    resources.tick(1.0)
    assert(resources.speed_multiplier() == 0.55)
    resources.tick(2.0)
    assert(forms.get_current().id == &"sprout")
    resources.exit_toxin(toxin)
    var saved := resources.snapshot()
    resources.reset()
    resources.restore(saved)
    assert(resources.snapshot() == saved)
    toxin.free()
    resources.free()
    forms.free()
    quit()
```

- [ ] **Step 2: Run and verify failure**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_resource_controller.gd
```

Expected: parser error because `ResourceController` does not exist.

- [ ] **Step 3: Implement the resource controller**

```gdscript
class_name ResourceController
extends Node

signal values_changed(growth: float, threshold: float, stability: float)
signal toxin_changed(active: bool)
signal form_transitioned(form_id: StringName)

const MAX_STABILITY := 100.0
const TOXIN_DRAIN_PER_SECOND := 35.0
const STABILITY_RECOVERY_PER_SECOND := 20.0
const NUTRITION_STABILITY_MULTIPLIER := 1.25
const TOXIN_SPEED_MULTIPLIER := 0.55

var growth_progress := 0.0
var stability := MAX_STABILITY
var _forms: FormController
var _toxin_sources: Dictionary = {}

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
    if form.growth_threshold > 0.0:
        growth_progress = minf(growth_progress + nutrition_left, form.growth_threshold)
        if growth_progress >= form.growth_threshold and _forms.grow():
            growth_progress = 0.0
            form_transitioned.emit(_forms.get_current().id)
    _emit_values()
    return true
```

Implement `tick()` with toxin drain, one-step wither at zero, recovery outside toxin, source-set semantics, and dictionary-only snapshots `{growth, stability}`.

```gdscript
func tick(delta: float) -> void:
    if not _toxin_sources.is_empty():
        stability = maxf(0.0, stability - TOXIN_DRAIN_PER_SECOND * delta)
        if stability <= 0.0:
            if _forms.wither():
                growth_progress = 0.0
                form_transitioned.emit(_forms.get_current().id)
            stability = MAX_STABILITY
    else:
        stability = minf(MAX_STABILITY, stability + STABILITY_RECOVERY_PER_SECOND * delta)
    _emit_values()

func enter_toxin(source: Object) -> void:
    _toxin_sources[source.get_instance_id()] = weakref(source)
    toxin_changed.emit(true)

func exit_toxin(source: Object) -> void:
    _toxin_sources.erase(source.get_instance_id())
    toxin_changed.emit(not _toxin_sources.is_empty())
```

- [ ] **Step 4: Run resource and progression tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_resource_controller.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_form_progression.gd
```

Expected: both exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add features/resources/resource_controller.gd tests/unit/test_resource_controller.gd
git commit -m "feat: add nutrition and toxin resource state"
```

---

### Task 3: Player Composition, Collision, Root, Leg Extension, and Glide

**Files:**
- Create: `features/abilities/ability_controller.gd`
- Create: `tests/scene/test_player_abilities.gd`
- Modify: `features/player/player.gd`
- Modify: `features/player/movement_controller.gd`
- Modify: `features/player/state_machine.gd`
- Modify: `features/player/player_visuals.gd`
- Modify: `features/player/player.tscn`
- Modify: `project.godot`

**Interfaces:**
- Consumes: `FormController`, `ResourceController`, `FormDefinition` capabilities.
- Produces: `AbilityController.setup(player, movement, forms, leg_area)`, `toggle_primary()`, `set_leg_extension_direction(direction)`, `try_root()`, `try_extend_legs()`, `stop_primary()`, `stop_secondary()`, `cancel_all()`, `is_rooted()`, `is_leg_extended()`, `is_vine_attached()`.
- Produces: public player component references `resources: ResourceController` and `abilities: AbilityController`.
- Produces: player methods `absorb_nutrition(amount: float) -> bool`, `enter_toxin(source: Object)`, `exit_toxin(source: Object)`, `apply_wind(force: float, delta: float)`, `capture_state() -> Dictionary`, `restore_state(snapshot: Dictionary)`, `cancel_actions()`.

- [ ] **Step 1: Add directional movement actions and write failing player ability tests**

```gdscript
func _run() -> void:
    var player := preload("res://features/player/player.tscn").instantiate() as Player
    var ground := _make_ground()
    root.add_child(ground)
    root.add_child(player)
    player.global_position = Vector2(0.0, -1.0)
    await _physics_steps(4)
    assert(player.current_form_id() == &"sprout")
    assert(not player.abilities.try_root())
    assert(player.form_controller.restore_form(&"humanoid"))
    await physics_frame
    assert(player.abilities.try_root())
    assert(player.abilities.is_rooted())
    player.abilities.stop_primary()
    assert(player.abilities.try_extend_legs())
    assert(player.abilities.is_leg_extended())
    player.cancel_actions()
    assert(not player.abilities.is_leg_extended())
    assert(player.form_controller.restore_form(&"mature"))
    player.velocity.y = 500.0
    player.movement.tick(0.1, 0.0, true)
    assert(player.velocity.y <= player.form_controller.get_current().glide_fall_speed)
```

Use a `SceneTree` test with a world-layer `StaticBody2D`, await helpers, cleanup, and `quit()`.

- [ ] **Step 2: Run and verify the missing component fails**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_player_abilities.gd
```

Expected: parser or assertion failure because `AbilityController` is absent.

- [ ] **Step 3: Implement focused ability state**

```gdscript
class_name AbilityController
extends Node

signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)

var _player: Player
var _movement: MovementController
var _forms: FormController
var _leg_area: Area2D
var _rooted := false
var _leg_extended := false

func try_root() -> bool:
    var form := _forms.get_current()
    if not form.can_root or not _player.is_on_floor() or _leg_extended:
        return false
    _rooted = true
    _movement.set_rooted(true)
    ability_state_changed.emit(&"rooted")
    return true

func try_extend_legs() -> bool:
    var form := _forms.get_current()
    if not form.can_extend_legs or not _player.is_on_floor() or _rooted:
        return false
    _leg_extended = true
    _leg_area.monitoring = true
    _movement.set_movement_locked(true)
    ability_state_changed.emit(&"legs")
    return true
```

Add idempotent stop methods and `cancel_all()`. Make the player origin represent its feet; update the `RectangleShape2D` size and vertical offset on form change. Use a zero-length `ShapeCast2D` on the world mask before growing, and set it as `FormController`'s switch validator. Add the 72-pixel leg `Area2D` to group `leg_extension`.

- [ ] **Step 4: Integrate player input and movement flags**

```gdscript
# player.gd input excerpt
resources.tick(delta)
if Input.is_action_just_pressed("ability_primary"):
    abilities.toggle_primary()
abilities.set_leg_extension_direction(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
var move_dir := Input.get_axis("move_left", "move_right")
state_machine.tick(delta, move_dir, Input.is_action_pressed("jump"))
```

In `MovementController`, apply `resources.speed_multiplier()`, ignore wind while rooted, lock movement while rooted/extended, and use `form.can_glide` rather than the old independent flag. Remove normal `switch_form` cycling from `_unhandled_input()`.

- [ ] **Step 5: Run player, resource, and form tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_player_abilities.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_resource_controller.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tests/scene/player_movement_test.tscn --quit-after 120
```

Expected: all exit `0`, with no script errors.

- [ ] **Step 6: Commit**

```powershell
git add project.godot features/abilities/ability_controller.gd features/player/player.gd features/player/movement_controller.gd features/player/state_machine.gd features/player/player_visuals.gd features/player/player.tscn tests/scene/test_player_abilities.gd
git commit -m "feat: integrate player form abilities"
```

---

### Task 4: Vine Anchor and Swing Physics

**Files:**
- Create: `features/abilities/vine_anchor.gd`
- Create: `features/abilities/vine_anchor.tscn`
- Modify: `features/abilities/ability_controller.gd`
- Modify: `features/player/movement_controller.gd`
- Modify: `features/player/player_visuals.gd`
- Modify: `tests/scene/test_player_abilities.gd`

**Interfaces:**
- Produces: `VineAnchor : Node2D`, group `vine_anchor`.
- Produces: `MovementController.attach_vine(anchor, length)`, `detach_vine()`, `is_vine_attached()`.
- Consumes: mature `can_use_vine`, 300-pixel selection range, primary input state.

- [ ] **Step 1: Extend the failing ability test**

```gdscript
var anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
root.add_child(anchor)
anchor.global_position = player.global_position + Vector2(120.0, -160.0)
player.form_controller.restore_form(&"mature")
assert(player.abilities.try_attach_vine())
assert(player.abilities.is_vine_attached())
var length_before := player.global_position.distance_to(anchor.global_position)
player.movement.tick(0.1, 1.0, false)
assert(player.global_position.distance_to(anchor.global_position) <= length_before + 1.0)
player.abilities.stop_primary()
assert(not player.abilities.is_vine_attached())
```

- [ ] **Step 2: Run and verify failure**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_player_abilities.gd
```

Expected: missing `VineAnchor` / `try_attach_vine` failure.

- [ ] **Step 3: Implement anchor selection and the rope constraint**

```gdscript
func try_attach_vine() -> bool:
    if not _forms.get_current().can_use_vine:
        return false
    var nearest := _nearest_visible_anchor(300.0)
    if nearest == null:
        feedback_requested.emit("NO ANCHOR")
        return false
    _vine_anchor = nearest
    _movement.attach_vine(nearest, _player.global_position.distance_to(nearest.global_position))
    ability_state_changed.emit(&"vine")
    return true
```

Use a direct-space-state ray query from the player to each range-qualified anchor; exclude the player RID and accept only anchors whose ray is unobstructed or whose collider is the anchor itself.

```gdscript
# movement_controller.gd after gravity and horizontal acceleration
if is_instance_valid(_vine_anchor):
    var radial := body.global_position - _vine_anchor.global_position
    if radial.length() > _vine_length:
        body.global_position = _vine_anchor.global_position + radial.normalized() * _vine_length
        var outward := body.velocity.dot(radial.normalized())
        if outward > 0.0:
            body.velocity -= radial.normalized() * outward
        var tangent := Vector2(-radial.y, radial.x).normalized()
        body.velocity += tangent * move_dir * vine_tangent_acceleration * delta
```

Draw the rope from player to anchor in `PlayerVisuals`; clear it on detach, death, form change, and reset.

- [ ] **Step 4: Run ability and movement scene tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_player_abilities.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tests/scene/player_movement_test.tscn --quit-after 120
```

Expected: player ability test and movement test scene exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add features/abilities/vine_anchor.gd features/abilities/vine_anchor.tscn features/abilities/ability_controller.gd features/player/movement_controller.gd features/player/player_visuals.gd tests/scene/test_player_abilities.gd
git commit -m "feat: add whitebox vine swinging"
```

---

### Task 5: Physical Whitebox Interactions

**Files:**
- Create: `features/level/wind_zone.gd`
- Create: `features/level/wind_zone.tscn`
- Create: `features/level/ability_switch.gd`
- Create: `features/level/ability_switch.tscn`
- Create: `features/level/whitebox_gate.gd`
- Create: `features/level/whitebox_gate.tscn`
- Create: `features/level/exit_goal.gd`
- Create: `features/level/exit_goal.tscn`
- Create: `tests/scene/test_whitebox_interactions.gd`
- Modify: `features/level/nutrition_tank.gd`
- Modify: `features/level/nutrition_tank.tscn`
- Modify: `features/level/checkpoint.gd`

**Interfaces:**
- Consumes: Player public resource/wind/form methods and `leg_extension` group.
- Produces: `WindZone.set_blowing_for_test(active: bool)`, `AbilitySwitch.is_active()`, `WhiteboxGate.is_closed()`, and `ExitGoal` locked/completed signals.
- Preserves: existing `NutritionTank.absorb`, `Checkpoint.checkpoint_reached`, `WhiteboxSwitch`, and `ExitDevice` tests.

- [ ] **Step 1: Write failing physical interaction tests**

```gdscript
assert(nutrition_tank.nutrition_per_second == 40.0)
nutrition_tank.body_entered.emit(player)
nutrition_tank._physics_process(1.0)
assert(player.resources.growth_progress == 40.0)

wind_zone.set_blowing_for_test(true)
var speed_before := player.velocity.x
wind_zone.apply_to_actor(player, 0.5)
assert(player.velocity.x > speed_before)
player.form_controller.restore_form(&"humanoid")
player.abilities.try_root()
speed_before = player.velocity.x
wind_zone.apply_to_actor(player, 0.5)
assert(player.velocity.x == speed_before)

assert(not high_switch.is_active())
high_switch.try_activate_area(player.abilities.leg_area())
assert(high_switch.is_active())
assert(not gate.is_closed())
```

Also assert the low switch rejects humanoid, accepts sprout, and the exit emits locked feedback until both required switches are active.

- [ ] **Step 2: Run and verify missing-scene failure**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_whitebox_interactions.gd
```

Expected: missing class/scene parser failure.

- [ ] **Step 3: Implement continuous nutrition and actor-aware checkpoints**

```gdscript
# nutrition_tank.gd
@export var nutrition_per_second := 40.0
var _actors: Array[Node] = []

func _physics_process(delta: float) -> void:
    for actor in _actors:
        if is_instance_valid(actor):
            absorb(actor, nutrition_per_second * delta)
```

Add `signal actor_checkpoint_reached(actor: Node2D, position: Vector2)` while preserving the original checkpoint signal and activation behavior.

- [ ] **Step 4: Implement wind, switches, gates, and exit**

`WindZone` alternates `warning_duration = 1.0` and `blow_duration = 1.5`, applies `wind_force = 900.0`, and exposes `apply_to_actor(actor, delta)` for deterministic tests. `AbilitySwitch` has enum modes `LEG_EXTENSION` and `SPROUT_BODY`, latches active once, and emits `activated`. `WhiteboxGate` disables its `CollisionShape2D` with `set_deferred("disabled", true)` after activation. `ExitGoal` receives required switch nodes and emits `player_completed(player)` or `locked_entered`.

```gdscript
func apply_to_actor(actor: Node2D, delta: float) -> void:
    if _blowing and actor.has_method(&"apply_wind"):
        actor.call(&"apply_wind", wind_force * direction, delta)

func _activate() -> void:
    if _active:
        return
    _active = true
    activated.emit()

func open() -> void:
    _closed = false
    collision_shape.set_deferred("disabled", true)
    queue_redraw()
```

- [ ] **Step 5: Run new and existing interaction tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_whitebox_interactions.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_level_interactions.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/unit/test_whitebox_switch.gd
```

Expected: all exit `0`.

- [ ] **Step 6: Commit**

```powershell
git add features/level/wind_zone.gd features/level/wind_zone.tscn features/level/ability_switch.gd features/level/ability_switch.tscn features/level/whitebox_gate.gd features/level/whitebox_gate.tscn features/level/exit_goal.gd features/level/exit_goal.tscn features/level/nutrition_tank.gd features/level/nutrition_tank.tscn features/level/checkpoint.gd tests/scene/test_whitebox_interactions.gd
git commit -m "feat: add physical whitebox interactions"
```

---

### Task 6: Playable Level, Checkpoint State, HUD, and Completion

**Files:**
- Create: `features/ui/game_hud.gd`
- Create: `features/ui/game_hud.tscn`
- Create: `features/ui/completion_overlay.gd`
- Create: `features/ui/completion_overlay.tscn`
- Create: `tests/scene/test_playable_whitebox.gd`
- Modify: `scenes/levels/whitebox_sandbox.gd`
- Modify: `scenes/levels/whitebox_sandbox.tscn`
- Modify: `scenes/app/main.tscn`

**Interfaces:**
- Consumes: player snapshots, checkpoint events, hazards, switches, gates, exit, resource/ability signals.
- Produces: signals `checkpoint_changed(checkpoint_id)`, `completion_changed(completed, seconds)`.
- Produces: `WhiteboxSandbox.get_player()`, `respawn_player()`, `restart_level()`, `complete_level()`, `elapsed_time()`, `is_completed()`, `checkpoint_form_id()`, and deterministic `activate_checkpoint_for_test(checkpoint_id)`.
- Produces: read-only HUD binding `GameHud.bind_player(player, level)` and overlay `show_completion(seconds)`.

- [ ] **Step 1: Write the failing playable-level contract test**

```gdscript
var level := preload("res://scenes/levels/whitebox_sandbox.tscn").instantiate() as WhiteboxSandbox
root.add_child(level)
await process_frame
var player := level.get_player()
assert(player != null)
assert(player.current_form_id() == &"sprout")
assert(level.get_node("Course/LowTunnel") != null)
assert(level.get_node("Course/WindSection/WindZone") != null)
assert(level.get_node("Course/HighSwitch") != null)
assert(level.get_node("Course/VineSection/VineAnchor") != null)
assert(level.get_node("Course/ToxinSection/ToxinZone") != null)
assert(level.get_node("Course/FinalLowSwitch") != null)
var initial := player.capture_state()
level.activate_checkpoint_for_test(&"mid")
player.form_controller.restore_form(&"mature")
level.respawn_player()
assert(player.current_form_id() == level.checkpoint_form_id())
level.restart_level()
assert(player.current_form_id() == initial.form_id)
assert(not level.is_completed())
```

Add direct contract assertions that completion is rejected with closed switches and accepted once both switches are active.

- [ ] **Step 2: Run and verify failure**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_playable_whitebox.gd
```

Expected: missing player/course API assertions.

- [ ] **Step 3: Assemble the course and level lifecycle**

Create a roughly 3600-pixel horizontal whitebox with ordered sections from the spec. Use `StaticBody2D` rectangles for floors, gaps, low ceilings, and gates; visible `Polygon2D` nodes mirror every collision. Add a player instance at the start, a following `Camera2D`, two nutrition zones, rhythmic wind plus hazard, a high leg switch and gate, a mid checkpoint, a mature nutrition zone, vine anchor and gap, glide landing, toxin zone, final low tunnel/switch, and exit.

```gdscript
func respawn_player() -> void:
    _player.cancel_actions()
    _player.velocity = Vector2.ZERO
    _restore_checkpoint_snapshot()

func restart_level() -> void:
    _completed = false
    _elapsed = 0.0
    _reset_all_interactions()
    _checkpoint_snapshot = _initial_snapshot.duplicate(true)
    _restore_checkpoint_snapshot()

func complete_level() -> void:
    if _completed or not _all_required_switches_active():
        return
    _completed = true
    completion_changed.emit(true, _elapsed)
    GlobalSignalBus.level_completed.emit(level_id)
```

- [ ] **Step 4: Add read-only HUD and completion overlay**

Bind labels and progress bars to player signals. Show form, growth, stability, contextual controls, ability state, checkpoint/locked feedback, and a centered completion panel with elapsed seconds and `R 重新开始`.

```gdscript
func bind_player(player: Player, level: WhiteboxSandbox) -> void:
    _player = player
    _level = level
    player.resources.values_changed.connect(_on_values_changed)
    player.form_controller.form_changed.connect(_on_form_changed)
    player.abilities.ability_state_changed.connect(_on_ability_state_changed)
    player.abilities.feedback_requested.connect(show_message)
    level.checkpoint_changed.connect(_on_checkpoint_changed)
    level.completion_changed.connect(_on_completion_changed)
    _refresh_all()
```

- [ ] **Step 5: Run level and main-scene tests**

```powershell
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_playable_whitebox.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/scene/test_whitebox_sandbox.gd
& '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --quit-after 180
```

Expected: all exit `0`, no script errors, and main scene reaches 180 frames.

- [ ] **Step 6: Commit**

```powershell
git add scenes/levels/whitebox_sandbox.gd scenes/levels/whitebox_sandbox.tscn scenes/app/main.tscn features/ui/game_hud.gd features/ui/game_hud.tscn features/ui/completion_overlay.gd features/ui/completion_overlay.tscn tests/scene/test_playable_whitebox.gd
git commit -m "feat: assemble playable whitebox level"
```

---

### Task 7: Regression, Documentation, and Actual Keyboard Playthrough

**Files:**
- Modify: `README.md`
- Modify: `docs/api/level.md`
- Modify: `docs/api/interactions.md`
- Modify: `WIP.md`
- Test: all files under `tests/unit` and `tests/scene`

**Interfaces:**
- Consumes: the completed vertical slice.
- Produces: an evidence-backed playable handoff with current controls and API documentation.

- [ ] **Step 1: Run every automated test script**

```powershell
$godot = '..\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
Get-ChildItem tests -Recurse -Filter 'test_*.gd' | ForEach-Object {
    $relative = 'res://' + $_.FullName.Substring((Get-Location).Path.Length + 1).Replace('\','/')
    & $godot --headless --path . --script $relative
    if ($LASTEXITCODE -ne 0) { throw "Failed: $relative" }
}
```

Expected: every script exits `0`.

- [ ] **Step 2: Run clean import, reusable scenes, and main launch**

```powershell
& $godot --headless --editor --path . --quit
& $godot --headless --path . res://features/player/player.tscn --quit-after 120
& $godot --headless --path . res://scenes/levels/whitebox_sandbox.tscn --quit-after 180
& $godot --headless --path . --quit-after 180
```

Expected: all exit `0`; the current Godot log has zero matches for `SCRIPT ERROR`, `Parse Error`, or `ERROR`.

- [ ] **Step 3: Update documentation with implemented behavior**

Update README controls/start instructions, level API player/snapshot lifecycle, and interaction APIs for wind/switch/gate/exit. Remove the completed implementation-plan entry from `WIP.md` only after all automated and manual acceptance checks pass; keep the design and plan documents as process records.

- [ ] **Step 4: Perform the real-window keyboard playthrough**

Launch `Godot_v4.7.2-stable_win64.exe --path <repo>`. Use only left mouse, `W/A/S/D`, `Space`, and optional `R`. Verify, in order: sprout tunnel, nutrition growth to humanoid, root against active wind, directional leg switch, checkpoint, growth to mature, vine attach/release, glide landing, toxin wither to sprout, final low switch, unlocked exit, completion overlay. Do not invoke debug form switching or scene methods.

- [ ] **Step 5: Verify repository scope and commit**

```powershell
git diff --check
git status --short
git diff --stat origin/main...HEAD
git add README.md docs/api/level.md docs/api/interactions.md WIP.md
git commit -m "docs: document playable whitebox controls"
```

Expected: no whitespace errors, no generated files, and only planned gameplay/test/documentation changes.

- [ ] **Step 6: Record final evidence**

Report the commit list, automated test count, headless launch results, actual playthrough result, completion time, log error count, known whitebox limitations, and the absolute project path.
