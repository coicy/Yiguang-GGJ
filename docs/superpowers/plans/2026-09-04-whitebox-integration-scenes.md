# Whitebox Integration Scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build independently launchable interaction scenes, a player-free sandbox, and a root startup shell ready for the player module.

**Architecture:** Each interaction is feature-owned and communicates through typed local signals. `WhiteboxSandbox` owns its local wiring, checkpoint, reset, and completion; `Main` only hosts it. `%PlayerAnchor` is an insertion point, never a temporary player.

**Tech Stack:** Godot 4.7.2, typed GDScript, `Area2D`, `Node2D`, `TileMapLayer`, headless scripts.

**Spec:** `docs/scene_design_and_ownership.md`, `docs/architecture.md`, `docs/development_guidelines.md`, `docs/api/interactions.md`, `docs/api/level.md`.

## Global Constraints

- Use root `project.godot`, never modify `2.0/`.
- Do not create or modify player, form, or ability code.
- Use layer 6/mask 2 for hazards and layer 7/mask 2 for interactables.
- `GlobalSignalBus` receives only cross-scene lifecycle facts and no Nodes.

---

### Task 1: Implement and test switch/exit contracts

**Files:**
- Create: `tests/unit/test_whitebox_switch.gd`
- Create: `features/level/whitebox_switch.gd`
- Create: `features/level/exit_device.gd`
- Modify: `docs/api/interactions.md`

**Interfaces:**
- `WhiteboxSwitch : Node`: `activate() -> void`, `deactivate() -> void`, `is_active() -> bool`, `activated`, `deactivated`.
- `ExitDevice : Node`: `set_required_switches(count: int) -> void`, `register_switch(switch: WhiteboxSwitch) -> void`, `is_open() -> bool`, `opened`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree
func _init() -> void:
	var switch_node := WhiteboxSwitch.new()
	var exit_device := ExitDevice.new()
	exit_device.set_required_switches(1)
	exit_device.register_switch(switch_node)
	assert(not exit_device.is_open())
	switch_node.activate()
	assert(exit_device.is_open())
	quit()
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . --script tests/unit/test_whitebox_switch.gd`

Expected: class-missing failure.

- [ ] **Step 3: Implement the smallest API**

`WhiteboxSwitch` stores `_active: bool` and emits only on transition. `ExitDevice` stores typed registered switches, reconnects no duplicate signal, and emits `opened` only for closed-to-open transition.

- [ ] **Step 4: Verify green**

Run: `godot --headless --path . --script tests/unit/test_whitebox_switch.gd`

Expected: exit code 0.

- [ ] **Step 5: Commit**

Run: `git add features/level/whitebox_switch.gd features/level/exit_device.gd tests/unit/test_whitebox_switch.gd docs/api/interactions.md`

Run: `git commit -m "feat: add whitebox switch and exit contracts"`

### Task 2: Implement and test area interaction scenes

**Files:**
- Create: `tests/unit/test_level_interactions.gd`
- Create: `features/level/toxin_zone.gd`, `hazard.gd`, `checkpoint.gd`, `nutrition_tank.gd`
- Create: `features/level/toxin_zone.tscn`, `hazard.tscn`, `checkpoint.tscn`, `nutrition_tank.tscn`
- Modify: `docs/api/interactions.md`

**Interfaces:**
- `ToxinZone : Area2D`: `actor_entered(actor: Node2D)`, `actor_exited(actor: Node2D)`, `is_actor_inside(actor: Node2D) -> bool`.
- `Hazard : Area2D`: `actor_hurt(actor: Node2D)`, `actor_killed(actor: Node2D)`, `kill(actor: Node2D) -> void`.
- `Checkpoint : Area2D`: `activate(actor: Node2D) -> bool`, `get_checkpoint_position() -> Vector2`, `checkpoint_reached(position: Vector2)`.
- `NutritionTank : Area2D`: `absorb(actor: Node, amount: float) -> bool`; it calls only `actor.absorb_nutrition(amount)`.

- [ ] **Step 1: Write failing tests**

```gdscript
var checkpoint := Checkpoint.new()
checkpoint.position = Vector2(64.0, 32.0)
assert(checkpoint.get_checkpoint_position() == Vector2(64.0, 32.0))
assert(not NutritionTank.new().absorb(Node.new(), 1.0))
```

Include a test actor whose `absorb_nutrition(amount: float) -> bool` returns `true`.

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . --script tests/unit/test_level_interactions.gd`

