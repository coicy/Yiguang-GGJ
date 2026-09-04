# Whitebox Core Gameplay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a runnable Godot whitebox vertical slice for the GDD's core platforming, form conversion, toxin, ability, and interaction rules.

**Architecture:** Keep one reusable `CharacterBody2D` player scene. Put designer-tuned form and ability data in typed `Resource` classes, keep runtime state in focused Nodes/RefCounted objects, and communicate upward with typed signals. A minimal sandbox level will exercise the systems without defining a production level layout.

**Tech Stack:** Godot 4.7.2, typed GDScript, `CharacterBody2D`, `TileMapLayer`-compatible collision geometry, `Resource`, `Area2D`, `AnimatableBody2D`, headless Godot script tests.

**Spec:** `docs/GDD.md`, `docs/architecture.md`, `docs/development_guidelines.md`, and `docs/api/README.md`.

## Global Constraints

- Use the root `project.godot` as the only project target; ignore the nested `2.0/` project.
- Keep the first playable scope to movement, form conversion, toxin, abilities, interactions, and a whitebox sandbox.
- Keep combat and complex enemies out of this slice; enemy support remains a documented low-priority extension point.
- Use one player scene; do not duplicate a player scene per form.
- Use typed GDScript, feature-owned files, direct calls down, typed signals up, and no scene-node references in Autoloads.
- Every public system API change must update the corresponding `docs/api/*.md` file.
- Do not stage or modify existing user changes in `.gitignore`, `2.0/`, or `LICENSE`.

---

### Task 1: Define and test the pure form/resource model

**Files:**
- Create: `features/forms/form_definition.gd`
- Create: `features/forms/form_catalog.gd`
- Create: `tests/unit/test_form_model.gd`
- Modify: `project.godot` only if a test entrypoint is needed
- Update: `docs/api/forms.md`

**Interfaces:**
- `FormDefinition` exposes `form_id: StringName`, `stage_index: int`, `move_speed_multiplier: float`, `jump_multiplier: float`, `body_size: Vector2`, `abilities: Array[StringName]`.
- `FormCatalog` exposes `add_form(form: FormDefinition) -> void`, `get_form(form_id: StringName) -> FormDefinition`, and `has_form(form_id: StringName) -> bool`.

- [ ] Write tests for ordered stage lookup, missing-form rejection, and independent Resource instances.
- [ ] Run the unit script and confirm the failure is caused by missing classes.
- [ ] Implement the smallest typed Resource/catalog API.
- [ ] Re-run the unit script and confirm the model tests pass.
- [ ] Update the API document with exact signatures and invariants.

### Task 2: Implement form conversion and toxin state

**Files:**
- Create: `features/forms/form_state.gd`
- Create: `features/forms/form_controller.gd`
- Create: `features/forms/resource_absorber.gd`
- Create: `tests/unit/test_form_state.gd`
- Update: `docs/api/forms.md`

**Interfaces:**
- `FormState` exposes `current_form_id`, `stability`, `nutrition_progress`, `toxin_progress`, `in_toxin_zone`, `set_form(form_id: StringName) -> void`, `absorb_nutrition(amount: float) -> bool`, `absorb_toxin(amount: float) -> bool`, `tick_toxin_zone(delta: float) -> void`.
- `FormController` exposes `switch_to(form_id: StringName) -> bool`, `can_switch_to(form_id: StringName) -> bool`, and emits `form_changed(form_id: StringName)` and `form_change_rejected(form_id: StringName, reason: StringName)`.

- [ ] Write failing tests for growth thresholds, toxin shrink thresholds, stability drain, and recovery.
- [ ] Run tests and confirm expected failures.
- [ ] Implement state transitions with no scene dependencies.
- [ ] Re-run tests and confirm all form-state behaviors pass.
- [ ] Update API docs and add change notes.

### Task 3: Implement player movement and ability runtime

**Files:**
- Create: `features/player/movement_controller.gd`
- Create: `features/player/player.gd`
- Create: `features/abilities/ability_definition.gd`
- Create: `features/abilities/ability_controller.gd`
- Create: `features/player/player.tscn`
- Create: `tests/unit/test_ability_model.gd`
- Update: `docs/api/player.md`
- Update: `docs/api/forms.md`

