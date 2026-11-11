@tool
extends Node3D

## Room06 west seal (西侧封印): rotate the four-beast stone disk until
## 青龙 faces east, matching the wall murals. Soft puzzle, no death.
## Sits under the unscaled tomb_corridor root (WestWing is ×1.5).

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")
const PLATE_CLACK := preload("res://audio/sfx/footstep/footstep_stone_1.ogg")
const STONE_DARK_MAT := preload("res://art/materials/stone_dark.tres")
const BRONZE_MAT := preload("res://art/materials/bronze.tres")

signal disk_rotated(steps: int)
signal puzzle_solved
signal seal_granted

## Disk step 0 = 青龙 faces local +X (east). Each E press adds 1 (90° CW).
@export var start_step := 2
@export var correct_step := 0
@export var interact_distance := 2.4
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var door_path: NodePath = NodePath("../DualSealDoor")
@export var shortcut_path: NodePath = NodePath("../TorchLeverWallWestShortcut")
@export var prompt_hold_seconds := 2.2

var _solved := false
var _step := 0
var _spinning := false
var _spin_t := 0.0
var _from_yaw := 0.0
var _to_yaw := 0.0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _disk: Node3D
var _disk_area: Area3D
var _prompt: Label
var _prompt_left := 0.0
var _player: Node3D
var _sfx_turn: AudioStreamPlayer3D
var _sfx_ok: AudioStreamPlayer3D
var _gold_emit: StandardMaterial3D

