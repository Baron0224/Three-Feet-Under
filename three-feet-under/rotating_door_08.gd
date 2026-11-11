@tool
extends Node3D

## Room08 rotating mechanism (转门机关).
## West entrance stays open (from the bridge). A central disk has three
## settings: 北 opens the north gate to 09, 南 opens the south gate to the
## east shortcut, 封 closes both. E rotates the disk. Soft puzzle, no death.
## Sits under the unscaled tomb_corridor root (EastWing is ×1.5).

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")
const PLATE_CLACK := preload("res://audio/sfx/footstep/footstep_stone_1.ogg")
const STONE_DARK_MAT := preload("res://art/materials/stone_dark.tres")
const BRONZE_MAT := preload("res://art/materials/bronze.tres")
const BRICK_MAT := preload("res://art/materials/brick.tres")

signal setting_changed(setting: int)
signal north_gate_toggled(open: bool)
signal south_gate_toggled(open: bool)

## 0=封, 1=北, 2=南
@export var start_setting := 0
@export var interact_distance := 2.4
@export var gate_distance := 10.2:
	set(v):
		gate_distance = maxf(6.0, v)
		_request_rebuild()
@export var opening_width := 4.0:
	set(v):
		opening_width = maxf(2.4, v)
		_request_rebuild()
@export var opening_height := 3.9:
	set(v):
		opening_height = maxf(2.0, v)
		_request_rebuild()
@export var rise_distance := 4.1
@export var rise_speed := 1.8
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var prompt_hold_seconds := 1.8

var _setting := 0
var _spinning := false
var _spin_t := 0.0
var _from_yaw := 0.0
var _to_yaw := 0.0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _disk: Node3D
var _disk_area: Area3D
var _north_slab: Node3D
var _south_slab: Node3D
var _north_body: StaticBody3D
var _south_body: StaticBody3D
var _slab_start_y := 0.0
var _prompt: Label
var _prompt_left := 0.0
var _player: Node3D
var _sfx_turn: AudioStreamPlayer3D
var _sfx_gate: AudioStreamPlayer3D

