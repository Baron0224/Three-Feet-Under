@tool
extends Node3D

## Room04 west-wing pressure-plate puzzle (压板机关).
## Four floor plates in a 2×2 grid; correct clockwise sequence raises the
## north stone gate into Corridor05. Soft fail only — plates reset, no death.
## Must sit under an unscaled tomb_corridor root (WestWing is ×1.5).

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")
const PLATE_CLACK := preload("res://audio/sfx/footstep/footstep_stone_1.ogg")
const BRICK_MAT := preload("res://art/materials/brick.tres")
const STONE_DARK_MAT := preload("res://art/materials/stone_dark.tres")
const BRONZE_MAT := preload("res://art/materials/bronze.tres")

signal plate_pressed(index: int)
signal puzzle_failed
signal puzzle_solved
signal gate_opened

## Plate indices: 0=NW, 1=NE, 2=SE, 3=SW (north = local −Z).
@export var correct_sequence: PackedInt32Array = PackedInt32Array([0, 1, 2, 3]):
	set(v):
		correct_sequence = v

@export var plate_spacing := 2.1:
	set(v):
		plate_spacing = maxf(1.4, v)
		_request_rebuild()

@export var plate_size := Vector3(1.15, 0.12, 1.15):
	set(v):
		plate_size = v
		_request_rebuild()

@export var press_depth := 0.07
@export var fail_reset_delay := 0.55
@export var prompt_hold_seconds := 1.6

@export var gate_local_offset := Vector3(0.8, 0.0, -5.45):
	set(v):
		gate_local_offset = v
		_request_rebuild()

@export var opening_width := 4.0:
	set(v):
		opening_width = maxf(2.0, v)
		_request_rebuild()

@export var opening_height := 3.8:
	set(v):
		opening_height = maxf(2.0, v)
		_request_rebuild()

@export var slab_thickness := 0.32:
	set(v):
		slab_thickness = maxf(0.12, v)
		_request_rebuild()

@export var rise_distance := 4.0
@export var rise_speed := 1.55
@export var use_brick := true
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var show_clue_carving := true:
	set(v):
		show_clue_carving = v
		_request_rebuild()

var _solved := false
var _opening := false
var _failing := false
var _progress := 0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _plates: Array = []  # Dictionary per plate
var _slab: Node3D
var _slab_body: StaticBody3D
var _slab_start_y := 0.0
var _prompt: Label
var _prompt_left := 0.0
var _sfx_clack: AudioStreamPlayer3D
var _sfx_gate: AudioStreamPlayer3D
var _sfx_fail: AudioStreamPlayer3D

