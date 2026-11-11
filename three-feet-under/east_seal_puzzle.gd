@tool
extends Node3D

## Room09 east seal (东侧封印): bronze-nail stepping path.
## Walk only the safe tiles (clue carved on the south mural). Wrong step
## fires a glancing dart and returns you to the start. No abyss death.
## Sits under the unscaled tomb_corridor root (EastWing is ×1.5).

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")
const PLATE_CLACK := preload("res://audio/sfx/footstep/footstep_stone_1.ogg")
const STONE_DARK_MAT := preload("res://art/materials/stone_dark.tres")
const BRONZE_MAT := preload("res://art/materials/bronze.tres")

signal tile_stepped(index: int, safe: bool)
signal puzzle_failed
signal puzzle_solved
signal seal_granted

## 3 columns (L=0, C=1, R=2) × 5 rows. Row 0 is south (entrance, +Z), row 4 is north (altar, −Z).
## Safe path: C, C, L, R, C
@export var safe_path: PackedInt32Array = PackedInt32Array([1, 1, 0, 2, 1]):
	set(v):
		safe_path = v
		_request_rebuild()

@export var tile_size := Vector3(1.15, 0.12, 1.15):
	set(v):
		tile_size = v
		_request_rebuild()

@export var spacing := 1.7:
	set(v):
		spacing = maxf(1.3, v)
		_request_rebuild()

@export var press_depth := 0.07
@export var fail_reset_delay := 0.7
@export var interact_distance := 2.2
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var door_path: NodePath = NodePath("../DualSealDoor")
@export var shortcut_path: NodePath = NodePath("../EastShortcutGate")
@export var prompt_hold_seconds := 2.2

var _solved := false
var _failing := false
var _progress := 0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _tiles: Array = []
var _prompt: Label
var _prompt_left := 0.0
var _player: Node3D
var _sfx_step: AudioStreamPlayer3D
var _sfx_fail: AudioStreamPlayer3D
var _sfx_ok: AudioStreamPlayer3D
var _altar_area: Area3D
var _dart: MeshInstance3D
var _dart_t := -1.0
var _dart_from := Vector3.ZERO
var _dart_to := Vector3.ZERO
var _start_mark: Vector3 = Vector3(0, 1.2, 6.2)

const COLS := 3
const ROWS := 5


