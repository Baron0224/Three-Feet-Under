# Tomb art pass 01

Project-authored stone materials and static architectural dressing for Godot 4.7.2
GL Compatibility. No downloaded textures/assets, texture generators, plugins or runtime
scene-building scripts are required.

## Resources

- `shaders/world_stone.gdshader`: meter-scale world-position face projection, offset
  stone courses, recessed joints, chipped edges, sparse cracks, mineral noise and
  derivative-based surface-gradient bump. Dominant-axis projection is intended for
  static box architecture; it is not blended triplanar mapping. The relief changes
  lighting normals, never vertex positions or collisions.
- `materials/wall.tres`: 1.1 x 0.46m courses; `floor.tres`: 0.85m paving;
  `ceiling.tres`: 1.3 x 0.72m slabs. Trim, rock and coffin are separate presets.
  `block_size`, `joint_width`, `stone_color`, `relief`, `wear` control appearance.
  Rock mode uses irregular strata and fine grain rather than masonry joints.
- `tomb_environment.tres`: low cool ambient and dark background. No volumetric/depth
  fog, SSAO, screen-space reflections, SDFGI or unsupported Compatibility effects.
- `art_details.tscn`: independently instanced ArtDetails subtree; wall-foot/cornice
  bands, door surrounds, column collars, main-tomb geometric masonry relief, plinth
  edging, entrance rock facing/chips, cliff fragments and static emissive wall fixtures.
- `batches/*.tres`: 22 persisted MultiMeshes containing 517 low-poly instances
  (about 6204 triangles total). Mesh transforms are saved; no runtime generator.
  They use shared `detail_cube.tres` / `chipped_rock.tres` and material resources.

All art details are collision-free. Wall reliefs protrude approximately 4mm per face;
door surrounds stay outside the clear aperture, upper friezes above jumping space,
and fragments stay at edges/corners or in existing deep walls. No new physics bodies,
lights, symbols, puzzle props, interactive treasures, bridge or rope were added.
Existing 46 Omni lights were retuned rather than multiplied. Two fixed lights cast
shadows (hub center and hall center), plus the existing player flashlight. Deep 07
lighting is cool; ordinary local pools are warm. The 12m abyss collision gap is intact.

## Review and maintenance

`tools/rebuild_details.gd` is a one-shot authoring utility, not attached to any scene.
It requires an actual graphics driver because Godot's dummy/headless renderer cannot
round-trip MultiMesh transform buffers. It refuses headless mode and validates buffers
before saving resources. Use a hidden process to avoid disturbing an editor:

```powershell
Start-Process -WindowStyle Hidden -FilePath '<Godot console exe>' -ArgumentList @('--path','"<project path>"','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--audio-driver','Dummy','--position','-20000,-20000','--script','res://art/tools/rebuild_details.gd')
```

`tools/capture_review.gd` likewise uses a hidden real OpenGL process and a 1280x720
SubViewport with 2x MSAA. It captures 10 representative views plus actual controls/death
HUDs to the OS TEMP `tfu_art_review_v3` folder. It does not edit/save the user's editor
or scene. The renderer is real OpenGL/NVIDIA, not headless. The copy of the flashlight
on the review camera has the actual player's settings; no extra review fill lights.

Reviewed frames: entrance, entrance corridor, hub, west corridor, 04, 07 gap/depth,
10 columns, 11 coffin/relief, 12 stairs, controls HUD and death HUD. Actual capture
reported approximately 28-382 draw calls by view on the RTX 4060 Laptop GPU; this is
not an FPS benchmark or a performance guarantee. Large scene-wide batches trade fine
culling for low dressing draw count; further region/portal visibility optimization
can follow a real walk-through profile.

Still coarse: regular box silhouettes, repeated stone cracks/tiling, faceted cliff
proxy blocks, simple rectangular static light cores (no flame animation), abstract
masonry relief rather than historical carvings, and limited long-session/gameplay
lighting QA. The entrance rock facing is a visual backdrop, not traversable terrain.
This is the first art pass; gameplay mechanisms and a human GUI playthrough remain.

Reference API documentation (no external asset/code package imported):
- https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html

## Environment enlarged to 1.5x (2026-11-05)

The scene root, player, tablet and HUD are not scaled. Only root architecture subtrees
and the ArtDetails instance have uniform 1.5 scale, with root translations multiplied
once. Nested wing geometry retains its original local coordinates. Both visual meshes
and their collision children therefore expand together without gaps or duplicate scale.
Player spawn moved to (0,2.41,17.55), settling at floor Y=2.31. The tablet is unscaled
at (-2.21,1.45,-2.25), flush to the enlarged left wall at a human-readable height.