const SETTING_NAMES := ["封", "北", "南"]
const SETTING_YAW := [0.5 * PI, 0.0, PI]


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
		print("RotatingDoor08: ready at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func get_setting() -> int:
	return _setting


func _rebuild_geometry() -> void:
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_setting = start_setting % 3
	_spinning = false

	var root := Node3D.new()
	root.name = "Generated"
	_attach(root, gen)

	_mesh_cyl(root, "Plinth", 1.7, 1.8, 0.28, Vector3(0, 0.14, 0), STONE_DARK_MAT)
	_disk = Node3D.new()
	_disk.name = "TurnDisk"
	_disk.position = Vector3(0, 0.36, 0)
	_disk.rotation.y = SETTING_YAW[_setting]
	root.add_child(_disk)
	_mesh_cyl(_disk, "Disk", 1.45, 1.45, 0.16, Vector3.ZERO, BRONZE_MAT)
	# Pointer: at yaw 0 it points +Z (south / 封 baseline). Setting 北 points −Z after -90°.
	# We treat pointer +Z as 封, −Z as 北, −X/+X we won't use; 南 is pointer +Z after 180°? 
	# SETTING_YAW[1] = -90° so pointer that starts +X... let's put the pointer along local −Z
	# (north) on the disk mesh, so setting 北 (yaw -90) actually... keep it simple:
	# Pointer along local −Z. When disk yaw=0, pointer faces north (−Z) — but we want start 封.
	# Use a carved ring of three labels around the floor instead, and a pointer to the active one.
	_mesh_box(_disk, "Pointer", Vector3(0.18, 0.08, 1.0), Vector3(0, 0.12, -0.45), STONE_DARK_MAT)

	# Floor marks around the disk: 封 at +X, 北 at −Z, 南 at +Z — wait pointer local -Z.
	# When yaw=SETTING_YAW[1]=-PI/2, local -Z world is -X. That's wrong.
	# Pointer local -Z. World direction of pointer = disk.basis * Vector3(0,0,-1).
	# yaw 0: pointer −Z (north) . So SETTING 北 should be yaw 0, but start is 封.
	# Remap: 封 yaw = PI/2 (pointer faces +X, a blank wall), 北 yaw=0, 南 yaw=PI.
	# I'll just use labels on the floor and not overthink the pointer art.

	_add_floor_label(root, "MarkNorth", Vector3(0, 0.05, -2.3), Color(0.25, 0.45, 0.7))
	_add_floor_label(root, "MarkSouth", Vector3(0, 0.05, 2.3), Color(0.7, 0.32, 0.22))
	_add_floor_label(root, "MarkSeal", Vector3(2.3, 0.05, 0), Color(0.45, 0.4, 0.32))

	_disk_area = Area3D.new()
	_disk_area.name = "DiskArea"
	_disk_area.position = Vector3(0, 0.7, 0)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.7
	shape.height = 1.4
	col.shape = shape
	_disk_area.add_child(col)
	root.add_child(_disk_area)

	_north_slab = _make_gate(root, "NorthGate", Vector3(0, 0, -gate_distance), 0.0)
	_south_slab = _make_gate(root, "SouthGate", Vector3(0, 0, gate_distance), PI)
	_slab_start_y = opening_height * 0.5
	_apply_gate_state(true)

	_sfx_turn = AudioStreamPlayer3D.new()
	_sfx_turn.stream = PLATE_CLACK
	_sfx_turn.unit_size = 8.0
	root.add_child(_sfx_turn)
	_sfx_gate = AudioStreamPlayer3D.new()
	_sfx_gate.stream = STONE_DOOR
	_sfx_gate.unit_size = 12.0
	root.add_child(_sfx_gate)


func _add_floor_label(parent: Node3D, label_name: String, pos: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	_mesh_box(parent, label_name, Vector3(0.7, 0.06, 0.7), pos, mat)


func _make_gate(parent: Node3D, gate_name: String, pos: Vector3, yaw: float) -> Node3D:
	var gate := Node3D.new()
	gate.name = gate_name
	gate.position = pos
	gate.rotation.y = yaw
	parent.add_child(gate)
	_mesh_box(gate, "JambL", Vector3(0.4, opening_height + 0.35, 0.6), Vector3(-(opening_width * 0.5 + 0.2), opening_height * 0.5, 0), STONE_DARK_MAT)
	_mesh_box(gate, "JambR", Vector3(0.4, opening_height + 0.35, 0.6), Vector3(opening_width * 0.5 + 0.2, opening_height * 0.5, 0), STONE_DARK_MAT)
	_mesh_box(gate, "Lintel", Vector3(opening_width + 1.0, 0.4, 0.65), Vector3(0, opening_height + 0.1, 0), STONE_DARK_MAT)
	var slab := Node3D.new()
	slab.name = "Slab"
	slab.position = Vector3(0, opening_height * 0.5, 0)
	gate.add_child(slab)
	_mesh_box(slab, "SlabBody", Vector3(opening_width * 0.96, opening_height * 0.98, 0.32), Vector3.ZERO, BRICK_MAT)
	var body := StaticBody3D.new()
	body.name = "Body"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening_width * 0.96, opening_height * 0.98, 0.32)
	col.shape = shape
	body.add_child(col)
	slab.add_child(body)
	if gate_name == "NorthGate":
		_north_body = body
	else:
		_south_body = body
	return slab


func _north_open() -> bool:
	return _setting == 1


func _south_open() -> bool:
	return _setting == 2


func _apply_gate_state(instant: bool) -> void:
	if instant:
		if _north_slab:
			_north_slab.position.y = _slab_start_y + (rise_distance if _north_open() else 0.0)
		if _south_slab:
			_south_slab.position.y = _slab_start_y + (rise_distance if _south_open() else 0.0)
		_set_body_open(_north_body, _north_open())
		_set_body_open(_south_body, _south_open())


func _set_body_open(body: StaticBody3D, is_open: bool) -> void:
	if body == null:
		return
	body.collision_layer = 0 if is_open else 1
	body.collision_mask = 0 if is_open else 1


func _clear_generated() -> void:
	_disk = null
	_disk_area = null
	_north_slab = null
	_south_slab = null
	_north_body = null
	_south_body = null
	_sfx_turn = null
	_sfx_gate = null
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
		_spin_t = move_toward(_spin_t, 1.0, delta * 2.2)
		_disk.rotation.y = lerp_angle(_from_yaw, _to_yaw, _spin_t)
		if _spin_t >= 1.0:
			_spinning = false
			_disk.rotation.y = _to_yaw
			if _sfx_gate:
				_sfx_gate.play()
			north_gate_toggled.emit(_north_open())
			south_gate_toggled.emit(_south_open())
			_show_prompt("通向：%s" % SETTING_NAMES[_setting], true)
	# Animate gates toward the current setting.
	if _north_slab:
		var nt := _slab_start_y + (rise_distance if _north_open() else 0.0)
		_north_slab.position.y = move_toward(_north_slab.position.y, nt, rise_speed * delta)
		if is_equal_approx(_north_slab.position.y, nt):
			_set_body_open(_north_body, _north_open())
	if _south_slab:
		var st := _slab_start_y + (rise_distance if _south_open() else 0.0)
		_south_slab.position.y = move_toward(_south_slab.position.y, st, rise_speed * delta)
		if is_equal_approx(_south_slab.position.y, st):
			_set_body_open(_south_body, _south_open())
	if _prompt_left > 0.0:
		_prompt_left -= delta
		if _prompt_left <= 0.0 and _prompt and not _disk_near():
			if _prompt.text.begins_with("E ") or _prompt.text.begins_with("通向"):
				_prompt.visible = false
		return
	if _spinning:
		return
	if _prompt == null or _player == null:
		return
	if not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if _disk_near():
		var nxt := SETTING_NAMES[(_setting + 1) % 3]
		_show_prompt("E 转动石盘（当前：%s，下一：%s）" % [SETTING_NAMES[_setting], nxt])
	elif _prompt.text.begins_with("E ") and "石盘" in _prompt.text:
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _spinning:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if not _disk_near():
		return
	_rotate_setting()
	get_viewport().set_input_as_handled()


func _rotate_setting() -> void:
	_from_yaw = SETTING_YAW[_setting]
	_setting = (_setting + 1) % 3
	_to_yaw = SETTING_YAW[_setting]
	_spin_t = 0.0
	_spinning = true
	if _sfx_turn:
		_sfx_turn.play()
	setting_changed.emit(_setting)
	# Re-enable collision while a gate is coming down.
	if not _north_open():
		_set_body_open(_north_body, false)
	if not _south_open():
		_set_body_open(_south_body, false)
