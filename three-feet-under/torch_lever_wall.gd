@tool
extends Node3D

## Torch-lever rising stone wall (concept A).
## E on the torch sconce pulls the lever down; the slab slides upward into the frame.
## require_torch_item=false for now; set true later when inventory torch exists.

signal lever_pulled
signal wall_opened
signal wall_blocked_needs_torch
signal wall_blocked_locked
signal lock_released

@export var opening_width := 4.2:
	set(v):
		opening_width = maxf(2.0, v)
		_request_rebuild()
@export var opening_height := 4.4:
	set(v):
		opening_height = maxf(2.0, v)
		_request_rebuild()
@export var slab_thickness := 0.35:
	set(v):
		slab_thickness = maxf(0.15, v)
		_request_rebuild()
@export var rise_distance := 4.6
@export var rise_speed := 1.6
@export var lever_pull_speed := 90.0
@export var lever_pull_degrees := 30.0
@export var lever_rest_degrees := 10.0
@export var interact_distance := 2.3
@export var allow_debug_interact := true
@export var require_torch_item := false
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var lever_on_right := false
@export var lever_on_inner_wall := false
@export var lever_on_passage_side := false
@export var locked := false
@export var locked_prompt := "需先取得西侧封印"
@export var close_behind := false
## World-space direction from the wall toward the hub interior.
@export var hub_forward := Vector3(1, 0, 0)
@export var hub_close_distance := 1.8

var _opened := false
var _opening := false
var _closing := false
var _unlocked := true
var _lever_animating := false
var _lever_t := 0.0
var _slab_start_y := 0.0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _slab: Node3D
var _slab_body: StaticBody3D
var _lever_arm: Node3D
var _lever_area: Area3D
var _flame_light: OmniLight3D
var _prompt: Label
var _player: Node3D

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _bronze: StandardMaterial3D
var _bronze_dark: StandardMaterial3D
var _flame_mat: StandardMaterial3D