**Interfaces:**
- `MovementController` exposes `configure_from_form(form: FormDefinition) -> void`, `set_input_axis(axis: float) -> void`, `request_jump() -> void`, and `physics_step(delta: float) -> void`.
- `AbilityDefinition` exposes `ability_id: StringName`, `required_form_id: StringName`, `cooldown: float`, `stability_cost: float`.
- `AbilityController` exposes `can_use(ability_id: StringName) -> bool`, `use(ability_id: StringName) -> bool`, and emits `ability_used(ability_id: StringName)` / `ability_rejected(ability_id: StringName, reason: StringName)`.

- [ ] Write failing tests for ability form gating, cooldown gating, and stability cost.
- [ ] Run tests and confirm expected failures.
- [ ] Implement pure ability validation first, then scene composition.
- [ ] Add coyote time, jump buffer, variable jump height, and form movement modifiers.
- [ ] Run unit tests and the player scene launch test.
- [ ] Update API docs with public methods, signals, and extension rules.

### Task 4: Implement whitebox interactions

**Files:**
- Create: `features/level/interactable.gd`
- Create: `features/level/nutrition_tank.gd`
- Create: `features/level/toxin_zone.gd`
- Create: `features/level/hazard.gd`
- Create: `features/level/checkpoint.gd`
- Create: `features/level/exit_device.gd`
- Create: `features/level/whitebox_switch.gd`
- Create: `tests/unit/test_interactions.gd`
- Update: `docs/api/interactions.md`

**Interfaces:**
- `Interactable` exposes `can_interact(actor: Node) -> bool`, `interact(actor: Node) -> bool`, and emits `interaction_succeeded(actor: Node)` / `interaction_rejected(actor: Node, reason: StringName)`.
- Resource nodes expose `absorb(actor: Node, amount: float) -> bool`.
- `WhiteboxSwitch` exposes `activate() -> void`, `deactivate() -> void`, and `is_active() -> bool`.
- `ExitDevice` exposes `set_required_switches(count: int) -> void`, `register_switch(switch: WhiteboxSwitch) -> void`, and `is_open() -> bool`.

- [ ] Write failing tests for switch state, exit unlock, resource absorption, and hazard reset signaling.
- [ ] Run tests and confirm expected failures.
- [ ] Implement small independent interaction nodes.
- [ ] Add collision layers and scene-owned signals without global node references.
- [ ] Run interaction tests and current-scene launch tests.
- [ ] Update API docs.

### Task 5: Assemble the runnable whitebox sandbox

**Files:**
- Create: `scenes/levels/whitebox_sandbox.tscn`
- Create: `scenes/levels/whitebox_sandbox.gd`
- Modify: `scenes/app/main.tscn`
- Modify: `autoloads/global_signal_bus.gd` only for required lifecycle events
- Modify: `autoloads/run_state.gd` only for checkpoint/form state that must survive reset
- Update: `docs/api/level.md`

**Interfaces:**
- `WhiteboxSandbox` exposes `reset_level() -> void`, `complete_level() -> void`, and `get_checkpoint_position() -> Vector2`.

- [ ] Build a simple collision floor, platforms, gaps, toxin zone, nutrition tank, switch, exit, checkpoint, and camera boundary.
- [ ] Wire the player and interaction signals using local scene ownership.
- [ ] Start the root project headlessly and launch the sandbox scene.
- [ ] Manually verify the core loop: move, jump, absorb, form-change, use abilities, trigger switch, open exit, reset at checkpoint.
- [ ] Update level API documentation and remove the completed WIP index entries.

### Task 6: Final verification and documentation review

**Files:**
- Update: all changed `docs/api/*.md` files as needed
- Update: `AGENT.md` to index the API documentation entrypoint

- [ ] Run every unit test script.
- [ ] Run root project editor validation and sandbox launch validation.
- [ ] Run `git diff --check`.
- [ ] Review public code symbols against API docs and fix mismatches.
- [ ] Confirm `git status` contains no accidental edits to `.gitignore`, `2.0/`, or `LICENSE`.
