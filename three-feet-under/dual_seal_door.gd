@tool
extends Node3D

const STONE_DOOR := preload("res://audio/sfx/stone_door.ogg")

## Hub dual-seal bronze double door (双印门).
## Left = yellow/gold seal, Right = blue seal. Both must unlock before doors open.
## West/east puzzle scripts can call unlock_yellow_seal() / unlock_blue_seal().
## Debug: stand near a glowing socket and press E to unlock that seal.

signal seal_unlocked(which: StringName)
signal both_seals_unlocked
signal door_opened

@export var door_width := 5.6:
	set(v):
		door_width = maxf(2.0, v)
		_request_rebuild()
@export var door_height := 4.2:
	set(v):
		door_height = maxf(2.0, v)
		_request_rebuild()
@export var door_thickness := 0.22:
	set(v):
		door_thickness = maxf(0.08, v)
		_request_rebuild()
@export var open_angle_degrees := 100.0
@export var open_speed := 70.0
@export var interact_distance := 2.4
@export var allow_debug_interact := true
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var auto_open_when_both_unlocked := true

var _yellow_unlocked := false
var _blue_unlocked := false
var _opening := false
var _opened := false
var _open_t := 0.0
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _left_leaf: Node3D
var _right_leaf: Node3D
var _left_body: StaticBody3D
var _right_body: StaticBody3D
var _yellow_area: Area3D
var _blue_area: Area3D
var _prompt: Label
var _player: Node3D
var _sfx: AudioStreamPlayer3D

var _bronze: StandardMaterial3D
var _bronze_dark: StandardMaterial3D
var _patina: StandardMaterial3D
var _yellow_emit: StandardMaterial3D
var _blue_emit: StandardMaterial3D
var _socket_well: StandardMaterial3D