func _ready() -> void:
	_unlocked = not locked
	_request_rebuild(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		return
	if what == NOTIFICATION_ENTER_TREE and Engine.is_editor_hint():
		_request_rebuild(true)


func _request_rebuild(from_boot: bool = false) -> void:
	if not is_inside_tree():
		return
	if _rebuild_queued:
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
		print("TorchLeverWall: ready at ", global_position)
	else:
		print("TorchLeverWall: editor preview at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func is_open() -> bool:
	return _opened


func open_wall() -> void:
	if _opened or _opening or _closing:
		return
	_start_sequence()


func is_unlocked() -> bool:
	return _unlocked


func release_lock() -> void:
	if _unlocked:
		return
	_unlocked = true
	locked = false
	lock_released.emit()
	if _prompt:
		_prompt.visible = true
		_prompt.text = "捷径已开，扳壁灯单向返回"
	print("TorchLeverWall: lock released at ", global_position)


func _player_has_torch() -> bool:
	# Hook for later inventory. Currently always true unless require_torch_item.
	if not require_torch_item:
		return true
	if _player == null:
		return false
	if _player.has_method("has_item") and _player.has_item("torch"):
		return true
	if _player.get("inventory") is Array and ("torch" in _player.inventory):
		return true
	return false


func _start_sequence() -> void:
	if _opened or _opening or _closing or _lever_animating:
		return
	if not _unlocked:
		wall_blocked_locked.emit()
		if _prompt:
			_prompt.visible = true
			_prompt.text = locked_prompt
		return
	if not _player_has_torch():
		wall_blocked_needs_torch.emit()
		if _prompt:
			_prompt.visible = true
			_prompt.text = "需要火把插入壁灯"
		return
	_lever_animating = true
	_lever_t = 0.0
	lever_pulled.emit()
	print("TorchLeverWall: lever pulled")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _lever_animating and _lever_arm:
		_lever_t = move_toward(_lever_t, 1.0, (lever_pull_speed / maxf(lever_pull_degrees, 1.0)) * delta)
		# Up ~+45deg to down ~-45deg around local Z (arm swings in vertical plane).
		var start_ang := lever_rest_degrees
		var end_ang := lever_rest_degrees - lever_pull_degrees
		var ang := deg_to_rad(lerpf(start_ang, end_ang, _lever_t))
		_lever_arm.rotation.z = ang
		if _lever_t >= 1.0:
			_lever_animating = false
			_opening = true
			_slab_start_y = _slab.position.y if _slab else opening_height * 0.5

	if _opening and _slab:
		var target_y := _slab_start_y + rise_distance
		_slab.position.y = move_toward(_slab.position.y, target_y, rise_speed * delta)
		if is_equal_approx(_slab.position.y, target_y):
			_opening = false
			_opened = true
			if _slab_body:
				_slab_body.collision_layer = 0
				_slab_body.collision_mask = 0
			wall_opened.emit()
			print("TorchLeverWall: wall opened")
			if _prompt:
				_prompt.visible = false
		return

	if _closing and _slab:
		var target_y := _slab_start_y
		_slab.position.y = move_toward(_slab.position.y, target_y, rise_speed * delta)
		if is_equal_approx(_slab.position.y, target_y):
			_closing = false
			_opened = false
			_opening = false
			_lever_animating = false
			_lever_t = 0.0
			if _lever_arm:
				_lever_arm.rotation.z = deg_to_rad(lever_rest_degrees)
			if _slab_body:
				_slab_body.collision_layer = 1
				_slab_body.collision_mask = 1
			print("TorchLeverWall: closed behind player")
		return

	if _opened:
		if close_behind and _player_on_hub_side():
			_begin_close()
		return

	_update_prompt()


func _update_prompt() -> void:
	if not allow_debug_interact or _prompt == null or _player == null:
		return
	if not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not _lever_near():
		if _prompt.text.begins_with("E ") and ("壁灯" in _prompt.text or "火把" in _prompt.text or "封印" in _prompt.text):
			_prompt.visible = false
		return
	_prompt.visible = true
	if not _unlocked:
		_prompt.text = locked_prompt
	elif require_torch_item and not _player_has_torch():
		_prompt.text = "E 需要火把"
	else:
		_prompt.text = "E 扳下壁灯，单向返回枢纽"


func _lever_near() -> bool:
	if _lever_area == null or _player == null:
		return false
	var offset := _player.global_position - _lever_area.global_position
	offset.y = 0.0
	return offset.length() <= interact_distance


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not allow_debug_interact:
		return
	if _opened or _opening or _closing or _lever_animating:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _lever_near():
		_start_sequence()
		get_viewport().set_input_as_handled()


func _player_on_hub_side() -> bool:
	if _player == null:
		return false
	var d := hub_forward
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(1, 0, 0)
	d = d.normalized()
	var offset := _player.global_position - global_position
	offset.y = 0.0
	return offset.dot(d) > hub_close_distance


func _begin_close() -> void:
	if not _opened or _closing or _slab == null:
		return
	_closing = true
	if _slab_body:
		_slab_body.collision_layer = 1
		_slab_body.collision_mask = 1
	print("TorchLeverWall: closing behind player")


func _make_materials() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.32, 0.30, 0.28)
	_stone.roughness = 0.92
	_stone.metallic = 0.05

	_stone_dark = StandardMaterial3D.new()
	_stone_dark.albedo_color = Color(0.18, 0.17, 0.16)
	_stone_dark.roughness = 0.95

	_bronze = StandardMaterial3D.new()
	_bronze.albedo_color = Color(0.30, 0.20, 0.10)
	_bronze.metallic = 0.75
	_bronze.roughness = 0.48

	_bronze_dark = StandardMaterial3D.new()
	_bronze_dark.albedo_color = Color(0.14, 0.10, 0.07)
	_bronze_dark.metallic = 0.7
	_bronze_dark.roughness = 0.65

	_flame_mat = StandardMaterial3D.new()
	_flame_mat.albedo_color = Color(1.0, 0.55, 0.12)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.45, 0.08)
	_flame_mat.emission_energy_multiplier = 4.5
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Gen_") or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_slab = null
	_slab_body = null
	_lever_arm = null
	_lever_area = null
	_flame_light = null


func _rebuild_geometry() -> void:
	if not is_inside_tree():
		return
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_make_materials()
	_build_geometry(gen)


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


