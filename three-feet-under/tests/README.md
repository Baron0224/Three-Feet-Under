# Player controls regression check

Run from the Godot project directory:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/player_controls_check.gd
```

Checks the live shared controller in main.tscn and tomb_corridor.tscn with synthetic
InputMap actions/key events and real CharacterBody3D physics. Temporary low ceilings
exist only in the test scene tree. The check reloads the tomb scene on purpose.
It exits 0 when all assertions pass. The missing-current-scene failure case deliberately
emits one `Level restart failed: Unconfigured` warning before testing R-key recovery.

The headless display driver has no OS cursor: mouse checks cover event handling and
explicit capture state, not visible OS capture. GUI camera feel and HUD typography
still need a human playthrough. The test does not edit scene files.

## Final wing architecture

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/final_wing_check.gd
```

Samples standing and jump-apex capsule clearance and floor support in 10-12, then drives
the live controller both ways through all three hall lanes, the north side room,
around the coffin base and up/down the exit stairs. It also checks that columns/coffin
are solid, box meshes match their colliders and the visible exit wall blocks walkout.

## 1.5x environment regression

The scene metadata provides the authored environment scale. Tests multiply environmental
coordinates/ground heights and required traversal duration, never capsule radius/height,
eye offset, speed or jump height. main.tscn remains 1.0x. New commands:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/environment_scale_check.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/side_wings_check.gd
```

Scale audit checks world transforms (including nested wings and art), real room sizes,
human physics/flashlight/tablet range, material block sizes and an actual fall from the
eastern 1.5x bank beyond the old hardcoded bounds followed by scene restart. Side-wing
checks follow both enlarged west/east routes and shortcuts with the live controller,
plus 132 no-support/deep-floor/death-volume probes across the enlarged abyss.
