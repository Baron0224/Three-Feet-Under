# Quality Godot First Person Controller v2 attribution

Upstream: https://github.com/ColormaticStudios/quality-godot-first-person-2
Pinned commit: 27fab75ca8f6d949d887e9f3f9008c2b0e8bb603
Source: addons/fpc/character.gd at the pinned commit
Source SHA-256 (UTF-8 text as fetched): 44f9d9c88b773c42ec2b9b67e9382e172d19d4eb77a264dd74437ff4013cbb49
License: MIT; Copyright (c) 2023 Colormatic. Full license in LICENSE alongside this file.

Reviewed source and license read-only before adaptation. No upstream demo, dependencies,
editor plugins, tool scripts or autoloads were installed or executed.

Adaptation in res://player.gd (2026-11-05):
- Derived the Input.get_vector direction / yaw mapping and direct horizontal velocity
  pattern from _handle_movement (motion_smoothing=false, in_air_momentum=false).
- Adapted _handle_jumping's just-pressed + floor + nonascending checks; no continuous
  hopping, sprint, animation dependency, head bob, reticle, gamepad or dynamic FOV.
- Adapted hold-crouch state and low-ceiling release guard from _handle_state.
  Replaced animation/raycast dependencies with an instance-local capsule resize,
  a complete standing-capsule physics query, and delta-based camera interpolation.
- Kept this project's Camera3D node, yaw/mouse handling and scene structure.
- Added project-specific Shift slow walking, reading/death locks, controls/death HUD,
  bounds-restricted abyss threshold and guarded delayed current-scene reload.

This is a minimal source adaptation, not the complete upstream controller package.
Standing clearance, death/reload and tablet integration are project additions.
