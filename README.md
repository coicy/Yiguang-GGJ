# Yiguang-GGJ

## GGJ ShapeShift Platformer

Godot 4.7.2 2D platformer whitebox for a 48-hour Game Jam project.

The current main scene is a playable whitebox vertical slice covering all three character forms and their core traversal abilities.

## Start

1. Open `project.godot` with Godot 4.7.2 or a compatible 4.7 build.
2. Press F6/F5 to run the player scene or the complete whitebox course.
3. Read [`docs/architecture.md`](docs/architecture.md) before creating gameplay scenes.
4. Read [`docs/toolkit.md`](docs/toolkit.md) before adding an external addon.

## Current scope

- Single-player 2D platforming.
- A shared player controller with data-driven forms and abilities.
- Nutrition-driven growth from sprout to humanoid to mature form.
- Toxin stability, staged withering, checkpoints, gates, hazards, and a timed exit.
- Combat is an optional feature module, not a dependency of movement.
- Desktop keyboard baseline, with gamepad bindings added when hardware is available.

## Controls

- `A` / `D`: move.
- `Space`: jump; hold while falling in mature form to glide.
- Hold `Q`: root immediately during strong-wind phases in humanoid form, or swing from the nearest visible vine anchor in mature form; release to stop. Strong wind overpowers normal walking, so advance during warnings and root during gusts.
- Hold `F`: extend upward in humanoid form, keep walking, and step onto platforms up to the leg-extension height; release to retract.
- `R`: restart the complete course from the beginning.
- `F3`: toggle the existing debug overlay.

Forms are earned through gameplay. The old `E` form-cycle shortcut is intentionally disabled during normal play.
