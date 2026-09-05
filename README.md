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
- Left Mouse: toggle root in humanoid form, or attach/detach from the nearest visible vine anchor in mature form.
- `W/A/S/D`: while rooted in humanoid form, slowly extend the leg in cardinal directions and push the player; release to retract.
- Hold `E` inside nutrition or toxin liquid to absorb it; without `E`, neither liquid is absorbed. Each stage change ends that absorption session: release and press `E` again to continue.
- `R`: restart the complete course from the beginning.
- `F3`: toggle the existing debug overlay.

Forms are earned through gameplay. `E` is reserved for resource absorption; it does not cycle forms.

## Gameplay audio

Existing Kenney sounds from the `lan` asset branch now accompany footsteps, jumping/landing, growth/withering, absorption, rooting/leg extension, vine attachment, gliding, buttons, moving cubes, checkpoints, and death. Sources and event tuning are recorded in [credits](docs/credits.md).