func _ready() -> void:
	_request_rebuild(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		return
	if what == NOTIFICATION_ENTER_TREE and Engine.is_editor_hint():
		_request_rebuild(true)


func _request_rebuild(from_boot: bool = false) -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	if from_boot or not _boot_done:
		call_deferred("_boot_rebuild_async")
	else:
		call_deferred("_rebuild_async_idle")


func _boot_rebuild_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_rebuild_queued = false
	_boot_done = true
	if not is_inside_tree():
		return
	_rebuild_geometry()
	if not Engine.is_editor_hint():
		_prompt = get_node_or_null(prompt_path) as Label
		_player = get_tree().get_first_node_in_group("player") as Node3D
		print("EastSealPuzzle: ready at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func is_solved() -> bool:
	return _solved


func _tile_pos(col: int, row: int) -> Vector3:
	var x := (float(col) - 1.0) * spacing
	# row 0 south (+Z), row 4 north (−Z)
	var z := (2.0 - float(row)) * spacing
	return Vector3(x, 0.06, z)


func _rebuild_geometry() -> void:
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_solved = false
	_failing = false
	_progress = 0
	_dart_t = -1.0
	_tiles.clear()

	var root := Node3D.new()
	root.name = "Generated"
	_attach(root, gen)

	# South mural clue: 5 rows of 3 nail marks, safe cells raised gold.
	var plaque := Node3D.new()
	plaque.name = "CluePlaque"
	plaque.position = Vector3(-10.15, 1.55, 0)
	plaque.rotation.y = -0.5 * PI
	root.add_child(plaque)
	_mesh_box(plaque, "Back", Vector3(2.4, 1.6, 0.1), Vector3.ZERO, STONE_DARK_MAT)
	for r in ROWS:
		for c in COLS:
			var safe := _is_safe(c, r)
			var mark_mat: Material = BRONZE_MAT if safe else STONE_DARK_MAT
			var pz := (float(r) - 2.0) * 0.22
			var px := (float(c) - 1.0) * 0.42
			var sz := Vector3(0.16, 0.16, 0.08 if safe else 0.04)
			_mesh_box(plaque, "Nail_%d_%d" % [c, r], sz, Vector3(px, 0.45 - pz, 0.08), mark_mat)

	# Path tiles.
	for r in ROWS:
		for c in COLS:
			var body := Node3D.new()
			body.name = "Tile_%d_%d" % [c, r]
			body.position = _tile_pos(c, r)
			root.add_child(body)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.38, 0.35, 0.32)
			mat.roughness = 0.9
			_mesh_box(body, "Slab", tile_size, Vector3.ZERO, mat)
			# Decorative nail on every tile; safe ones sit slightly proud and brighter.
			var safe := _is_safe(c, r)
			# Don't make the answer obvious on the floor — all nails look similar;
			# the mural is the clue. Tiny height difference only.
			_mesh_box(body, "Nail", Vector3(0.12, 0.05, 0.12), Vector3(0, tile_size.y * 0.5 + 0.03, 0), BRONZE_MAT)
			var area := Area3D.new()
			area.name = "StepArea"
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(tile_size.x * 0.92, 0.5, tile_size.z * 0.92)
			col.shape = shape
			col.position = Vector3(0, 0.2, 0)
			area.add_child(col)
			body.add_child(area)
			_tiles.append({
				"col": c,
				"row": r,
				"index": r * COLS + c,
				"safe": safe,
				"body": body,
				"area": area,
				"base_y": body.position.y,
				"pressed": false,
			})

	# North altar.
	var altar_z := _tile_pos(1, ROWS - 1).z - 2.1
	_mesh_box(root, "AltarBase", Vector3(2.6, 0.3, 1.8), Vector3(0, 0.15, altar_z), STONE_DARK_MAT)
	_mesh_box(root, "AltarTop", Vector3(1.8, 0.16, 1.2), Vector3(0, 0.36, altar_z), BRONZE_MAT)
	_mesh_cyl(root, "SealSocket", 0.32, 0.36, 0.22, Vector3(0, 0.52, altar_z), BRONZE_MAT)
	_altar_area = Area3D.new()
	_altar_area.name = "AltarArea"
	_altar_area.position = Vector3(0, 0.7, altar_z)
	var acol := CollisionShape3D.new()
	var ashape := CylinderShape3D.new()
	ashape.radius = 1.1
	ashape.height = 1.4
	acol.shape = ashape
	_altar_area.add_child(acol)
	root.add_child(_altar_area)

	_dart = MeshInstance3D.new()
	_dart.name = "Dart"
	var dart_mesh := BoxMesh.new()
	dart_mesh.size = Vector3(0.08, 0.08, 0.55)
	_dart.mesh = dart_mesh
	_dart.material_override = BRONZE_MAT
	_dart.visible = false
	root.add_child(_dart)

	_sfx_step = AudioStreamPlayer3D.new()
	_sfx_step.stream = PLATE_CLACK
	_sfx_step.unit_size = 8.0
	root.add_child(_sfx_step)
	_sfx_fail = AudioStreamPlayer3D.new()
	_sfx_fail.stream = PLATE_CLACK
	_sfx_fail.pitch_scale = 0.7
	_sfx_fail.unit_size = 10.0
	root.add_child(_sfx_fail)
	_sfx_ok = AudioStreamPlayer3D.new()
	_sfx_ok.stream = STONE_DOOR
	_sfx_ok.unit_size = 12.0
	root.add_child(_sfx_ok)

	_start_mark = Vector3(0, 1.2, _tile_pos(1, 0).z + 2.2)


func _is_safe(col: int, row: int) -> bool:
	if row < 0 or row >= safe_path.size():
		return false
	return int(safe_path[row]) == col


func _clear_generated() -> void:
	_tiles.clear()
	_altar_area = null
	_dart = null
	_sfx_step = null
	_sfx_fail = null
	_sfx_ok = null
	var old := get_node_or_null("Generated")
	if old:
		old.free()


func _attach(node: Node, gen: int) -> void:
	if gen != _build_gen or not is_inside_tree():
		node.free()
		return
	add_child(node)
	if Engine.is_editor_hint():
		node.owner = get_tree().edited_scene_root


func _mesh_box(parent: Node, mesh_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mesh_cyl(parent: Node, mesh_name: String, r_top: float, r_bot: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.radial_segments = 20
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _show_prompt(text: String, hold: bool = false) -> void:
	if _prompt == null:
		return
	_prompt.visible = true
	_prompt.text = text
	if hold:
		_prompt_left = prompt_hold_seconds


func _player_on_tile(tile: Dictionary) -> bool:
	if _player == null:
		return false
	var area: Area3D = tile["area"]
	var offset := _player.global_position - area.global_position
	offset.y = 0.0
	return offset.length() <= maxf(tile_size.x, tile_size.z) * 0.55


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _dart_t >= 0.0 and _dart:
		_dart_t = move_toward(_dart_t, 1.0, delta * 6.0)
		_dart.global_position = _dart_from.lerp(_dart_to, _dart_t)
		_dart.visible = _dart_t < 1.0
		if _dart_t >= 1.0:
			_dart_t = -1.0
			_dart.visible = false
	if _prompt_left > 0.0:
		_prompt_left -= delta
		if _prompt_left <= 0.0 and _prompt and not _altar_near():
			if _prompt.text.contains("印") or _prompt.text.contains("钉") or _prompt.text.contains("E "):
				_prompt.visible = false
	if _solved or _failing:
		return
	if _player == null:
		return
	for tile in _tiles:
		if tile["pressed"]:
			continue
		if _player_on_tile(tile):
			_step_tile(tile)
			break
	if _progress >= ROWS and _altar_near() and not _solved:
		_show_prompt("E 领取东印")


func _altar_near() -> bool:
	if _altar_area == null or _player == null:
		return false
	var offset := _player.global_position - _altar_area.global_position
	offset.y = 0.0
	return offset.length() <= interact_distance


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _solved:
		return
	if _progress < ROWS:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _altar_near():
		_solve()
		get_viewport().set_input_as_handled()


func _step_tile(tile: Dictionary) -> void:
	var row: int = tile["row"]
	var col: int = tile["col"]
	# Must step rows in order; stepping a future/past row is a fail unless it's the expected next.
	if row != _progress:
		_fail(tile)
		return
	if not _is_safe(col, row):
		_fail(tile)
		return
	tile["pressed"] = true
	var body: Node3D = tile["body"]
	body.position.y = float(tile["base_y"]) - press_depth
	_progress += 1
	if _sfx_step:
		_sfx_step.play()
	tile_stepped.emit(int(tile["index"]), true)
	if _progress >= ROWS:
		_show_prompt("沿钉步走到祭坛", true)


func _fail(tile: Dictionary) -> void:
	if _failing or _solved:
		return
	_failing = true
	if _sfx_fail:
		_sfx_fail.play()
	tile_stepped.emit(int(tile["index"]), false)
	puzzle_failed.emit()
	_show_prompt("踏错钉步，退回重走", true)
	if _player:
		_dart_from = _player.global_position + Vector3(3.5, 1.1, 0)
		_dart_to = _player.global_position + Vector3(0, 1.0, 0)
		_dart_t = 0.0
		if _dart:
			_dart.visible = true
	await get_tree().create_timer(fail_reset_delay).timeout
	_reset_path()
	if _player and is_instance_valid(_player):
		_player.global_position = global_transform * _start_mark
		if "velocity" in _player:
			_player.velocity = Vector3.ZERO
	_failing = false


func _reset_path() -> void:
	_progress = 0
	for tile in _tiles:
		tile["pressed"] = false
		var body: Node3D = tile["body"]
		body.position.y = float(tile["base_y"])


func _solve() -> void:
	if _solved:
		return
	_solved = true
	if _sfx_ok:
		_sfx_ok.play()
	_show_prompt("东印已启", true)
	var door := get_node_or_null(door_path)
	if door and door.has_method("unlock_blue_seal"):
		door.unlock_blue_seal()
	var shortcut := get_node_or_null(shortcut_path)
	if shortcut and shortcut.has_method("release_lock"):
		shortcut.release_lock()
	puzzle_solved.emit()
	seal_granted.emit()
	print("EastSealPuzzle: blue seal granted")