const BEASTS := [
	{ "name": "青龙", "color": Color(0.25, 0.62, 0.48) },
	{ "name": "朱雀", "color": Color(0.72, 0.28, 0.22) },
	{ "name": "白虎", "color": Color(0.86, 0.82, 0.70) },
	{ "name": "玄武", "color": Color(0.22, 0.28, 0.48) },
]


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
		print("WestSealPuzzle: ready at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func is_solved() -> bool:
	return _solved


func _rebuild_geometry() -> void:
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_step = start_step % 4
	_solved = false
	_spinning = false

	_gold_emit = StandardMaterial3D.new()
	_gold_emit.albedo_color = Color(0.95, 0.72, 0.18)
	_gold_emit.emission_enabled = true
	_gold_emit.emission = Color(0.95, 0.72, 0.18)
	_gold_emit.emission_energy_multiplier = 0.7
	_gold_emit.metallic = 0.55
	_gold_emit.roughness = 0.4

	var root := Node3D.new()
	root.name = "Generated"
	_attach(root, gen)

	_mesh_box(root, "AltarBase", Vector3(3.2, 0.28, 3.2), Vector3(0, 0.14, 0), STONE_DARK_MAT)
	_mesh_box(root, "AltarRing", Vector3(2.5, 0.12, 2.5), Vector3(0, 0.32, 0), BRONZE_MAT)

	_disk = Node3D.new()
	_disk.name = "SealDisk"
	_disk.position = Vector3(0, 0.46, 0)
	_disk.rotation.y = _step_yaw(_step)
	root.add_child(_disk)

	_mesh_cyl(_disk, "DiskBody", 1.15, 1.15, 0.16, Vector3(0, 0, 0), STONE_DARK_MAT)
	_mesh_cyl(_disk, "DiskRim", 1.22, 1.22, 0.06, Vector3(0, 0.08, 0), BRONZE_MAT)
	# Pointer on the disk marks 青龙 (index 0) facing +X at step 0.
	_mesh_box(_disk, "Pointer", Vector3(0.85, 0.08, 0.16), Vector3(0.55, 0.12, 0), _gold_emit)

	for i in 4:
		var beast: Dictionary = BEASTS[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = beast["color"]
		mat.roughness = 0.55
		# Around the disk: 0=+X 青龙, 1=-Z 朱雀 (south), 2=-X 白虎, 3=+Z 玄武 (north is -Z in tomb, but
		# mural "south" is +Z). Place plaques in local disk space at 90° * i from +X.
		var ang := float(i) * 0.5 * PI
		var pos := Vector3(cos(ang) * 0.85, 0.14, -sin(ang) * 0.85)
		_mesh_box(_disk, "Beast_%d" % i, Vector3(0.34, 0.12, 0.28), pos, mat)

	_disk_area = Area3D.new()
	_disk_area.name = "DiskArea"
	_disk_area.position = Vector3(0, 0.7, 0)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 1.4
	col.shape = shape
	_disk_area.add_child(col)
	root.add_child(_disk_area)

	# Wall murals: east 青龙, south 朱雀, west 白虎, north 玄武. Inset from 21×15 m room.
	_add_mural(root, "MuralEast", Vector3(9.2, 1.7, 0), Vector3(0.08, 1.6, 1.8), BEASTS[0]["color"], 0.5 * PI)
	_add_mural(root, "MuralSouth", Vector3(3.6, 1.7, 6.4), Vector3(1.8, 1.6, 0.08), BEASTS[1]["color"], 0.0)
	_add_mural(root, "MuralWest", Vector3(-9.2, 1.7, -3.6), Vector3(0.08, 1.6, 1.8), BEASTS[2]["color"], -0.5 * PI)
	_add_mural(root, "MuralNorth", Vector3(0, 1.7, -6.4), Vector3(1.8, 1.6, 0.08), BEASTS[3]["color"], PI)

	_sfx_turn = AudioStreamPlayer3D.new()
	_sfx_turn.name = "SfxTurn"
	_sfx_turn.stream = PLATE_CLACK
	_sfx_turn.unit_size = 8.0
	root.add_child(_sfx_turn)
	_sfx_ok = AudioStreamPlayer3D.new()
	_sfx_ok.name = "SfxOk"
	_sfx_ok.stream = STONE_DOOR
	_sfx_ok.unit_size = 12.0
	root.add_child(_sfx_ok)


func _add_mural(parent: Node3D, mural_name: String, pos: Vector3, size: Vector3, color: Color, _yaw: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	_mesh_box(parent, mural_name + "Slab", size, pos, STONE_DARK_MAT)
	var inner := size * Vector3(0.55, 0.55, 0.55)
	if size.x < size.z:
		inner.x = minf(size.x * 0.4, 0.05)
	else:
		inner.z = minf(size.z * 0.4, 0.05)
	_mesh_box(parent, mural_name + "Mark", inner, pos + Vector3(0, 0, 0), mat)


func _step_yaw(step: int) -> float:
	return -float(step % 4) * 0.5 * PI


func _clear_generated() -> void:
	_disk = null
	_disk_area = null
	_sfx_turn = null
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
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _disk_near() -> bool:
	if _disk_area == null or _player == null:
		return false
	var offset := _player.global_position - _disk_area.global_position
	offset.y = 0.0
	return offset.length() <= interact_distance


func _show_prompt(text: String, hold: bool = false) -> void:
	if _prompt == null:
		return
	_prompt.visible = true
	_prompt.text = text
	if hold:
		_prompt_left = prompt_hold_seconds


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _spinning and _disk:
		_spin_t = move_toward(_spin_t, 1.0, delta * 2.4)
		_disk.rotation.y = lerp_angle(_from_yaw, _to_yaw, _spin_t)
		if _spin_t >= 1.0:
			_spinning = false
			_disk.rotation.y = _to_yaw
			if _step == correct_step:
				_solve()
	if _prompt_left > 0.0:
		_prompt_left -= delta
		if _prompt_left <= 0.0 and _prompt and not (_disk_near() and not _solved):
			if _prompt.text.begins_with("E ") or _prompt.text.contains("西印") or _prompt.text.contains("石盘"):
				_prompt.visible = false
		return
	if _solved:
		return
	if _prompt == null or _player == null:
		return
	if not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if _disk_near():
		_show_prompt("E 转动石盘")
	elif _prompt.text.begins_with("E ") and "石盘" in _prompt.text:
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _solved or _spinning:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if not _disk_near():
		return
	_rotate_disk()
	get_viewport().set_input_as_handled()


func _rotate_disk() -> void:
	_from_yaw = _step_yaw(_step)
	_step = (_step + 1) % 4
	_to_yaw = _step_yaw(_step)
	_spin_t = 0.0
	_spinning = true
	if _sfx_turn:
		_sfx_turn.play()
	disk_rotated.emit(_step)


func _solve() -> void:
	if _solved:
		return
	_solved = true
	if _sfx_ok:
		_sfx_ok.play()
	_show_prompt("西印已启", true)
	var door := get_node_or_null(door_path)
	if door and door.has_method("unlock_yellow_seal"):
		door.unlock_yellow_seal()
	var shortcut := get_node_or_null(shortcut_path)
	if shortcut and shortcut.has_method("release_lock"):
		shortcut.release_lock()
	puzzle_solved.emit()
	seal_granted.emit()
	print("WestSealPuzzle: yellow seal granted")
