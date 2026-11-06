@tool
extends Node3D

## Dilapidated but complete stone bridge across Chasm07 (深渊断桥).
## Spans end-to-end with cracked uneven slabs and broken rails.
## Hooks for later collapse / rope swing — not triggered yet.

signal player_entered_midspan
signal player_exited_midspan
signal collapse_requested  # for future A→B→C sequence

@export var bridge_length := 24.0:
	set(v):
		bridge_length = maxf(6.0, v)
		_request_rebuild()
## Target width = OUTER span of BankA/CFrame shoulders at Chasm07 heads
## (local Z -23.30..-16.70, EastWing*1.5 → world 9.9), not the 4.5 corridor inner opening.
@export var bridge_width := 9.9:
	set(v):
		bridge_width = maxf(1.5, v)
		_request_rebuild()
@export var slab_cols := 14:
	set(v):
		slab_cols = maxi(4, v)
		_request_rebuild()
@export var slab_rows := 3:
	set(v):
		slab_rows = maxi(2, v)
		_request_rebuild()
@export var arch_height := 0.55
@export var deck_thickness := 0.28
@export var enable_midspan_shake := true
@export var shake_amplitude := 0.018
@export var allow_future_collapse := true
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")

var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0
var _rng := RandomNumberGenerator.new()

var _deck_root: Node3D
var _mid_area: Area3D
var _player_on_mid := false
var _shake_t := 0.0
var _deck_base_y := 0.0

var _stone: Material
var _stone_dark: Material
var _moss: Material


func _ready() -> void:
	_rng.randomize()
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
	if Engine.is_editor_hint():
		print("DilapidatedBridge: editor preview len=", bridge_length, " width=", bridge_width, " at ", global_position)
	else:
		print("DilapidatedBridge: ready len=", bridge_length, " width=", bridge_width, " at ", global_position)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild_geometry()


## Future collapse entry point (no-op for now aside from signal).
func request_collapse() -> void:
	if not allow_future_collapse:
		return
	collapse_requested.emit()
	print("DilapidatedBridge: collapse_requested (stub)")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enable_midspan_shake or _deck_root == null:
		return
	if _player_on_mid:
		_shake_t += delta * 9.0
		var amp: float = shake_amplitude
		_deck_root.position.y = _deck_base_y + sin(_shake_t) * amp
		_deck_root.position.z = sin(_shake_t * 1.3) * amp * 0.35
	else:
		_deck_root.position.y = move_toward(_deck_root.position.y, _deck_base_y, delta * 0.08)
		_deck_root.position.z = move_toward(_deck_root.position.z, 0.0, delta * 0.08)



func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Gen_") or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_deck_root = null
	_mid_area = null
	_player_on_mid = false


func _rebuild_geometry() -> void:
	if not is_inside_tree():
		return
	_build_gen += 1
	var gen: int = _build_gen
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


func _mesh_box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _make_materials() -> void:
	var floor_mat := load("res://art/materials/floor.tres")
	var wall_mat := load("res://art/materials/wall.tres")
	var rock_mat := load("res://art/materials/rock.tres")
	if floor_mat is Material:
		_stone = floor_mat
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.30, 0.29, 0.27)
		sm.roughness = 0.94
		_stone = sm
	if wall_mat is Material:
		_stone_dark = wall_mat
	else:
		var sd := StandardMaterial3D.new()
		sd.albedo_color = Color(0.22, 0.21, 0.20)
		sd.roughness = 0.96
		_stone_dark = sd
	if rock_mat is Material:
		_moss = rock_mat
	else:
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color(0.20, 0.26, 0.18)
		ms.roughness = 1.0
		_moss = ms


func _arch_y(x: float) -> float:
	# Slight humpback: 0 at ends, arch_height at center.
	var t: float = clampf((x / maxf(bridge_length * 0.5, 0.001) + 1.0) * 0.5, 0.0, 1.0)
	return sin(t * PI) * arch_height