Expected: class-missing failure.

- [ ] **Step 3: Implement smallest scripts and scenes**

Each scene has one unscaled `CollisionShape2D` using `RectangleShape2D`. `Checkpoint` returns only `global_position`, and no interaction node searches the tree for level or player nodes.

- [ ] **Step 4: Verify green and parse scenes**

Run: `godot --headless --path . --script tests/unit/test_level_interactions.gd`

Run: `godot --headless --path . --editor --quit`

Expected: both exit code 0; manually run reusable scenes with F6.

- [ ] **Step 5: Commit**

Run: `git add features/level tests/unit/test_level_interactions.gd docs/api/interactions.md`

Run: `git commit -m "feat: add whitebox level interaction scenes"`

### Task 3: Implement and test the sandbox/startup shell

**Files:**
- Create: `tests/scene/test_whitebox_sandbox.gd`
- Create: `scenes/levels/whitebox_sandbox.gd`, `scenes/levels/whitebox_sandbox.tscn`
- Modify: `scenes/app/main.tscn`, `docs/api/level.md`

**Interfaces:**
- `WhiteboxSandbox : Node2D`: `reset_level() -> void`, `complete_level() -> void`, `get_checkpoint_position() -> Vector2`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree
const SANDBOX := preload("res://scenes/levels/whitebox_sandbox.tscn")
func _init() -> void:
	var sandbox := SANDBOX.instantiate() as WhiteboxSandbox
	root.add_child(sandbox)
	assert(sandbox.get_node("Actors/PlayerAnchor") is Marker2D)
	assert(sandbox.get_node("Interactions/SwitchA") is WhiteboxSwitch)
	sandbox.reset_level()
	quit()
```

- [ ] **Step 2: Verify red**

Run: `godot --headless --path . --script tests/scene/test_whitebox_sandbox.gd`

Expected: missing-scene failure.

- [ ] **Step 3: Implement sandbox and root shell**

`WhiteboxSandbox` stores `_checkpoint_position: Vector2`, connects children in `_ready()` by `%SceneUniqueName`, resets `SwitchA`, and moves `%PlayerAnchor`. It emits `GlobalSignalBus.level_completed` only if exit is open. `main.tscn` gets a `LevelHost` containing the sandbox and retains `Interface` and `Debug`.

- [ ] **Step 4: Verify green and project startup**

Run: `godot --headless --path . --script tests/scene/test_whitebox_sandbox.gd`

Run: `godot --headless --path . --editor --quit`

Run: `godot --headless --path . --quit-after 2`

Expected: all exit code 0.

- [ ] **Step 5: Commit**

Run: `git add scenes/app/main.tscn scenes/levels tests/scene/test_whitebox_sandbox.gd docs/api/level.md`

Run: `git commit -m "feat: assemble whitebox sandbox shell"`

### Task 4: Final verification and public API review

**Files:**
- Modify: `docs/api/interactions.md`, `docs/api/level.md`, `WIP.md`

- [ ] **Step 1: Run every test script**

Run: `godot --headless --path . --script tests/unit/test_whitebox_switch.gd`

Run: `godot --headless --path . --script tests/unit/test_level_interactions.gd`

Run: `godot --headless --path . --script tests/scene/test_whitebox_sandbox.gd`

- [ ] **Step 2: Validate project and diff**

Run: `godot --headless --path . --editor --quit`

Run: `godot --headless --path . --quit-after 2`

Run: `git diff --check`

- [ ] **Step 3: Align API documents**

Record exact Task 1–3 methods and signals. Retain the WIP plan entry until this implementation is accepted as an ongoing project record.

- [ ] **Step 4: Commit**

Run: `git add docs/api/interactions.md docs/api/level.md WIP.md`

Run: `git commit -m "docs: verify whitebox integration contracts"`
