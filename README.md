# Yiguang-GGJ

## GGJ ShapeShift Platformer

Godot 4.7.2 2D platformer scaffold for a 48-hour Game Jam project.

This repository currently contains architecture, project configuration, and team conventions only. Gameplay implementation belongs in the feature folders described in [`docs/development_guidelines.md`](docs/development_guidelines.md).

## Start

1. Open `project.godot` with Godot 4.7.2 or a compatible 4.7 build.
2. Run the project once to verify the empty boot scene opens.
3. Read [`docs/architecture.md`](docs/architecture.md) before creating gameplay scenes.
4. Read [`docs/toolkit.md`](docs/toolkit.md) before adding an external addon.

## Current scope

- Single-player 2D platforming.
- A shared player controller with data-driven forms and abilities.
- Combat is an optional feature module, not a dependency of movement.
- Desktop keyboard baseline, with gamepad bindings added when hardware is available.