func _ready() -> void:
	_request_rebuild(true)
	if not Engine.is_editor_hint():
		_sfx = AudioStreamPlayer3D.new()
		_sfx.stream = STONE_DOOR
		_sfx.volume_db = -2.0
		_sfx.pitch_scale = 0.75
		_sfx.max_distance = 28.0
		add_child(_sfx)


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
		print("DualSealDoor: ready at ", global_position)
	else:
		print("DualSealDoor: editor preview at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


func unlock_yellow_seal() -> void:
	_unlock_seal(&"yellow")


func unlock_blue_seal() -> void:
	_unlock_seal(&"blue")


func unlock_seal(which: StringName) -> void:
	_unlock_seal(which)


func is_yellow_unlocked() -> bool:
	return _yellow_unlocked


func is_blue_unlocked() -> bool:
	return _blue_unlocked


func are_both_unlocked() -> bool:
	return _yellow_unlocked and _blue_unlocked


func is_open() -> bool:
	return _opened


func force_open() -> void:
	if _opened or _opening:
		return
	_yellow_unlocked = true
	_blue_unlocked = true
	_begin_open()


func _unlock_seal(which: StringName) -> void:
	var changed := false
	if which == &"yellow" and not _yellow_unlocked:
		_yellow_unlocked = true
		changed = true
		_set_socket_unlocked_look(_yellow_area, true)
	elif which == &"blue" and not _blue_unlocked:
		_blue_unlocked = true
		changed = true
		_set_socket_unlocked_look(_blue_area, true)
	if not changed:
		return
	seal_unlocked.emit(which)
	print("DualSealDoor: unlocked ", which)
	if _yellow_unlocked and _blue_unlocked:
		both_seals_unlocked.emit()
		if auto_open_when_both_unlocked:
			_begin_open()


func _begin_open() -> void:
	if _opened or _opening:
		return
	_opening = true
	if _sfx:
		_sfx.play()
	if _prompt:
		_prompt.visible = false
	print("DualSealDoor: opening")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _opening:
		_open_t = move_toward(_open_t, 1.0, (open_speed / maxf(open_angle_degrees, 1.0)) * delta)
		var ang := deg_to_rad(open_angle_degrees * _open_t)
		if _left_leaf:
			_left_leaf.rotation.y = -ang
		if _right_leaf:
			_right_leaf.rotation.y = ang
		if _open_t >= 1.0:
			_opening = false
			_opened = true
			if _left_body:
				_left_body.collision_layer = 0
				_left_body.collision_mask = 0
			if _right_body:
				_right_body.collision_layer = 0
				_right_body.collision_mask = 0
			door_opened.emit()
		return

	if _opened:
		return

	_update_debug_prompt()


func _update_debug_prompt() -> void:
	if not allow_debug_interact or _prompt == null or _player == null:
		return
	if not (_player.has_method("can_interact") and _player.can_interact()):
		return
	var near_y := _socket_near(_yellow_area) and not _yellow_unlocked
	var near_b := _socket_near(_blue_area) and not _blue_unlocked
	if near_y:
		_prompt.visible = true
		_prompt.text = "E 试转黄印（调试）"
	elif near_b:
		_prompt.visible = true
		_prompt.text = "E 试转蓝印（调试）"
	elif _prompt.text.begins_with("E 试转"):
		_prompt.visible = false


func _socket_near(area: Area3D) -> bool:
	if area == null or _player == null:
		return false
	var offset := _player.global_position - area.global_position
	offset.y = 0.0
	return offset.length() <= interact_distance


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not allow_debug_interact:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _socket_near(_yellow_area) and not _yellow_unlocked:
		unlock_yellow_seal()
		get_viewport().set_input_as_handled()
	elif _socket_near(_blue_area) and not _blue_unlocked:
		unlock_blue_seal()
		get_viewport().set_input_as_handled()


func _make_materials() -> void:
	_bronze = StandardMaterial3D.new()
	_bronze.albedo_color = Color(0.28, 0.18, 0.10)
	_bronze.metallic = 0.72
	_bronze.roughness = 0.55

	_bronze_dark = StandardMaterial3D.new()
	_bronze_dark.albedo_color = Color(0.14, 0.10, 0.07)
	_bronze_dark.metallic = 0.7
	_bronze_dark.roughness = 0.7

	_patina = StandardMaterial3D.new()
	_patina.albedo_color = Color(0.22, 0.32, 0.24)
	_patina.metallic = 0.45
	_patina.roughness = 0.82

	_socket_well = StandardMaterial3D.new()
	_socket_well.albedo_color = Color(0.05, 0.04, 0.03)
	_socket_well.metallic = 0.3
	_socket_well.roughness = 0.9

	_yellow_emit = StandardMaterial3D.new()
	_yellow_emit.albedo_color = Color(0.95, 0.72, 0.18)
	_yellow_emit.emission_enabled = true
	_yellow_emit.emission = Color(1.0, 0.75, 0.15)
	_yellow_emit.emission_energy_multiplier = 3.2
	_yellow_emit.metallic = 0.4
	_yellow_emit.roughness = 0.35

	_blue_emit = StandardMaterial3D.new()
	_blue_emit.albedo_color = Color(0.25, 0.55, 0.95)
	_blue_emit.emission_enabled = true
	_blue_emit.emission = Color(0.2, 0.55, 1.0)
	_blue_emit.emission_energy_multiplier = 3.4
	_blue_emit.metallic = 0.4
	_blue_emit.roughness = 0.35


func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Gen_") or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_left_leaf = null
	_right_leaf = null
	_left_body = null
	_right_body = null
	_yellow_area = null
	_blue_area = null


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


func _mesh_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mesh_cyl(parent: Node3D, name: String, r_top: float, r_bot: float, height: float, pos: Vector3, mat: Material, segs: int = 20, face_z: bool = false) -> MeshInstance3D:
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
		# Cylinder height is Y; rotate so disc faces door front (+Z).
		mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	return mi


func _add_collision(leaf: Node3D, size: Vector3, local_center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = local_center
	body.add_child(cs)
	leaf.add_child(body)
	return body


func _build_socket(leaf: Node3D, name: String, pos: Vector3, emit_mat: Material) -> Area3D:
	var socket := Node3D.new()
	socket.name = name
	socket.position = pos
	leaf.add_child(socket)

	# Recessed well
	_mesh_cyl(socket, "Well", 0.38, 0.38, 0.08, Vector3(0, 0, door_thickness * 0.28), _socket_well, 24, true)
	# Glow rim
	_mesh_cyl(socket, "Rim", 0.48, 0.48, 0.07, Vector3(0, 0, door_thickness * 0.36), emit_mat, 28, true)
	# Inner cog-like stepped ring (visual only)
	_mesh_cyl(socket, "Cog", 0.30, 0.30, 0.05, Vector3(0, 0, door_thickness * 0.40), _bronze_dark, 12, true)
	_mesh_cyl(socket, "Hub", 0.10, 0.10, 0.06, Vector3(0, 0, door_thickness * 0.44), _bronze, 10, true)

	var area := Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	cs.shape = sphere
	area.add_child(cs)
	socket.add_child(area)
	return area


func _build_dragon(leaf: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "DragonMedallion"
	root.position = pos
	leaf.add_child(root)
	_mesh_box(root, "Plate", Vector3(0.95, 0.95, 0.04), Vector3(0, 0, door_thickness * 0.35), _bronze_dark)
	_mesh_cyl(root, "Disc", 0.40, 0.40, 0.06, Vector3(0, 0, door_thickness * 0.40), _patina, 22, true)
	# Coiled "dragon" suggestion: torus-like stacked cylinders + head bump
	_mesh_cyl(root, "Coil", 0.28, 0.28, 0.08, Vector3(0, 0, door_thickness * 0.46), _bronze, 16, true)
	_mesh_cyl(root, "Head", 0.10, 0.12, 0.14, Vector3(0.18, 0.12, door_thickness * 0.52), _bronze, 10, true)


func _build_knocker(leaf: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "LionKnocker"
	root.position = pos
	leaf.add_child(root)
	_mesh_cyl(root, "LionHead", 0.22, 0.26, 0.18, Vector3(0, 0, door_thickness * 0.42), _bronze, 14, true)
	_mesh_cyl(root, "Muzzle", 0.10, 0.12, 0.10, Vector3(0, -0.06, door_thickness * 0.52), _bronze_dark, 10, true)
	# Ring (torus approx: thin cylinder rotated)
	var ring := _mesh_cyl(root, "Ring", 0.20, 0.20, 0.05, Vector3(0, -0.32, door_thickness * 0.48), _bronze, 18)
	ring.rotation_degrees = Vector3(90, 0, 0)
	var ring_i := _mesh_cyl(root, "RingInner", 0.14, 0.14, 0.06, Vector3(0, -0.32, door_thickness * 0.48), _bronze_dark, 16)
	ring_i.rotation_degrees = Vector3(90, 0, 0)


func _build_leaf(is_left: bool, gen: int) -> void:
	var half_w := door_width * 0.5
	# Slight overlap at center so closed leaves look flush (no dark mid seam).
	var overlap := 0.02
	var leaf_w := half_w + overlap
	var hinge_x := -half_w if is_left else half_w
	var panel_center_x := (leaf_w * 0.5) if is_left else (-leaf_w * 0.5)

	var leaf := Node3D.new()
	leaf.name = "Gen_LeftLeaf" if is_left else "Gen_RightLeaf"
	leaf.position = Vector3(hinge_x, door_height * 0.5, 0.0)

	# Main panel (local space: hinge at x=0)
	_mesh_box(leaf, "Panel", Vector3(leaf_w, door_height, door_thickness), Vector3(panel_center_x, 0, 0), _bronze)
	# Raised border
	_mesh_box(leaf, "Border", Vector3(leaf_w * 0.92, door_height * 0.92, door_thickness * 0.35), Vector3(panel_center_x, 0, door_thickness * 0.25), _bronze_dark)
	# Vertical fillet
	_mesh_box(leaf, "Filigree", Vector3(leaf_w * 0.78, door_height * 0.78, door_thickness * 0.12), Vector3(panel_center_x, 0, door_thickness * 0.30), _patina)
	# Meeting stile at the center edge — covers residual seam when closed.
	var stile_x := leaf_w if is_left else -leaf_w
	_mesh_box(
		leaf,
		"MeetingStile",
		Vector3(0.06, door_height * 0.98, door_thickness * 1.15),
		Vector3(stile_x, 0.0, door_thickness * 0.08),
		_bronze
	)

	var cx := panel_center_x
	_build_dragon(leaf, Vector3(cx, door_height * 0.28, 0))
	var socket_pos := Vector3(cx, door_height * 0.02, 0)
	var area: Area3D
	if is_left:
		area = _build_socket(leaf, "YellowSocket", socket_pos, _yellow_emit)
		_yellow_area = area
	else:
		area = _build_socket(leaf, "BlueSocket", socket_pos, _blue_emit)
		_blue_area = area
	_build_knocker(leaf, Vector3(cx, -door_height * 0.28, 0))

	# Side hinge barrels
	for i in range(3):
		var hy := lerpf(-door_height * 0.38, door_height * 0.38, float(i) / 2.0)
		_mesh_cyl(leaf, "Hinge_%d" % i, 0.07, 0.07, 0.28, Vector3(0.0, hy, 0.0), _bronze_dark, 10)

	var body := _add_collision(leaf, Vector3(leaf_w, door_height, door_thickness), Vector3(panel_center_x, 0, 0))
	if is_left:
		_left_leaf = leaf
		_left_body = body
	else:
		_right_leaf = leaf
		_right_body = body

	_attach(leaf, gen)
	# restore unlocked look after rebuild
	if not Engine.is_editor_hint():
		call_deferred("_refresh_socket_looks")


func _refresh_socket_looks() -> void:
	_set_socket_unlocked_look(_yellow_area, _yellow_unlocked)
	_set_socket_unlocked_look(_blue_area, _blue_unlocked)


func _set_socket_unlocked_look(area: Area3D, unlocked: bool) -> void:
	if area == null:
		return
	var socket := area.get_parent()
	if socket == null:
		return
	var rim := socket.get_node_or_null("Rim") as MeshInstance3D
	if rim and rim.material_override is StandardMaterial3D:
		var mat := (rim.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.emission_energy_multiplier = 6.0 if unlocked else 3.2
		rim.material_override = mat


func _build_geometry(gen: int) -> void:
	# Stone/bronze frame around opening (visual only)
	var frame := Node3D.new()
	frame.name = "Gen_Frame"
	_mesh_box(frame, "Threshold", Vector3(door_width + 0.6, 0.18, 0.55), Vector3(0, 0.09, 0.05), _bronze_dark)
	_mesh_box(frame, "LintelBar", Vector3(door_width + 0.8, 0.35, 0.45), Vector3(0, door_height + 0.2, 0.0), _bronze)
	_mesh_box(frame, "PostL", Vector3(0.28, door_height + 0.4, 0.45), Vector3(-(door_width * 0.5 + 0.2), door_height * 0.5, 0.0), _bronze_dark)
	_mesh_box(frame, "PostR", Vector3(0.28, door_height + 0.4, 0.45), Vector3(door_width * 0.5 + 0.2, door_height * 0.5, 0.0), _bronze_dark)
	_attach(frame, gen)

	_build_leaf(true, gen)
	_build_leaf(false, gen)