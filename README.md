# Yiguang-GGJ

## GGJ ShapeShift Platformer

Godot 4.7.2 2D platformer whitebox for a 48-hour Game Jam project.

The default main scene loads the hand-built level in `scenes/levels/Level_main.tscn`. The JSON whitebox course remains available separately with its button-operated door, exit completion, and HUD.

## Start

1. Open `project.godot` with Godot 4.7.2 or a compatible 4.7 build.
2. Press F5 for the hand-built main level. To try the JSON door/exit/HUD flow, open `scenes/levels/json_whitebox_level.tscn` and press F6.
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
- `Space`: jump in humanoid/mature form; hold while falling in mature form to glide. Sprouts cannot jump.
- Left Mouse: toggle root in humanoid form, or attach/detach from a visible vine anchor in the mouse direction in mature form.
- `W/A/S/D`: while rooted in humanoid form, slowly extend the leg in cardinal directions and push the player; release to retract.
- Hold `E` inside nutrition or toxin liquid to absorb it; without `E`, neither liquid is absorbed. Each stage change ends that absorption session: release and press `E` again to continue.
- While attached to a vine ring, press `E` to move above it if the player fits and the path is clear; reaching the top releases the vine.
- `R`: restart the complete course from the beginning.
- `F3`: toggle the existing debug overlay.

Forms are earned through gameplay. `E` absorbs resources or climbs an attached ring; it does not cycle forms.

## Gameplay audio

Existing Kenney sounds from the `lan` asset branch now accompany footsteps, jumping/landing, growth/withering, absorption, rooting/leg extension, vine attachment, gliding, buttons, moving cubes, checkpoints, and death. Sources and event tuning are recorded in [credits](docs/credits.md).

## Button-operated door

Touch B1 at world position `(448, 304)` to move the door at `(624, 432)` upward by 48 pixels. B1 still drives its original C1 platform. The door remains solid as it moves, stays open, and resets when the course reloads with `R`.

Reuse `features/level/whitebox_door.tscn` for other doors. Choose `SLIDE` with `open_offset`, or `ROTATE` with `hinge_offset` and `opening_degrees` in the Inspector. The level parent connects a button's `pressed` signal to a call to `door.open()`. The existing map uses the button's `Entity_ref` list for this connection. See [entity rules](docs/whitebox_entity_rules.md) for configuration and verification.

## Exit, completion, and HUD

This flow is connected in `scenes/levels/json_whitebox_level.tscn`. The newer hand-built main entry from upstream is preserved; its `HandbuiltLevel` has not yet been connected to this exit/HUD flow.

The JSON whitebox course includes a pixel-art exit at world position `(704, 464)`. Touch the button marked “出口按钮” (B1), wait for its door to finish opening, and enter the lit exit beyond it. Opening the door alone does not win. Completing the course freezes gameplay and shows elapsed time, retry count, a victory sound, and a restart button; click it or press `R` to reset the course.

The HUD shows the current form, growth, stability, timer, retries, and exit objective. Controls update with the form, including the release-and-press-`E` requirement after each growth/withering stage, checkpoint feedback, and toxin warnings. The HUD leaves gameplay mouse input available.

Exit art, sign, prompt/lever icons, numeric font, UI palette, and victory sound reuse the existing asset branch; see [credits](docs/credits.md). A full manual playthrough and a refreshed Windows export remain to be verified. Automated checks and rendered previews are recorded in [acceptance criteria](docs/whitebox_acceptance_criteria.md).
