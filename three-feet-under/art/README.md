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


## Decor props: lions, seals, sarcophagus, guards (2026-11-06)

Static dressing added on top of the 1.5x architecture, matching the demo layout
(石狮 at the two seal rooms, 石棺 in the main tomb, 守卫 lining the hall walls):

- `props/decor_details.tscn`: root `DecorDetails`, unit scale, positions authored in
  world meters. It must never inherit the 1.5x building scale, so `tomb_corridor.tscn`
  instances it as one node (`DecorDetails`) next to `Candles`.
- Groups: `StoneLions` (4, scale 1.4), `SealPedestals` (2), `Sarcophagus` (1),
  `HallGuards` (8), `TombLampStands` (4) — 19 placements, 46 de-duplicated meshes,
  241 MeshInstance3D parts, all collision-free, unlit, script-free.
- Materials: `materials/seal_gold.tres` (albedo 0.86,0.63,0.26, metallic 0.75,
  roughness 0.3) and `seal_blue.tres` (0.18,0.46,0.86, metallic 0.55, roughness 0.24)
  give the seals their only bright accent in the dark rooms; everything else reuses
  the existing coffin/trim/bronze presets.
- The old greybox coffin keeps its collision but is hidden (`visible = false`) so the
  new sarcophagus replaces it visually without changing traversal.
- Regenerate with `art/tools/build_decor_details.py` (idempotent; writes the .tscn and
  hooks the node into `tomb_corridor.tscn`). Intermediate box dumps stay in the OS
  temp directory.
- `tests/environment_scale_check.gd` now asserts decor props are *not* environment-
  scaled (prop scale 0.2-3.0, never exactly 1.5) instead of requiring 1.5.
- Visual review: `art/tools/capture_decor_review.gd` renders 06/09 seal rooms, the
  tomb chamber, lion and guard close-ups and the hall axis into TEMP/tfu_decor_review.

## Decor v2: vessels, dings, niches, altars, spear racks (2026-11-06)

Second dressing pass on top of the 1.5x architecture, same pipeline and rules as v1:

- `props/decor_details.tscn` now holds 49 placements / 67 de-duplicated meshes / 406
  MeshInstance3D parts, still under the single unit-scale `DecorDetails` root.
- New groups: `BurialVessels` (13 clay urns, ~0.65 m), `BronzeDings` (4 bronze
  tripods, ~0.42 m), `WallNiches` (10 inset alcoves with figurine + offering bowl),
  `OfferingAltar` (1 clay-and-bronze offering table, west of the sarcophagus),
  `SpearRacks` (2 racks of 2 spears each, south hall wall between guards).
- New material `materials/clay.tres` (albedo 0.62,0.42,0.28, metallic 0.02,
  roughness 0.88) for the urns and altar; dings reuse the bronze preset, niches
  reuse trim/bronze/rock mixes.
- Placement: hall north/south walls get urn rows and inset niches; the tomb chamber
  corners get urns; dings stand between the hall columns; the offering table faces
  the tomb entrance; spear racks flank the hall guards.
- Regenerate with `art/tools/build_decor_details.py` (still idempotent; re-hooks the
  existing `DecorDetails` node, no duplicate).
- `art/tools/capture_decor_review.gd` renders 14 shots at 1920x1080 with 2x MSAA
  (added vessel_row/vessel_close/ding_close/niche_close/niche_tomb/altar_shot/
  rack_close/tomb_vessel) into TEMP/tfu_decor_review.
- Headless check: scale audit now reports 875 assertions / 375 architectural+tablet
  meshes / 413 human-scale decor meshes, failures=0; every DecorDetails mesh (v1 and
  v2 alike) is excluded from the environment-scale assertion and gets a human-scale
  range check instead (0.2-3.0, never exactly 1.5).

## Decor v3: Eastern-Han Chinese style (2026-11-07)

Third pass turns the tomb chamber and great hall toward an Eastern Han feel, same
pipeline and rules; `decor_details.tscn` now holds 93 placements / 103
de-duplicated meshes (v3 adds 44 placements / 36 meshes / 499 parts).

- **Barrel vault ribs (`VaultRibs`)**: five stone rib bands (x=45..69) plus four
  narrower clay-trim infill boards, each following a circular arch (spring 6.2 m,
  rise 1.3 m, apex 7.5 m, half-span 13.5 m) across the 27x27 m tomb chamber. Each
  segment is a pitch-rotated box; pieces carry their own yaw/pitch in the scene
  (new `part_tform()` in the generator).