func _build_geometry(gen: int) -> void:
	var root := Node3D.new()
	root.name = "Gen_Bridge"
	_deck_root = root
	_deck_base_y = 0.0

	var half_l: float = bridge_length * 0.5
	var half_w: float = bridge_width * 0.5
	var segments: int = maxi(slab_cols, 8)
	var seg_len: float = bridge_length / float(segments)

	# --- Continuous dark deck (uniform width) ---
	# One structural plate per segment so the arch reads, but same width end-to-end.
	for i in range(segments):
		var x0: float = -half_l + (float(i) + 0.5) * seg_len
		var y_arch: float = _arch_y(x0)
		_mesh_box(
			root,
			"Deck_%d" % i,
			Vector3(seg_len * 1.02, deck_thickness, bridge_width),
			Vector3(x0, y_arch + deck_thickness * 0.5, 0.0),
			_stone
		)

	# Deck kept flat/regular — no raised crack/trim strips on the walkway.

	# Walkable collision — same uniform width, stepped to follow arch
	var body := StaticBody3D.new()
	body.name = "DeckBody"
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)
	for i in range(segments):
		var x0: float = -half_l + (float(i) + 0.5) * seg_len
		var y_arch: float = _arch_y(x0)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(seg_len * 1.02, deck_thickness + 0.1, bridge_width)
		cs.shape = shape
		cs.position = Vector3(x0, y_arch + deck_thickness * 0.5, 0.0)
		body.add_child(cs)

	# --- Low thick parapets: solid curb with intentional missing teeth ---
	# Pattern of present/missing per side so both rails share same outer width.
	var rail_h: float = 0.62
	var rail_t: float = 0.38
	var present_L: Array[bool] = [true, true, false, true, true, true, false, true, false, true, true, true, false, true]
	var present_R: Array[bool] = [true, false, true, true, false, true, true, true, true, false, true, false, true, true]
	while present_L.size() < segments:
		present_L.append(true)
		present_R.append(true)

	for side_i in range(2):
		var side: float = -1.0 if side_i == 0 else 1.0
		var z_rail: float = side * (half_w - rail_t * 0.5)  # flush with deck edge — uniform width
		for i in range(segments):
			var x0: float = -half_l + (float(i) + 0.5) * seg_len
			var y_arch: float = _arch_y(x0)
			# Clear BOTH bridge heads only (桥两头) — keep mid-span dilapidated rails.
			# ~2 segments each end so no lone stubs sit on the landing edge.
			var end_clear: float = seg_len * 2.0
			if x0 < -half_l + end_clear or x0 > half_l - end_clear:
				continue
			var present: bool = present_L[i] if side_i == 0 else present_R[i]
			if not present:
				# Broken tooth: leave a low jagged stump only
				if i % 3 != 1:
					_mesh_box(
						root,
						"RailStub_%d_%d" % [side_i, i],
						Vector3(seg_len * 0.55, rail_h * 0.28, rail_t * 0.9),
						Vector3(x0, y_arch + deck_thickness + rail_h * 0.14, z_rail),
						_stone_dark
					)
				continue
			_mesh_box(
				root,
				"Rail_%d_%d" % [side_i, i],
				Vector3(seg_len * 0.98, rail_h, rail_t),
				Vector3(x0, y_arch + deck_thickness + rail_h * 0.5, z_rail),
				_stone_dark if (i % 4 == 0) else _stone
			)
			# Coping on intact sections
			_mesh_box(
				root,
				"Coping_%d_%d" % [side_i, i],
				Vector3(seg_len * 0.92, 0.1, rail_t * 1.15),
				Vector3(x0, y_arch + deck_thickness + rail_h + 0.05, z_rail),
				_moss if (i % 5 == 2) else _stone_dark
			)

	# Center support pillar into the mist
	var pillar := Node3D.new()
	pillar.name = "CenterPillar"
	pillar.position = Vector3(0.0, -6.0, 0.0)
	root.add_child(pillar)
	_mesh_box(pillar, "Shaft", Vector3(1.5, 12.0, 1.5), Vector3(0, 0, 0), _stone_dark)
	_mesh_box(pillar, "Cap", Vector3(2.2, 0.45, 2.2), Vector3(0, 6.15, 0), _stone)

	# End supports under the deck only — same width as heads, nothing raised above the walkway.
	for end_i in range(2):
		var end_sign: float = -1.0 if end_i == 0 else 1.0
		var x_end: float = end_sign * half_l
		_mesh_box(root, "Abutment_%d" % end_i, Vector3(1.15, 0.45, bridge_width), Vector3(x_end, -0.1, 0), _stone_dark)
		_mesh_box(root, "Step_%d" % end_i, Vector3(0.7, 0.16, bridge_width), Vector3(x_end - end_sign * 0.45, 0.08, 0), _stone)

	# Mid-span detector
	var area := Area3D.new()
	area.name = "MidspanArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bridge_length * 0.35, 2.5, bridge_width * 0.95)
	acs.shape = box
	acs.position = Vector3(0.0, 1.2 + arch_height * 0.5, 0.0)
	area.add_child(acs)
	root.add_child(area)
	_mid_area = area
	if not Engine.is_editor_hint():
		if not area.body_entered.is_connected(_on_mid_entered):
			area.body_entered.connect(_on_mid_entered)
		if not area.body_exited.is_connected(_on_mid_exited):
			area.body_exited.connect(_on_mid_exited)

	_attach(root, gen)


func _on_mid_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_mid = true
		player_entered_midspan.emit()


func _on_mid_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_mid = false
		player_exited_midspan.emit()
