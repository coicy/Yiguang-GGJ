# Project Instructions

This repository is a Godot 4.7.2 2D single-player Game Jam project. Keep the project practical for a 48-hour development window and respect the user's requested scope; do not implement unrelated gameplay, systems, or polish.

## Required context

Before changing project architecture or gameplay, read:

- `docs/architecture.md`
- `docs/development_guidelines.md`

Before adding or changing an addon, external tool, or asset pipeline, also read:

- `docs/toolkit.md`
- `docs/credits.md` when external assets or tools are involved

Use the smallest relevant subset of these documents for small fixes, but do not bypass their rules silently.

## Architecture rules

- Organize by feature: `features/player`, `features/forms`, `features/abilities`, `features/combat`, `features/enemies`, `features/level`, and `features/ui`.
- Use one reusable `CharacterBody2D` player scene. Keep movement, state transitions, form switching, abilities, and combat as separate responsibilities.
- Store designer-tuned form and ability data in `Resource` assets. Duplicate mutable runtime data deeply; never mutate shared `.tres` data.
- Keep combat optional and independent from the movement loop.
- Use `Signal Up, Call Down`: local typed signals for scene-owned events, direct method calls for parent commands, and `GlobalSignalBus` only for a small set of cross-scene lifecycle events.
- Keep `GlobalSignalBus` and `RunState` lean. Never store scene-specific node references in an Autoload.

## Godot rules

- Use typed GDScript, `snake_case` files/methods, and `PascalCase` nodes/classes.
- Use `%SceneUniqueName` references instead of brittle absolute node paths.
- Run character movement in `_physics_process()` using `velocity` and `move_and_slide()`; do not move gameplay by assigning `global_position`.
- Preserve coyote time, jump buffering, and variable jump height when implementing platform movement.
- Use `TileMapLayer`/`TileSet` for level geometry and one-way platforms. Use `AnimatableBody2D` with physics synchronization for moving platforms.
- Do not access child nodes in `_init()`, put physics in `_physics_process()`, and do not use per-frame `print()` calls.
- Do not add a third-party addon unless its Godot 4.7.2 compatibility, license, version, owner, and removal path are documented in `docs/toolkit.md`.

## Verification

- Every reusable entity scene must pass an F6 current-scene launch test.
- Run a project launch test after changes to `project.godot`, Autoloads, scenes, or input actions.
- Prefer small unit/scene tests for pure data and physics contracts; do not make full-level integration tests the default.
- Do not commit `.godot/`, local engine binaries, build output, `.agents/`, or `skills-lock.json`.