- **Pictorial relief bands (`WallReliefs`)**: 22 cast-stone bands (6.0 x 1.02 x
  0.10 m, trims + bronze rims, motifs protruding 0.06 m) at ~2.5-3.7 m height on
  the great hall walls (north/south/east/west) and tomb chamber walls, three
  rotating patterns: `procession` (chariot + horse + driver), `cloud` (4 S-curves),
  `guardian` (paired door guards with spears + sun/moon discs).
- **Boshan censers (`BoshanBurners`)**: 2 bronze hill-censer altars (base, stem,
  bowl, layered lid + knob + fins, ~0.84 m), one on the hall column base, one in
  the tomb chamber.
- **Clay figurines (`ClayFigurines`)**: 5 clay tomb figurines (~0.6 m; base,
  skirt, body, head, hat, arms), two on hall column bases, three lining the tomb
  chamber walls.
- **Coin scatter (`CoinScatter`)**: 14 bronze wuzhu-style coins (0.025 m-thick
  discs, 0.11 m radius, lying flat at floor level), scattered near the offering
  altar and tomb chamber west.
- Placement notes: relief bands hug inner wall faces with a 0.02 m standoff
  (yaw 0/90/-90 face inward; yaw 180 places origin 0.07 m inside the wall);
  column-base props sit at y=0.605 (top of the 2.1 m column base).
- `art/tools/capture_decor_review.gd` now renders 21 shots (added tomb_axis,
  vault_look, relief_hall, relief_tomb, boshan_close, figurine_close, coin_close).
- Headless check: scale audit now reports 1374 assertions / 375 architectural
  meshes / 912 human-scale decor meshes, failures=0.

## Decor v3.1: vermilion paint + brick vault (2026-11-07)

Tightening pass on the Chinese style, same generator run (93 placements / 103
meshes unchanged):

- **Brick vault (`art/shaders/world_brick.gdshader` + `art/materials/brick.tres`)**:
  the tomb chamber arch ribs *and* infill boards now use a brick shader — world
  space projection (brick 0.62 x 0.30 m, running-bond offset every other row),
  so brick size and seams stay fixed at 1.5x environment scale just like wall
  stone. Replaces the previous clay-trim infill look; the entire ceiling reads
  as Han brick voussoirs.
- **Vermilion paint (`art/materials/vermilion.tres`)**: meter-scale vermilion
  (朱砂红, albedo 0.62/0.13/0.10) painted onto the pictoral relief motifs —
  chariot cart + driver (procession bands), cloud-tip curls (cloud bands),
  sun disc + spear shafts (guardian bands). 68 painted parts across the 22 bands.
- Generator: `MAT` dict gained `brick` / `vermilion` keys (referenced as
  `m_brick` / `m_vermilion`); vault ribs + infill pass `mat="brick"`.
- Headless check unchanged: scale audit 1374 / 375 / 912, failures=0.

## Decor v4: mingqi + gold ink (2026-11-07)

Fourth decor pass (now 101 placements / 144 meshes, +8 placements / +41 meshes
over v3.1). Two additions:

- **Mingqi 明器** (Eastern Han burial goods) in the previously empty rooms:
  - `Granaries` 陶仓 x2 (#04 room): round-sided grain store, clay body with trim
    girth bands, brick door + vent, roof lid + bronze peak + gold knob (~1.11 m).
  - `Towers` 陶楼 x2 (#08 room): three-eave watchtower, clay floors + trim
    eaves, brick door/window, bronze finial, gold gilt bands under each eave
    (~2.28 m — safely below the 4.65 m hall ceiling).
  - `Wells` 陶井 x1 (#04): clay rim + trim posts/roof + winch (~1.21 m).
  - `Stoves` 陶灶 x3 (#04 / #06 west corner / #09 north corner): clay hearth
    with two cooking holes + bronze pots + chimney + gold front strip (~0.5 m).
- **Gold-ink 描金** accents (`art/materials/gold_ink.tres`, albedo 0.93/0.78/0.30,
  metallic 0.8): applied to the painterly relief bands — wheel hubs + cloud-knot
  dots + guardian hems + a gold rim around the sun disc: 67 gold-ink parts across
  the 22 bands (procession 7x2, cloud 8x4, guardian 7x3) plus granary knob /
  tower gilt bands / stove front strip.
- Generator: three new part lists (`GRANARY`, `TOWER`, `WELL`, `STOVE`), four new
  `GROUPS` entries, `gold_ink` material key, and 8 new `PLACEMENTS` rows (Room04
  x3, Room08 x2, Room06/09 x1 each, all on floor y=0.15).
- Headless checks: scale audit 1524 / 375 / 1062, failures=0; decor v4 structural
  probe (test renamed from `_decor_v4_probe.gd`, removed after passing) fails=0.
- Render: 8 new 1080p shots (`v4_room04/granary/well/stove/room08/tower/
  gold_hall/gold_tomb`) archived in 项目进度刻画图片/10-明器描金-20261107/.

## Decor v5: mingqi round 2 — pigpen, hunping, erbei, door stop (2026-11-07)

- Scene now 163 meshes / 112 placements (v4 144/101). Four new groups:
  - `Pigpens` x2 (Room06 west corner, Room09 west edge): clay pigpen
    ~1.3x1.0m with low walls, trough, and two stacked clay pigs (10 parts each).
  - `Hunpings` x2 (Room04, Room09 NE): five-jar soul jar ~0.6m tall —
    clay jar body + rim + lid + bronze lid knob + 4 mini jars on the shoulder.
  - `Erbeis` x4: vermilion lacquer ear cups with gold rim — 2 on the Room11
    offering altar top (y 0.745) flanking the bronze bowls, 1 on the floor by
    the Room06 seal pedestal, 1 by the Room09 one.
  - `DoorStops` x3: anti-tomb-raider stone bars leaning against walls —
    vertical bar (0.5x2.4x0.34, rock) tilted pitch 25° so the top tips toward
    the wall + trim chock at the foot (part-level pitch support reused from the
    vault ribs). Room11 north wall / Room09 south wall / Room11 west wall.
- Generator: four new part lists (`PIGPEN`, `HUNPING`, `ERBEI`, `STOPPER`), four
  `GROUPS` entries, 11 new `PLACEMENTS` rows. STOPPER's bar demonstrates
  per-part pitch inside the (name, spec) tuple, e.g.
  `("Bar", ("box", (0.5,2.4,0.34), (0,1.2,0), "rock", 0.0, 25.0))`.
- Headless checks: scale audit 1582 / 375 / 1120, failures=0; v5 structural
  probe (58 meshes across the 4 groups, no missing materials, world AABBs sane)
  passes.
- Render: 6 new 1080p shots (`v5_pigpen/hunping/erbei_altar/erbei_floor/
  stopper_tomb/stopper09`) archived in 项目进度刻画图片/11-明器二轮-20261107/.

## Round geometry + aging shaders (2026-11-07)

User feedback: props looked too boxy/"not real". Two programmatic changes (no
external models, no textures), same idempotent generator pipeline:

- **Rounded geometry** (`props/decor_details.tscn`): added 2 CapsuleMesh and 5
  SphereMesh parts for round surfaces that were formerly boxes (figurine head,
  hunping lid knobs, boshan burner tops, vessel lid knobs); cylinder radial
  segments raised from 8-16 to 24 (48 places). Resource mix is now 114 BoxMesh +
  2 CapsuleMesh + 5 SphereMesh + 41 CylinderMesh across 112 placements / 162
  de-duplicated meshes.
- **Aging clay** (`shaders/world_clay.gdshader` + `materials/clay.tres` now a
  ShaderMaterial): world-space mottling (kiln color variance), drying cracks and
  soft bumps via the same derivative-gradient bump technique as world_stone.
  Uniforms: `clay_color`, `dark_color`, `wear=0.6`, `scale_m`.
- **Aging bronze** (`shaders/world_bronze.gdshader` + `materials/bronze.tres`
  now a ShaderMaterial): world-space bronze-green patina mottling, scratches and
  a drier specular (METALLIC falls 0.55 -> 0.15 with rust amount). Uniforms:
  `bronze_color`, `patina_color`, `wear=0.65`, `scale_m`.
- **Rougher candle surfaces**: candle body/dish/pool/wick roughness raised;
  generator segments now 20/20/10/24 in `tools/write_candle_batches.py`.
- Candle 279-count, room layout and all placement rules unchanged.

Review & checks:

- Headless scale audit: 1582 assertions / 375 architectural meshes / 1120
  human-scale decor meshes, failures=0; player_controls 70 checks failures=0.
- `tools/capture_round_review.gd` renders 6 close-ups (pigpen, hunping,
  figurine, boshan, erbei, bronze) at 1920x1080 2xMSAA to the OS temp dir given
  by env var `TFU_ROUND_OUTPUT`. Like rebuild_details it requires a real OpenGL
  window (quit(1) under headless) — use a hidden process / normal window, not
  `--headless`.
- Archived: 6 close-ups + 21 panorama re-renders in
  项目进度刻画图片/12-曲面材质验收-20261107-133459/ (全景- prefix marks the
  re-rendered panoramas, comparable to 07 folder archives), and 9 before/after
  comparison sheets (3 of them same-camera) in 项目进度刻画图片/13-曲面圆润对比-20261107/.

Still coarse: procedural low-poly (visible facets up close), procedural noise
instead of scanned textures, no weathering on the vermilion/gold/stone materials,
no human playtest.

## Wall decoration fit pass (2026-11-07)

Playtest report: several wall decorations read as "a slab sticking out of the
wall". Root causes and fixes, all in `tools/build_decor_details.py` unless noted:

- **Relief bands no longer hover.** The band is a single 6 m panel; it used to be
  placed every 6 m regardless of door openings, so HallS (x=3) hung 2.8 m and
  TombE (x=70.43, z=-101) 2.31 m over corridor gaps. Placement is now a `RELIEF_SPOTS`
  list (28 bands) validated against `WALL_RUNS`: `check_band_fit()` keeps 0.3 m of
  solid wall at both ends and raises `SystemExit` at build time if a band would
  cross an opening.
- **Shallow, inset relief.** Slab is now 5 cm thick, back face -0.03 (buried 3 cm
  in the wall), front face +0.02; bronze rims shrink to 6 cm; motifs are scaled to
  4.5 cm thick at `z = 0.015 + 0.3 * old_z`. Total protrusion dropped from ~20 cm
  to 9.7 cm. The sun/moon discs used to be cylinders lying flat (axis on Y, radius
  0.30) poking 30 cm through the wall; they are now thin discs pitched 90 degrees
  flat against the face.
- **Niches sit on the wall.** Frame depth 16 -> 8 cm, back plate 3 cm flush,
  origin on the wall face (total 11 cm). `NicheTmbE`/`NicheTmbW` yaw were wrong
  (one faced into the wall, one whole niche was buried).
- **Door headers fill the void above doors.** Doorways are full-height openings
  while corridors stop at 4.65 m and halls at 7.65 m, so from inside a hall you
  looked straight into a black void above each door. Six headers
  (`doorhead_*`, y 4.60-7.65, 0.38 thick, `wall` material) plus a `trim`+`bronze`
  lintel now close them; generated from `DOOR_GAPS`.
- **Door stop moved out of the doorway**: `Stopper11W` (44.3, -87.5), and the
  cold-grey `rock` material replaced by warm `materials/stone_dark.tres` for both
  the stop bar and niche backs (it read as blue metal under torch light).
- **New material `materials/relief.tres`**: world_stone with `stone_color`
  (0.44, 0.41, 0.36), 4.0x1.4 m blocks and 4 mm joints — a dressed panel one step
  lighter than the wall, without the small-brick pattern that moired at distance.
- **Shader AA** (`shaders/world_stone.gdshader`): high-frequency grain is faded by
  `fwidth` before it feeds the bump, and block seams fade out when a cell covers
  under ~1 px (`cell_px` 0.28-1.1). Both removed a regular diagonal stripe artifact
  on grazing/thin surfaces.
- **Shadow acne**: the player torch `shadow_bias` went 0.1 -> 0.4 in
  `tomb_corridor.tscn` and `main.tscn`; stripes on thin wall-mounted panels are
  gone, shadows are still cast.

Checks:

- New `tests/decor_wall_fit_check.gd` loads `tomb_corridor.tscn`, treats 2-9 m
  tall BoxMeshes as walls (183), takes the subtree AABB of every `ReliefBand*` /
  `Niche*` (38 targets), samples 25x3 points per side 0.012 m off the face and
  requires >= 0.995 wall coverage with protrusion <= 0.15 m. Latest:
  `DECOR FIT: targets=38 walls=183 unsupported=0 oversized=0`.
- Headless scale audit: 1718 assertions / 375 architectural meshes / 1256
  human-scale decor meshes, failures=0; player_controls 70 checks failures=0.
- `tools/capture_wall_fix.gd` (env `TFU_WALLFIX_OUTPUT`, real OpenGL window only)
  renders 8 shots: hall south/north door, hall south wall, tomb east/west door,
  niche close-up, band close-up, door stop. Archived in
  项目进度刻画图片/14-墙面装饰贴合修复-20261107/.

## Eastern Han lacquered coffin (2026-11-10)

- User installed Blender 5.2.3 LTS; style locked to **Eastern Han (a.d. 25–220)**
  per user, referencing 盗墓笔记; see [STYLE_ANCHOR.md](STYLE_ANCHOR.md) — the
  permanent art anchor card (brick-chamber tomb + pictogram bricks, oil-lamp-only
  lighting, low-sat earth palette, PBR specs, forbidden list, build order,
  dispatch workflow).
- `tools/build_coffin_han.py` (Blender 4+ is **Z-up**: height along Z)
  procedurally builds the coffin and joins one mesh `Coffin_Han`: stone plinth
  4.7x2.2x0.20, trapezoid casket body (head wider/taller than foot: HEAD_W 1.82 /
  FOOT_W 1.56, HEAD_H 0.92 / FOOT_H 0.78, bevel 0.10/5seg), two vermilion
  lacquer bands (0.012 thick), arched (barrel) lid = cylinder half (48 seg,
  bisected z>0, scaled LEN/RISE 0.42). Materials: BLACK_LACQ
  (0.030,0.024,0.024 rough0.30 clearcoat0.8) / VERMILION (0.72,0.16,0.10) /
  STONE (0.24,0.20,0.16). Exported `models/coffin_heavy.glb` (dims 4.6x1.49x2.02,
  origin at geometric center z=0.747).
- Generator `build_decor_details.py` gained a `"glb"` part kind: emits a plain
  instanced node from an ExtResource; emission and reference must share one hash
  id. `Sarcophagus11` (57, 0.75, -91.5) yaw 90 now instantiates the coffin.
- `tools/capture_coffin.gd` (env `TFU_COFFIN_OUTPUT`, real window) renders 4
  shots (front/three-qtr/head/side). Comparison vs old boxy stone coffin
  archived in 项目进度刻画图片/15-中式髹漆木棺-20261110/.
- Checks: player_controls 70/0; environment_scale 1708 assertions failures=3
  (pre-existing, same on committed 1718 version).

## Eastern Han strip brick wall pilot (2026-11-11) — dispatch 01

Style-anchor dispatch 01: give ONE corridor wall a real Han brick material,
without touching structure or any other decoration.

- `shaders/world_hanbrick.gdshader`: world-space procedural Han strip brick
  (东汉条砖). Long face ~4:1 (`brick_size` vec2(0.44, 0.11)), running bond
  (every other row off by half a brick). Per-brick tone random between the
  anchor palette 夯土黄 #8A6D4F and 砖灰 #6E6259 via per-cell hash. Mortar
  joints carry accumulated dirt (groove darkened, in-joint grime noise), and
  ~18% of bricks (per-cell `spall_chance`) have an eroded patch exposing the
  earthen core (lighter `core_color` + recessed relief). Same world-space
  planar projection and surface-gradient bump as world_brick/world_stone, so
  brick size stays meter-accurate at 1.5x environment scale and there is no
  tiling repetition. PBR: rough 0.92+, specular 0.1, no plastic sheen.
- `materials/han_brick.tres`: ShaderMaterial instance bound to the palette
  (brick_a 0.541/0.427/0.31, brick_b 0.431/0.384/0.349, mortar dark, core
  0.6/0.5/0.35).
- `tomb_corridor.tscn`: only `LeftWall` (main-corridor left wall,
  mesh 0.3x3x17.5 @ x=-2.475, z=-4.875) overrides to `han_brick.tres`;
  nothing else changed.
- `tools/capture_brick_wall.gd` (env `TFU_BRICK_OUTPUT`, real OpenGL window):
  two shots standing in the corridor at eye level facing the wall
  (`brick_face` straight-on, `brick_angle` oblique). Archived
  项目进度刻画图片/16-墓道砖墙试点-20261111/.
- Checks: player_controls 70/0; environment_scale 1708 assertions failures=3
  (pre-existing, same as coffin round).