func _mesh_cyl(parent: Node, name: String, r_top: float, r_bot: float, height: float, pos: Vector3, mat: Material, segs: int = 16, face_z: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = height
	cyl.radial_segments = segs
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	if face_z:
		mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	return mi


func _build_geometry(gen: int) -> void:
	var frame := Node3D.new()
	frame.name = "Gen_Frame"

	# Carved stone frame (jambs + lintel + threshold)
	_mesh_box(frame, "JambL", Vector3(0.45, opening_height + 0.5, 0.7), Vector3(-(opening_width * 0.5 + 0.25), opening_height * 0.5, 0.0), _stone_dark)
	_mesh_box(frame, "JambR", Vector3(0.45, opening_height + 0.5, 0.7), Vector3(opening_width * 0.5 + 0.25, opening_height * 0.5, 0.0), _stone_dark)
	_mesh_box(frame, "Lintel", Vector3(opening_width + 1.1, 0.55, 0.75), Vector3(0.0, opening_height + 0.15, 0.0), _stone)
	_mesh_box(frame, "Threshold", Vector3(opening_width + 0.8, 0.2, 0.7), Vector3(0.0, 0.1, 0.05), _stone_dark)
	# Meander / fret suggestion on lintel face
	_mesh_box(frame, "LintelCarve", Vector3(opening_width * 0.85, 0.18, 0.12), Vector3(0.0, opening_height + 0.15, 0.38), _bronze_dark)
	_attach(frame, gen)

	# Rising slab
	var slab := Node3D.new()
	slab.name = "Gen_Slab"
	slab.position = Vector3(0.0, opening_height * 0.5, 0.0)
	_mesh_box(slab, "SlabBody", Vector3(opening_width * 0.96, opening_height * 0.98, slab_thickness), Vector3.ZERO, _stone)
	# Cracks (dark recessed strips)
	_mesh_box(slab, "CrackV", Vector3(0.04, opening_height * 0.7, slab_thickness * 1.05), Vector3(-0.35, 0.1, 0.0), _stone_dark)
	_mesh_box(slab, "CrackH", Vector3(opening_width * 0.55, 0.04, slab_thickness * 1.05), Vector3(0.2, -0.4, 0.0), _stone_dark)
	_mesh_box(slab, "CrackV2", Vector3(0.035, opening_height * 0.4, slab_thickness * 1.05), Vector3(0.55, 0.5, 0.0), _stone_dark)

	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening_width * 0.96, opening_height * 0.98, slab_thickness)
	cs.shape = shape
	body.add_child(cs)
	slab.add_child(body)
	_slab = slab
	_slab_body = body
	_attach(slab, gen)

	# Torch lever on side wall (right = +X local when facing door)
	var side := 1.0 if lever_on_right else -1.0
	var lever_root := Node3D.new()
	lever_root.name = "Gen_TorchLever"
	# Local +Z is tomb/hub face; local -Z is passage/corridor side.
	# Passage side sits deeper into corridor (-1.15) and is yaw-flipped 180° from hub mount.
	var depth := -1.15 if lever_on_passage_side else 0.42
	if lever_on_inner_wall:
		# Mount on INNER side wall of doorway (jamb), on chosen face.
		# Passage: push slightly INTO the brick (+0.06 past opening edge) so plate sits flush, no float gap.
		# Hub face: small inset so bracket clears jamb lip.
		var lateral := (opening_width * 0.5 + 0.06) if lever_on_passage_side else (opening_width * 0.5 - 0.04)
		lever_root.position = Vector3(side * lateral, 1.15, depth)
		# Face into the corridor volume from the side wall; +180 when on passage side.
		if lever_on_passage_side:
			lever_root.rotation_degrees.y = side * 90.0 + 180.0
		else:
			lever_root.rotation_degrees.y = -side * 90.0
	else:
		# Outside jamb; default hub face, or passage face when requested.
		var outer_depth := -1.15 if lever_on_passage_side else 0.55
		lever_root.position = Vector3(side * (opening_width * 0.5 + 0.42), 1.15, outer_depth)
		if lever_on_passage_side:
			lever_root.rotation_degrees.y = 0.0  # was 180; +180 flip from prior passage mount

	# Ornate bronze pivot plate
	_mesh_box(lever_root, "Plate", Vector3(0.55, 0.7, 0.08), Vector3(0, 0, -0.05), _bronze_dark)
	_mesh_cyl(lever_root, "PlateRing", 0.28, 0.28, 0.06, Vector3(0, 0, 0.0), _bronze, 24, true)
	_mesh_cyl(lever_root, "Pivot", 0.08, 0.08, 0.1, Vector3(0, 0, 0.06), _bronze_dark, 12, true)

	var arm := Node3D.new()
	arm.name = "LeverArm"
	arm.rotation_degrees = Vector3(0, 0, lever_rest_degrees) # resting slightly up
	lever_root.add_child(arm)
	_lever_arm = arm

	_mesh_box(arm, "ArmBar", Vector3(0.1, 0.85, 0.1), Vector3(0, 0.4, 0.12), _bronze)
	_mesh_cyl(arm, "Cup", 0.12, 0.14, 0.16, Vector3(0, 0.85, 0.12), _bronze_dark, 14)
	# Torch stick in cup
	_mesh_cyl(arm, "TorchStick", 0.035, 0.04, 0.55, Vector3(0, 1.15, 0.12), _stone_dark, 8)
	_mesh_cyl(arm, "Flame", 0.07, 0.025, 0.28, Vector3(0, 1.48, 0.12), _flame_mat, 8)

	var light := OmniLight3D.new()
	light.name = "FlameLight"
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.2
	light.omni_range = 6.5
	light.position = Vector3(0, 1.5, 0.12)
	arm.add_child(light)
	_flame_light = light

	var area := Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.7
	acs.shape = sph
	acs.position = Vector3(0, 0.5, 0.2)
	area.add_child(acs)
	lever_root.add_child(area)
	_lever_area = area

	_attach(lever_root, gen)