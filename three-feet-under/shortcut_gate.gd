@tool
extends Node3D

## One-way stone gate for a return shortcut.
## Locked until release_lock(); then it opens when the player is on the
## wing/passage side and closes when they have passed into the hub.

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")
const BRICK_MAT := preload("res://art/materials/brick.tres")
const STONE_DARK_MAT := preload("res://art/materials/stone_dark.tres")

signal lock_released
signal gate_opened
signal gate_closed

@export var opening_width := 4.0:
	set(v):
		opening_width = maxf(2.0, v)
		_request_rebuild()
@export var opening_height := 3.9:
	set(v):
		opening_height = maxf(2.0, v)
		_request_rebuild()
@export var slab_thickness := 0.32:
	set(v):
		slab_thickness = maxf(0.12, v)
		_request_rebuild()
@export var rise_distance := 4.1
@export var rise_speed := 1.7
@export var locked := true
@export var locked_prompt := "需先取得对应封印"
@export var use_brick := true
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
## World-space direction from the gate toward the hub interior.
@export var hub_forward := Vector3(-1, 0, 0)
@export var wing_open_distance := 3.4
@export var hub_close_distance := 1.8
@export var prompt_hold_seconds := 2.0

var _unlocked := false
var _opened := false
var _moving := 0  # 1 opening, -1 closing, 0 idle
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0
var _slab: Node3D
var _slab_body: StaticBody3D
var _slab_start_y := 0.0
var _prompt: Label
var _prompt_left := 0.0
var _player: Node3D
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	_unlocked = not locked
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
		print("ShortcutGate: ready at ", global_position, " locked=", not _unlocked)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func is_open() -> bool:
	return _opened


func is_unlocked() -> bool:
	return _unlocked


func release_lock() -> void:
	if _unlocked:
		return
	_unlocked = true
	locked = false
	lock_released.emit()
	_show_prompt("捷径已开，单向返回枢纽", true)
	print("ShortcutGate: lock released at ", global_position)


func _rebuild_geometry() -> void:
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	var mat: Material = BRICK_MAT if use_brick else STONE_DARK_MAT
	var root := Node3D.new()
	root.name = "Generated"
	_attach(root, gen)
	_mesh_box(root, "JambL", Vector3(0.4, opening_height + 0.4, 0.65), Vector3(-(opening_width * 0.5 + 0.22), opening_height * 0.5, 0), STONE_DARK_MAT)
	_mesh_box(root, "JambR", Vector3(0.4, opening_height + 0.4, 0.65), Vector3(opening_width * 0.5 + 0.22, opening_height * 0.5, 0), STONE_DARK_MAT)
	_mesh_box(root, "Lintel", Vector3(opening_width + 1.0, 0.45, 0.7), Vector3(0, opening_height + 0.12, 0), STONE_DARK_MAT)
	_slab = Node3D.new()
	_slab.name = "Slab"
	_slab.position = Vector3(0, opening_height * 0.5, 0)
	root.add_child(_slab)
	_slab_start_y = _slab.position.y
	_mesh_box(_slab, "SlabBody", Vector3(opening_width * 0.96, opening_height * 0.98, slab_thickness), Vector3.ZERO, mat)
	_slab_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening_width * 0.96, opening_height * 0.98, slab_thickness)
	col.shape = shape
	_slab_body.add_child(col)
	_slab.add_child(_slab_body)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = STONE_DOOR
	_sfx.unit_size = 11.0
	root.add_child(_sfx)
	_opened = false
	_moving = 0


func _clear_generated() -> void:
	_slab = null
	_slab_body = null
	_sfx = null
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


func _hub_axis() -> Vector3:
	var d := hub_forward
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(-1, 0, 0)
	return d.normalized()


func _player_along_hub() -> float:
	if _player == null:
		return 0.0
	var offset := _player.global_position - global_position
	offset.y = 0.0
	return offset.dot(_hub_axis())


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
	if _prompt_left > 0.0:
		_prompt_left -= delta
		if _prompt_left <= 0.0 and _prompt and (
			_prompt.text.contains("捷径") or _prompt.text.contains("封印") or _prompt.text.contains("单向")
		):
			_prompt.visible = false
	if _slab and _moving != 0:
		var target := _slab_start_y + (rise_distance if _moving > 0 else 0.0)
		_slab.position.y = move_toward(_slab.position.y, target, rise_speed * delta)
		if is_equal_approx(_slab.position.y, target):
			if _moving > 0:
				_opened = true
				if _slab_body:
					_slab_body.collision_layer = 0
					_slab_body.collision_mask = 0
				gate_opened.emit()
			else:
				_opened = false
				if _slab_body:
					_slab_body.collision_layer = 1
					_slab_body.collision_mask = 1
				gate_closed.emit()
			_moving = 0
		return
	if _player == null:
		return
	var along := _player_along_hub()
	var side := _player.global_position - global_position
	side.y = 0.0
	if not _unlocked:
		# Show locked hint if standing close on either side.
		if side.length() <= 2.6 and along > -0.4:
			_show_prompt(locked_prompt)
		elif _prompt and _prompt.text == locked_prompt and _prompt_left <= 0.0:
			_prompt.visible = false
		return
	# Wing / passage side is opposite hub_forward (along < 0).
	if not _opened and along < -0.4 and side.length() <= wing_open_distance:
		_begin_open()
	elif _opened and along > hub_close_distance:
		_begin_close()


func _begin_open() -> void:
	if _opened or _moving != 0 or _slab == null:
		return
	_moving = 1
	if _sfx:
		_sfx.play()
	print("ShortcutGate: opening")


func _begin_close() -> void:
	if not _opened or _moving != 0 or _slab == null:
		return
	_moving = -1
	if _slab_body:
		_slab_body.collision_layer = 1
		_slab_body.collision_mask = 1
	if _sfx:
		_sfx.play()
	print("ShortcutGate: closing behind player")