All shader/material resource bytes, block_size, joint_width and world-coordinate
mapping are unchanged: masonry is still 1.1x0.46m, paving 0.85m and ceiling slabs
1.3x0.72m. The expanded architecture shows more blocks. Lamp meshes follow ArtDetails;
existing Omni ranges are 1.5x, with light global transforms compensated to unit scale
(no accidental double range scale). Their colors/energy and the environment stay fixed.
The human flashlight remains 12m, with its original energy, cone and shadows.

Scene metadata `environment_scale=1.5` records the authored layout scale for tests/tools;
it is not a runtime resize slider. `abyss_death_bounds` is a root-local AABB defining
the expanded death region, with top Y=-7.5, before the bottom at Y=-27. The controller
reads this scene field; the unchanged main.tscn has no abyss. The baseline controller
fallback retains compatibility with the 1.0x snapshot.

`rebuild_details.gd` normalizes source world transforms back to 1.0 authoring space,
so regenerated static art is still scaled exactly once by the scene's ArtDetails node.
`capture_review.gd` scales camera x/z and floor heights while retaining human eye offsets,
FOV and flashlight range. Enlarged captures go to TEMP/tfu_scale_review_1_5;
a separately rendered 1.0x baseline is in TEMP/tfu_scale_review_1_0.

Audit snapshots / hashes / root transform changes are saved in repository
`docs/baselines/`. Snapshots use .txt suffixes to avoid duplicate Godot scene UIDs.
Geometry resources and person motion logic are unchanged; only the environment death
bounds function was adapted. Reproducible checks include tests/environment_scale_check.gd,
tests/side_wings_check.gd, tests/final_wing_check.gd and the original 58 checks.


## Unlit candles (2026-11-05)

The tomb now carries 279 extinguished candles in 17 area groups (entrance corridor,
hub, west/east wings, abyss banks, hall, tomb chamber, exit stairs, approach corridor).
They are deliberately unlit: no OmniLight, no emission, no script, no collision. The
existing 46 Omni lights and the player flashlight are what make them readable.

Static data, not runtime generation:

- Meshes `art/candles/candle_body.tres`, `candle_pool.tres`, `candle_wick.tres`,
  `candle_dish.tres` are unit-size CylinderMeshes (10/10/6/14 radial segments).
  Per-instance size lives in the MultiMesh basis, so one mesh serves every candle.
- Materials `art/candles/wax.tres` (albedo 0.87,0.83,0.72, roughness 0.52) and
  `art/candles/wick.tres` (near-black, roughness 1.0); saucers reuse
  `art/materials/bronze.tres`.
- MultiMesh batches `art/batches/CandleBodies.tres` (279), `CandlePools.tres` (279),
  `CandleWicks.tres` (279) and `CandleDishes.tres` (79) hold static transform buffers
  (12 floats per instance) exactly like the other ArtDetails batches.
- `art/candles.tscn` is a four-child MultiMeshInstance3D scene (WaxBodies, WaxPools,
  Wicks, Dishes) with material overrides. `tomb_corridor.tscn` instances it as the
  single root node `Candles` with unit scale: candles are human-scale props, so they
  must not inherit the 1.5x building scale of ArtDetails.

Placement rules (offline generator, `art/tools/`):

- Perimeter and corner sampling per room footprint; a candidate is kept only when a
  wall face is found within 0.8m along its outward normal, then pushed 0.36m off that
  face. Columns, the coffin platform and rocks are cleared by their world boxes.
- 2-4 candles per cluster on a 0.11-0.17m ring; height 0.20-0.55m skewed to short
  burned-down stubs; radius 0.040-0.058m; tilt up to 5 degrees; about 30% stand on a
  bronze saucer and the rest sit on the tiles. Only segments that resolve to real
  walls receive candles, which is why the tiny 05 shortcut stub stays empty.
- Pipeline: `dump_scene_boxes.py` (parse the saved scene into a world box dump) ->
  `place_candles.py` (choose positions) -> `write_candle_batches.py` (write the four
  .tres batches, `art/candles.tscn`, and the one-line `Candles` hook in the scene;
  idempotent). Intermediate JSON stays under the OS temp directory.

Verification: the scene loads headless without warnings; the 461-assertion scale
audit, side-wing (4619 samples / 44 movement legs), final-wing (3860 samples) and the
original 58 controller checks all still report failures=0. MultiMesh world AABB spans
x -59.8..82.2, z -108.5..2.2, y 0.11..0.54, i.e. the props sit on the real floors.
Visual checks used the real OpenGL renderer (`capture_review.gd`): wide shots in
TEMP/tfu_scale_review_1_5 and close-ups in TEMP/tfu_candle_review.
