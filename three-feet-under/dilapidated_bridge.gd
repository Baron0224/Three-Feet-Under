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
@export var bridge_width := 3.4:
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

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _moss: StandardMaterial3D


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
		print("DilapidatedBridge: editor preview len=", bridge_length, " at ", global_position)
	else:
		print("DilapidatedBridge: ready len=", bridge_length, " at ", global_position)


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


func _make_materials() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.34, 0.33, 0.31)
	_stone.roughness = 0.92
	_stone.metallic = 0.02

	_stone_dark = StandardMaterial3D.new()
	_stone_dark.albedo_color = Color(0.18, 0.17, 0.16)
	_stone_dark.roughness = 0.96

	_moss = StandardMaterial3D.new()
	_moss.albedo_color = Color(0.22, 0.32, 0.18)
	_moss.roughness = 1.0


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
	var col_w: float = bridge_length / float(slab_cols)
	var row_d: float = bridge_width / float(slab_rows)

	# Central support pillar into the mist
	var pillar := Node3D.new()
	pillar.name = "CenterPillar"
	pillar.position = Vector3(0.0, -6.0, 0.0)
	root.add_child(pillar)
	_mesh_box(pillar, "Shaft", Vector3(1.4, 12.0, 1.4), Vector3(0, 0, 0), _stone_dark)
	_mesh_box(pillar, "Cap", Vector3(2.0, 0.5, 2.0), Vector3(0, 6.2, 0), _stone)

	# Deck slabs — complete span, uneven / cracked
	for c in range(slab_cols):
		var x0 := -half_l + (float(c) + 0.5) * col_w
		var y_arch := _arch_y(x0)
		for r in range(slab_rows):
			var z0 := -half_w + (float(r) + 0.5) * row_d
			var jitter_y := _rng.randf_range(-0.06, 0.05)
			var tilt := Vector3(
				_rng.randf_range(-3.5, 3.5),
				_rng.randf_range(-2.0, 2.0),
				_rng.randf_range(-4.0, 4.0)
			)
			var sx := col_w * _rng.randf_range(0.88, 0.98)
			var sz := row_d * _rng.randf_range(0.86, 0.98)
			var mat := _stone if _rng.randf() > 0.22 else _stone_dark
			if _rng.randf() < 0.12:
				mat = _moss
			_mesh_box(
				root,
				"Slab_%d_%d" % [c, r],
				Vector3(sx, deck_thickness, sz),
				Vector3(x0 + _rng.randf_range(-0.04, 0.04), y_arch + jitter_y + deck_thickness * 0.5, z0 + _rng.randf_range(-0.03, 0.03)),
				mat,
				tilt
			)
			# Occasional crack scrap
			if _rng.randf() < 0.18:
				_mesh_box(
					root,
					"Crack_%d_%d" % [c, r],
					Vector3(sx * 0.7, 0.03, 0.04),
					Vector3(x0, y_arch + deck_thickness + 0.01, z0 + _rng.randf_range(-sz * 0.3, sz * 0.3)),
					_stone_dark
				)

	# Walkable collision — continuous slightly arched convex approx as stepped boxes
	var body := StaticBody3D.new()
	body.name = "DeckBody"
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)
	for c in range(slab_cols):
		var x0: float = -half_l + (float(c) + 0.5) * col_w
		var y_arch: float = _arch_y(x0)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(col_w * 1.02, deck_thickness + 0.08, bridge_width * 0.95)
		cs.shape = shape
		cs.position = Vector3(x0, y_arch + deck_thickness * 0.5, 0.0)
		body.add_child(cs)

	# Side rails — incomplete / crumbled
	for side_i in range(2):
		var side: float = -1.0 if side_i == 0 else 1.0
		var z_rail: float = side * (half_w + 0.12)
		for c in range(slab_cols):
			# Skip some segments for broken look
			var broken: bool = _rng.randf() < 0.28
			var x0: float = -half_l + (float(c) + 0.5) * col_w
			var y_arch: float = _arch_y(x0)
			if broken:
				# rubble stump
				if _rng.randf() < 0.7:
					_mesh_box(
						root,
						"RailStub_%s_%d" % [side, c],
						Vector3(col_w * 0.45, _rng.randf_range(0.15, 0.4), 0.28),
						Vector3(x0, y_arch + 0.25, z_rail + _rng.randf_range(-0.05, 0.05)),
						_stone_dark,
						Vector3(0, 0, _rng.randf_range(-12, 12))
					)
				continue
			var h: float = _rng.randf_range(0.55, 0.85)
			var rail_mat: Material = _stone if _rng.randf() > 0.3 else _moss
			_mesh_box(
				root,
				"Rail_%s_%d" % [side, c],
				Vector3(col_w * 0.9, h, 0.32),
				Vector3(x0, y_arch + h * 0.5 + 0.05, z_rail),
				rail_mat
			)
			# top coping sometimes missing
			if _rng.randf() > 0.35:
				_mesh_box(
					root,
					"Coping_%s_%d" % [side, c],
					Vector3(col_w * 0.85, 0.12, 0.4),
					Vector3(x0, y_arch + h + 0.1, z_rail),
					_stone_dark
				)

	# End abutments / steps into portals
	for end_i in range(2):
		var end_sign: float = -1.0 if end_i == 0 else 1.0
		var x_end: float = end_sign * half_l
		_mesh_box(root, "Abutment_%s" % end_sign, Vector3(1.2, 1.1, bridge_width + 0.8), Vector3(x_end, 0.35, 0), _stone_dark)
		_mesh_box(root, "Step_%s" % end_sign, Vector3(0.7, 0.22, bridge_width * 0.9), Vector3(x_end - end_sign * 0.55, 0.12, 0), _stone)

	# Mid-span detector for shake / future collapse trigger zone
	var area := Area3D.new()
	area.name = "MidspanArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bridge_length * 0.35, 2.5, bridge_width * 0.9)
	acs.shape = box
	acs.position = Vector3(0.0, 1.2 + arch_height * 0.5, 0.0)
	area.add_child(acs)
	root.add_child(area)
	_mid_area = area
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_mid_entered)
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