var _stone: Material
var _stone_dark: Material
var _bronze: Material
var _bronze_lit: StandardMaterial3D
var _plate_idle: StandardMaterial3D
var _plate_pressed_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D


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
		_prompt = _resolve_prompt()
		_setup_audio()
		_reset_runtime_state(false)
		print(
			"PressurePlatePuzzle: ready at ", global_position,
			" gate@", gate_local_offset, " seq=", correct_sequence
		)
	else:
		print("PressurePlatePuzzle: editor preview at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func _resolve_prompt() -> Label:
	if prompt_path:
		var n := get_node_or_null(prompt_path)
		if n is Label:
			return n
	var scene := get_tree().current_scene
	if scene:
		var label := scene.get_node_or_null("HUD/InteractPrompt")
		if label is Label:
			return label
	return null


func _setup_audio() -> void:
	_sfx_clack = AudioStreamPlayer3D.new()
	_sfx_clack.name = "SfxClack"
	_sfx_clack.stream = PLATE_CLACK
	_sfx_clack.volume_db = -6.0
	_sfx_clack.pitch_scale = 0.85
	_sfx_clack.max_distance = 18.0
	add_child(_sfx_clack)

	_sfx_fail = AudioStreamPlayer3D.new()
	_sfx_fail.name = "SfxFail"
	_sfx_fail.stream = PLATE_CLACK
	_sfx_fail.volume_db = -3.0
	_sfx_fail.pitch_scale = 0.45
	_sfx_fail.max_distance = 18.0
	add_child(_sfx_fail)

	_sfx_gate = AudioStreamPlayer3D.new()
	_sfx_gate.name = "SfxGate"
	_sfx_gate.stream = STONE_DOOR
	_sfx_gate.volume_db = -2.0
	_sfx_gate.pitch_scale = 0.7
	_sfx_gate.max_distance = 28.0
	add_child(_sfx_gate)


func is_solved() -> bool:
	return _solved


func open_gate() -> void:
	# Allow calling after _solve() already flipped _solved; only block re-entry while rising/done.
	if _opening:
		return
	if _slab and _slab_body and _slab_body.collision_layer == 0:
		return
	_solved = true
	_opening = true
	_slab_start_y = _slab.position.y if _slab else opening_height * 0.5
	if _sfx_gate:
		_sfx_gate.play()
	puzzle_solved.emit()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _prompt_left > 0.0:
		_prompt_left = maxf(0.0, _prompt_left - delta)
		if _prompt_left <= 0.0 and _prompt and not _solved:
			# Only clear our own soft prompts.
			if _prompt.text.begins_with("石") or _prompt.text.begins_with("机关"):
				_prompt.visible = false

	if _opening and _slab:
		var target_y := _slab_start_y + rise_distance
		_slab.position.y = move_toward(_slab.position.y, target_y, rise_speed * delta)
		if is_equal_approx(_slab.position.y, target_y):
			_opening = false
			if _slab_body:
				_slab_body.collision_layer = 0
				_slab_body.collision_mask = 0
			gate_opened.emit()
			_flash_prompt("石门缓缓升起", 2.2)
			print("PressurePlatePuzzle: gate opened")


func _flash_prompt(text: String, hold: float = -1.0) -> void:
	if _prompt == null:
		return
	_prompt.visible = true
	_prompt.text = text
	_prompt_left = prompt_hold_seconds if hold < 0.0 else hold


func _reset_runtime_state(play_sound: bool) -> void:
	_progress = 0
	_failing = false
	for p in _plates:
		_set_plate_down(p, false)
		p["occupied"] = false
	if play_sound and _sfx_fail:
		_sfx_fail.play()


func _plate_local(index: int) -> Vector3:
	# 0 NW, 1 NE, 2 SE, 3 SW — north is −Z.
	var half := plate_spacing * 0.5
	match index:
		0:
			return Vector3(-half, 0.0, -half)
		1:
			return Vector3(half, 0.0, -half)
		2:
			return Vector3(half, 0.0, half)
		_:
			return Vector3(-half, 0.0, half)


func _on_plate_entered(index: int, body: Node) -> void:
	if Engine.is_editor_hint() or _solved or _failing or _opening:
		return
	if body == null or not body.is_in_group("player"):
		return
	if index < 0 or index >= _plates.size():
		return
	var p: Dictionary = _plates[index]
	p["occupied"] = true
	if p["down"]:
		return
	_try_press(index)


func _on_plate_exited(index: int, body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if index < 0 or index >= _plates.size():
		return
	_plates[index]["occupied"] = false


func _try_press(index: int) -> void:
	if _progress < 0 or _progress >= correct_sequence.size():
		return
	var expected: int = int(correct_sequence[_progress])
	plate_pressed.emit(index)
	if index == expected:
		_set_plate_down(_plates[index], true)
		_progress += 1
		if _sfx_clack:
			_sfx_clack.pitch_scale = 0.8 + 0.08 * float(_progress)
			_sfx_clack.play()
		if _progress == 1:
			_flash_prompt("石板沉下……", 1.2)
		if _progress >= correct_sequence.size():
			_solve()
		return
	# Wrong plate — soft fail.
	_set_plate_down(_plates[index], true)
	if _sfx_fail:
		_sfx_fail.play()
	_flash_prompt("机关咔然复位", 1.4)
	_failing = true
	puzzle_failed.emit()
	get_tree().create_timer(fail_reset_delay).timeout.connect(_on_fail_timeout)


func _on_fail_timeout() -> void:
	if _solved:
		return
	_reset_runtime_state(false)
	# If player still stands on a plate after reset, re-evaluate that plate.
	for i in range(_plates.size()):
		if _plates[i]["occupied"]:
			_try_press(i)
			break


func _solve() -> void:
	_solved = true
	_flash_prompt("四石齐鸣——北门松动", 2.0)
	open_gate()


func _set_plate_down(p: Dictionary, down: bool) -> void:
	p["down"] = down
	var root: Node3D = p["root"]
	var mesh: MeshInstance3D = p["mesh"]
	var base_y: float = p["base_y"]
	root.position.y = base_y - (press_depth if down else 0.0)
	if mesh:
		mesh.material_override = _plate_pressed_mat if down else _plate_idle


func _make_materials() -> void:
	if use_brick:
		_stone = BRICK_MAT
		_stone_dark = STONE_DARK_MAT
	else:
		_stone = StandardMaterial3D.new()
		_stone.albedo_color = Color(0.34, 0.31, 0.28)
		_stone.roughness = 0.92
		_stone_dark = StandardMaterial3D.new()
		_stone_dark.albedo_color = Color(0.18, 0.17, 0.16)
		_stone_dark.roughness = 0.95

	_bronze = BRONZE_MAT

	_bronze_lit = StandardMaterial3D.new()
	_bronze_lit.albedo_color = Color(0.55, 0.38, 0.16)
	_bronze_lit.metallic = 0.7
	_bronze_lit.roughness = 0.4
	_bronze_lit.emission_enabled = true
	_bronze_lit.emission = Color(0.45, 0.28, 0.08)
	_bronze_lit.emission_energy_multiplier = 0.55

	_plate_idle = StandardMaterial3D.new()
	_plate_idle.albedo_color = Color(0.42, 0.38, 0.33)
	_plate_idle.roughness = 0.88
	_plate_idle.metallic = 0.04

	_plate_pressed_mat = StandardMaterial3D.new()
	_plate_pressed_mat.albedo_color = Color(0.28, 0.25, 0.21)
	_plate_pressed_mat.roughness = 0.94

	_mark_mat = StandardMaterial3D.new()
	_mark_mat.albedo_color = Color(0.22, 0.18, 0.12)
	_mark_mat.roughness = 0.85
	_mark_mat.metallic = 0.25


func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Gen_") or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_plates.clear()
	_slab = null
	_slab_body = null


func _rebuild_geometry() -> void:
	if not is_inside_tree():
		return
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_make_materials()
	_build_plates(gen)
	_build_floor_marks(gen)
	_build_gate(gen)
	if show_clue_carving:
		_build_clue_carving(gen)


func _attach(node: Node, gen: int) -> void:
	call_deferred("_attach_now", node, gen)


func _attach_now(node: Node, gen: int) -> void:
	if gen != _build_gen:
		if is_instance_valid(node):
			node.free()
		return
	if not is_inside_tree() or not is_instance_valid(node):
		return
	if node.get_parent() == self:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	add_child.call_deferred(node)


func _mesh_box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _configure_area(area: Area3D) -> void:
	area.collision_layer = 0
	area.collision_mask = 1
	# Enabled deferred after signals connect (avoids busy-parent enter events).
	area.monitoring = false
	area.monitorable = false


func _build_plates(gen: int) -> void:
	var root := Node3D.new()
	root.name = "Gen_Plates"
	for i in range(4):
		var plate := Node3D.new()
		plate.name = "Plate%d" % i
		var loc := _plate_local(i)
		plate.position = loc
		# Slightly proud of floor so the tile reads as a raised slab.
		var base_y := plate_size.y * 0.5 + 0.02
		plate.position.y = base_y

		var mesh := _mesh_box(plate, "Mesh", plate_size, Vector3.ZERO, _plate_idle)
		# Recessed rim.
		_mesh_box(
			plate, "Rim",
			Vector3(plate_size.x + 0.08, plate_size.y * 0.45, plate_size.z + 0.08),
			Vector3(0.0, -plate_size.y * 0.15, 0.0),
			_stone_dark
		)
		# Corner stud index mark (visual only; order taught by wall clue).
		var stud_mat := _bronze_lit if i == 0 else _bronze
		_mesh_box(plate, "Stud", Vector3(0.12, 0.04, 0.12), Vector3(0.0, plate_size.y * 0.55, 0.0), stud_mat)

		var area := Area3D.new()
		area.name = "Area"
		_configure_area(area)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(plate_size.x * 0.92, 0.55, plate_size.z * 0.92)
		cs.shape = shape
		cs.position = Vector3(0.0, 0.28, 0.0)
		area.add_child(cs)
		plate.add_child(area)

		root.add_child(plate)
		var entry := {
			"root": plate,
			"mesh": mesh,
			"area": area,
			"base_y": base_y,
			"down": false,
			"occupied": false,
			"index": i,
		}
		_plates.append(entry)

	_attach(root, gen)
	# Connect signals after attach settles.
	call_deferred("_connect_plate_signals", gen)


func _connect_plate_signals(gen: int) -> void:
	if gen != _build_gen or Engine.is_editor_hint():
		return
	for p in _plates:
		var area: Area3D = p["area"]
		var idx: int = int(p["index"])
		# Fresh rebuild always gets fresh Area3D nodes; connect once.
		area.body_entered.connect(_make_enter_cb(idx))
		area.body_exited.connect(_make_exit_cb(idx))
		area.set_deferred("monitoring", true)


func _make_enter_cb(index: int) -> Callable:
	return func(body: Node) -> void:
		_on_plate_entered(index, body)


func _make_exit_cb(index: int) -> Callable:
	return func(body: Node) -> void:
		_on_plate_exited(index, body)


func _build_floor_marks(gen: int) -> void:
	# Subtle dark chevrons / path strips teaching clockwise order NW→NE→SE→SW.
	var marks := Node3D.new()
	marks.name = "Gen_FloorMarks"
	var half := plate_spacing * 0.5
	var y := 0.045
	# Path segments between plate centers.
	var path := [
		[Vector3(-half, y, -half), Vector3(half, y, -half)],   # NW→NE
		[Vector3(half, y, -half), Vector3(half, y, half)],     # NE→SE
		[Vector3(half, y, half), Vector3(-half, y, half)],     # SE→SW
	]
	for i in range(path.size()):
		var a: Vector3 = path[i][0]
		var b: Vector3 = path[i][1]
		var mid := (a + b) * 0.5
		var delta := b - a
		var length := delta.length()
		var seg := _mesh_box(
			marks, "Path%d" % i,
			Vector3(maxf(length - 0.95, 0.35), 0.03, 0.08),
			mid,
			_mark_mat
		)
		if absf(delta.x) > absf(delta.z):
			seg.rotation_degrees.y = 0.0
		else:
			seg.rotation_degrees.y = 90.0
		# Small arrow head near end.
		var tip := b.lerp(a, 0.22)
		var arrow := _mesh_box(
			marks, "Arrow%d" % i,
			Vector3(0.18, 0.035, 0.18),
			tip,
			_bronze_lit
		)
		arrow.rotation_degrees.y = 45.0
	# Center brass nail — start hint.
	_mesh_box(marks, "CenterNail", Vector3(0.16, 0.04, 0.16), Vector3(0.0, y, 0.0), _bronze_lit)
	_attach(marks, gen)


func _build_gate(gen: int) -> void:
	var gate := Node3D.new()
	gate.name = "Gen_Gate"
	gate.position = gate_local_offset

	# Frame jambs + lintel (carved stone look).
	_mesh_box(
		gate, "JambL",
		Vector3(0.4, opening_height + 0.4, 0.55),
		Vector3(-(opening_width * 0.5 + 0.22), opening_height * 0.5, 0.0),
		_stone_dark
	)
	_mesh_box(
		gate, "JambR",
		Vector3(0.4, opening_height + 0.4, 0.55),
		Vector3(opening_width * 0.5 + 0.22, opening_height * 0.5, 0.0),
		_stone_dark
	)
	_mesh_box(
		gate, "Lintel",
		Vector3(opening_width + 1.0, 0.45, 0.6),
		Vector3(0.0, opening_height + 0.12, 0.0),
		_stone
	)
	_mesh_box(
		gate, "Threshold",
		Vector3(opening_width + 0.6, 0.16, 0.55),
		Vector3(0.0, 0.08, 0.02),
		_stone_dark
	)

	var slab := Node3D.new()
	slab.name = "Slab"
	slab.position = Vector3(0.0, opening_height * 0.5, 0.0)
	var slab_size := Vector3(opening_width * 0.96, opening_height * 0.98, slab_thickness)
	_mesh_box(slab, "SlabBody", slab_size, Vector3.ZERO, _stone)
	# Weather cracks.
	_mesh_box(slab, "CrackV", Vector3(0.04, opening_height * 0.65, slab_thickness * 1.05), Vector3(-0.4, 0.1, 0.0), _stone_dark)
	_mesh_box(slab, "CrackH", Vector3(opening_width * 0.5, 0.04, slab_thickness * 1.05), Vector3(0.25, -0.35, 0.0), _stone_dark)

	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = slab_size
	cs.shape = shape
	body.add_child(cs)
	slab.add_child(body)

	gate.add_child(slab)
	_slab = slab
	_slab_body = body
	_slab_start_y = slab.position.y
	_attach(gate, gen)


func _build_clue_carving(gen: int) -> void:
	# Small stone plaque on the south face of the gate lintel area — four studs
	# with a clockwise groove (甲→乙→丙→丁) so players can read the order.
	var clue := Node3D.new()
	clue.name = "Gen_ClueCarving"
	clue.position = gate_local_offset + Vector3(0.0, opening_height * 0.55, 0.38)

	_mesh_box(clue, "Plaque", Vector3(1.35, 0.85, 0.1), Vector3.ZERO, _stone_dark)
	_mesh_box(clue, "PlaqueRim", Vector3(1.45, 0.95, 0.06), Vector3(0.0, 0.0, -0.02), _stone)

	var stud_pts := [
		Vector3(-0.35, 0.18, 0.07),  # NW / 甲
		Vector3(0.35, 0.18, 0.07),   # NE / 乙
		Vector3(0.35, -0.18, 0.07),  # SE / 丙
		Vector3(-0.35, -0.18, 0.07), # SW / 丁
	]
	for i in range(4):
		var mat := _bronze_lit if i == 0 else _bronze
		_mesh_box(clue, "Stud%d" % i, Vector3(0.14, 0.14, 0.06), stud_pts[i], mat)
		# Tiny ordinal nub (size grows with index for non-text cue).
		var nub_s := 0.04 + 0.015 * float(i)
		_mesh_box(clue, "Nub%d" % i, Vector3(nub_s, nub_s, 0.05), stud_pts[i] + Vector3(0.0, 0.0, 0.04), _bronze_lit)

	# Groove segments (clockwise).
	_mesh_box(clue, "Groove0", Vector3(0.55, 0.04, 0.035), Vector3(0.0, 0.18, 0.06), _mark_mat)
	_mesh_box(clue, "Groove1", Vector3(0.04, 0.28, 0.035), Vector3(0.35, 0.0, 0.06), _mark_mat)
	_mesh_box(clue, "Groove2", Vector3(0.55, 0.04, 0.035), Vector3(0.0, -0.18, 0.06), _mark_mat)

	_attach(clue, gen)
