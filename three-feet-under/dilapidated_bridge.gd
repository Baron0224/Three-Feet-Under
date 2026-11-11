@tool
extends Node3D

## Dilapidated stone arch across Chasm07 with playable A→B→C collapse:
## A midspan rumble → forward span falls (collision removed);
## B ceiling rope swing (E) / side wooden beam across the gap;
## C safe landing on the far bank.

signal player_entered_midspan
signal player_exited_midspan
signal collapse_requested
signal collapse_finished
signal rope_swing_finished

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
@export var arch_height := 2.0:
	set(v):
		arch_height = clampf(v, 0.0, 2.2)
		_request_rebuild()
@export var deck_thickness := 0.72:
	set(v):
		deck_thickness = clampf(v, 0.4, 1.2)
		_request_rebuild()
@export var enable_midspan_shake := true
@export var shake_amplitude := 0.018
@export var allow_future_collapse := true
## Local-X of the forward span that falls (player approaches from -X / west bank).
@export var collapse_start_x := 0.8:
	set(v):
		collapse_start_x = clampf(v, -8.0, 8.0)
		_request_rebuild()
@export var collapse_end_x := 7.2:
	set(v):
		collapse_end_x = clampf(v, -6.0, 10.0)
		_request_rebuild()
@export var auto_collapse_on_midspan := true
@export var warn_seconds := 1.7
@export var collapse_fall_seconds := 1.35
@export var cam_shake_amp := 0.11
@export var rope_swing_seconds := 1.15
@export var enable_rescue_beam := true
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")

var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0
var _rng := RandomNumberGenerator.new()

var _deck_root: Node3D
var _collapse_root: Node3D
var _mid_area: Area3D
var _rope_area: Area3D
var _rescue_beam_body: StaticBody3D
var _player_on_mid := false
var _shake_t := 0.0
var _deck_base_y := 0.0
var _collapsed := false
var _collapsing := false
var _warn_t := 0.0
var _warning := false
var _swinging := false
var _player: Node3D
var _player_cam: Camera3D
var _cam_base := Vector3.ZERO
var _shake_left := 0.0
var _shake_amp := 0.0
var _prompt: Label
var _rope_prompt_active := false

var _stone: Material
var _stone_dark: Material
var _moss: Material
var _rope_mat: Material
var _wood_mat: Material


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
	if not Engine.is_editor_hint():
		_prompt = _resolve_prompt()
		print("DilapidatedBridge: ready len=", bridge_length, " width=", bridge_width,
			" collapse=[", collapse_start_x, ",", collapse_end_x, "] at ", global_position)
	else:
		print("DilapidatedBridge: editor preview len=", bridge_length, " width=", bridge_width, " at ", global_position)


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


## Playable collapse entry (also used by midspan auto-trigger).
func request_collapse() -> void:
	if not allow_future_collapse:
		return
	if _collapsed or _collapsing or _warning:
		return
	_start_collapse_sequence(true)


func has_collapsed() -> bool:
	return _collapsed


func is_gap_open() -> bool:
	return _collapsed


func _start_collapse_sequence(immediate: bool = false) -> void:
	if _collapsed or _collapsing:
		return
	if immediate:
		_warning = false
		_warn_t = warn_seconds
		_do_collapse()
		return
	_warning = true
	_warn_t = 0.0
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The bridge groans..."
	_begin_cam_shake(cam_shake_amp * 0.55, warn_seconds + 0.2)


func _do_collapse() -> void:
	if _collapsed or _collapsing:
		return
	collapse_requested.emit()
	_collapsing = true
	_warning = false
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The span collapses!"
	_begin_cam_shake(cam_shake_amp, collapse_fall_seconds + 0.35)
	print("DilapidatedBridge: collapsing forward span [", collapse_start_x, ",", collapse_end_x, "]")
	if _collapse_root and is_instance_valid(_collapse_root):
		_disable_bodies(_collapse_root)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_collapse_root, "position:y", _collapse_root.position.y - 22.0, collapse_fall_seconds)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_collapse_root, "rotation_degrees:z", _rng.randf_range(-18.0, 18.0), collapse_fall_seconds)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_collapse_root, "rotation_degrees:x", _rng.randf_range(8.0, 25.0), collapse_fall_seconds)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		if is_instance_valid(_collapse_root):
			_collapse_root.visible = false
	_enable_rescue_beam(true)
	_collapsed = true
	_collapsing = false
	if _prompt:
		_prompt.text = "E Grab the hanging rope"
		_prompt.visible = true
		_rope_prompt_active = true
		_hide_prompt_later(2.4)
	collapse_finished.emit()
	print("DilapidatedBridge: collapse finished — rope/beam ready")


func _disable_bodies(node: Node) -> void:
	if node is StaticBody3D:
		(node as StaticBody3D).collision_layer = 0
		(node as StaticBody3D).collision_mask = 0
	for c in node.get_children():
		_disable_bodies(c)


func _enable_rescue_beam(on: bool) -> void:
	if _rescue_beam_body == null or not is_instance_valid(_rescue_beam_body):
		return
	if not enable_rescue_beam:
		_rescue_beam_body.collision_layer = 0
		_rescue_beam_body.collision_mask = 0
		return
	_rescue_beam_body.collision_layer = 1 if on else 0
	_rescue_beam_body.collision_mask = 1 if on else 0
	_rescue_beam_body.visible = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_cam_shake(delta)
	_update_rope_prompt()
	if not enable_midspan_shake or _deck_root == null:
		pass
	elif _player_on_mid and not _collapsed:
		_shake_t += delta * (9.0 + (12.0 if _warning else 0.0))
		var amp: float = shake_amplitude * (1.0 + (3.5 if _warning else 0.0))
		_deck_root.position.y = _deck_base_y + sin(_shake_t) * amp
		_deck_root.position.z = sin(_shake_t * 1.3) * amp * 0.35
	elif _deck_root:
		_deck_root.position.y = move_toward(_deck_root.position.y, _deck_base_y, delta * 0.08)
		_deck_root.position.z = move_toward(_deck_root.position.z, 0.0, delta * 0.08)

	if _warning and not _collapsed and not _collapsing:
		_warn_t += delta
		if _warn_t >= warn_seconds:
			_do_collapse()


func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Gen_") or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_deck_root = null
	_collapse_root = null
	_mid_area = null
	_rope_area = null
	_rescue_beam_body = null
	_player_on_mid = false
	_collapsed = false
	_collapsing = false
	_warning = false
	_warn_t = 0.0
	_swinging = false
	_rope_prompt_active = false


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
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.28, 0.18, 0.10)
	rm.roughness = 0.92
	_rope_mat = rm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.36, 0.26, 0.14)
	wm.roughness = 0.88
	_wood_mat = wm


func _arch_y(x: float) -> float:
	# Zero grade at both banks; smooth rise and descent without stair steps.
	var t := clampf((x / (bridge_length * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	return 0.15 + arch_height * pow(sin(t * PI), 2.0)


func _arch_slope(x: float) -> float:
	var t := clampf((x / (bridge_length * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	return arch_height * PI / bridge_length * sin(2.0 * PI * t)


# Closed swept bevelled section. Top, arch belly and bevels share positions;
# analytic normals follow the continuous curve. The collision uses THESE triangles.
func _curved_stone(parent: Node3D, label: String, x0: float, x1: float, z0: float, z1: float, low: float, high: float, material: Material, solid: bool, bevel: float = 0.06) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := minf(bevel, minf((z1-z0)*0.24, (high-low)*0.24))
	var section := [Vector2(z0+b,high), Vector2(z1-b,high), Vector2(z1,high-b), Vector2(z1,low+b), Vector2(z1-b,low), Vector2(z0+b,low), Vector2(z0,low+b), Vector2(z0,high-b)]
	var normals := [Vector2(-0.3827,0.9239), Vector2(0.3827,0.9239), Vector2(0.9239,0.3827), Vector2(0.9239,-0.3827), Vector2(0.3827,-0.9239), Vector2(-0.3827,-0.9239), Vector2(-0.9239,-0.3827), Vector2(-0.9239,0.3827)]
	var count := maxi(8, int(ceil((x1-x0)/0.20)))
	for i in count:
		var xa := lerpf(x0,x1,float(i)/count)
		var xb := lerpf(x0,x1,float(i+1)/count)
		for j in 8:
			var k := (j+1)%8
			for corner in [Vector2i(0,j),Vector2i(1,k),Vector2i(0,k),Vector2i(0,j),Vector2i(1,j),Vector2i(1,k)]:
				var x := xa if corner.x == 0 else xb
				var q: Vector2 = section[corner.y]
				var n: Vector2 = normals[corner.y]
				st.set_normal(Vector3(-_arch_slope(x)*n.y,n.y,n.x).normalized())
				st.set_uv(Vector2(x,q.x))
				st.add_vertex(Vector3(x,_arch_y(x)+q.y,q.x))
	# End caps below the bank surface; fan winding faces out along X.
	for end in 2:
		var x := x0 if end == 0 else x1
		for j in range(1,7):
			var order := [0,j+1,j] if end == 0 else [0,j,j+1]
			for index in order:
				var q: Vector2 = section[index]
				st.set_normal(Vector3.LEFT if end == 0 else Vector3.RIGHT)
				st.set_uv(q)
				st.add_vertex(Vector3(x,_arch_y(x)+q.y,q.x))
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Body"
		body.set_meta("surface_type", "stone")
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		parent.add_child(body)


func _build_geometry(gen: int) -> void:
	var root := Node3D.new()
	root.name = "Gen_Bridge"
	_deck_root = root
	_deck_base_y = 0.0
	var half_l := bridge_length * 0.5
	var half_w := bridge_width * 0.5
	var x0 := -half_l
	var x1 := minf(collapse_start_x, collapse_end_x)
	var x2 := maxf(collapse_start_x, collapse_end_x)
	var x3 := half_l
	x1 = clampf(x1, x0 + 1.0, x3 - 2.0)
	x2 = clampf(x2, x1 + 1.5, x3 - 0.8)

	# Permanent west + east decks keep arch continuous before collapse.
	_curved_stone(root, "DeckWest", x0, x1, -half_w, half_w, -deck_thickness, 0.0, _stone, true, 0.07)
	_curved_stone(root, "DeckEast", x2, x3, -half_w, half_w, -deck_thickness, 0.0, _stone, true, 0.07)

	var collapse := Node3D.new()
	collapse.name = "Gen_CollapseSpan"
	root.add_child(collapse)
	_collapse_root = collapse
	_curved_stone(collapse, "DeckCollapse", x1, x2, -half_w, half_w, -deck_thickness, 0.0, _stone, true, 0.07)

	# Continuous arch fascia; parapets stay broken in places.
	for side in [-1.0, 1.0]:
		var edge: float = side * half_w
		var za := minf(edge, edge - side * 0.42)
		var zb := maxf(edge, edge - side * 0.42)
		_curved_stone(root, "FasciaW%s" % side, x0, x1, za, zb, -deck_thickness - 0.12, -deck_thickness, _stone_dark, false, 0.07)
		_curved_stone(collapse, "FasciaC%s" % side, x1, x2, za, zb, -deck_thickness - 0.12, -deck_thickness, _stone_dark, false, 0.07)
		_curved_stone(root, "FasciaE%s" % side, x2, x3, za, zb, -deck_thickness - 0.12, -deck_thickness, _stone_dark, false, 0.07)
		var ranges_w := [Vector2(-8.5, -3.2), Vector2(-2.6, minf(-0.2, x1 - 0.15))]
		var ranges_e := [Vector2(maxf(4.4, x2 + 0.15), 8.5)]
		if side < 0.0:
			ranges_w = [Vector2(-8.5, -3.2), Vector2(-2.6, minf(-0.2, x1 - 0.15))]
			ranges_e = [Vector2(maxf(5.6, x2 + 0.15), 8.5)]
		else:
			ranges_w = [Vector2(-8.5, -1.4), Vector2(-0.8, minf(0.2, x1 - 0.15))]
			ranges_e = [Vector2(maxf(5.6, x2 + 0.15), 8.5)]
		for i in ranges_w.size():
			var span: Vector2 = ranges_w[i]
			if span.y - span.x < 0.4:
				continue
			_curved_stone(root, "ParapetW%s_%s" % [side, i], span.x, span.y, za, zb, 0.0, 0.62, _stone_dark, true, 0.06)
			_curved_stone(root, "CopingW%s_%s" % [side, i], span.x, span.y, za, zb, 0.62, 0.72, _stone, true, 0.04)
		for i in ranges_e.size():
			var span_e: Vector2 = ranges_e[i]
			if span_e.y - span_e.x < 0.4:
				continue
			_curved_stone(root, "ParapetE%s_%s" % [side, i], span_e.x, span_e.y, za, zb, 0.0, 0.62, _stone_dark, true, 0.06)
			_curved_stone(root, "CopingE%s_%s" % [side, i], span_e.x, span_e.y, za, zb, 0.62, 0.72, _stone, true, 0.04)
		# Collapse-span parapet stubs (fall with the deck).
		var c0 := x1 + 0.35
		var c1 := x2 - 0.35
		if c1 > c0 + 0.5:
			_curved_stone(collapse, "ParapetC%s" % side, c0, c1, za, zb, 0.0, 0.62, _stone_dark, true, 0.06)
			_curved_stone(collapse, "CopingC%s" % side, c0, c1, za, zb, 0.62, 0.72, _stone, true, 0.04)

	for sign_x in [-1.0, 1.0]:
		_mesh_box(root, "Abutment%s" % sign_x, Vector3(1.2, 1.5, bridge_width), Vector3(sign_x * (half_l - 0.2), -0.85, 0), _stone_dark)

	_build_rope_and_beam(root, x1, x2, half_w)

	# Mid-span detector (triggers A warning).
	var area := Area3D.new()
	area.name = "MidspanArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bridge_length * 0.28, 2.5, bridge_width * 0.95)
	acs.shape = box
	acs.position = Vector3(-1.0, 1.2 + arch_height * 0.5, 0.0)
	area.add_child(acs)
	root.add_child(area)
	_mid_area = area
	if not Engine.is_editor_hint():
		if not area.body_entered.is_connected(_on_mid_entered):
			area.body_entered.connect(_on_mid_entered)
		if not area.body_exited.is_connected(_on_mid_exited):
			area.body_exited.connect(_on_mid_exited)

	_attach(root, gen)


func _build_rope_and_beam(root: Node3D, x1: float, x2: float, half_w: float) -> void:
	var rope_root := Node3D.new()
	rope_root.name = "Gen_Rope"
	root.add_child(rope_root)

	# Twin hanging ropes + short crossbar (tomb rescue gear aesthetic).
	var mid_x := (x1 + x2) * 0.5
	var crown := _arch_y(mid_x)
	var hang_y := crown + 3.4
	var grab_y := crown + 1.35
	for side_z in [-0.55, 0.55]:
		var rope := MeshInstance3D.new()
		rope.name = "Rope%s" % side_z
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = hang_y - grab_y + 0.2
		rope.mesh = cyl
		rope.material_override = _rope_mat
		rope.position = Vector3(mid_x, (hang_y + grab_y) * 0.5, side_z)
		rope_root.add_child(rope)
		# Ceiling anchors toward each bank.
		for end_x in [x1 + 0.2, x2 - 0.2]:
			var slant := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.035
			sc.bottom_radius = 0.035
			var dx := end_x - mid_x
			var dy := hang_y - (crown + 2.6)
			var length := sqrt(dx * dx + dy * dy)
			sc.height = length
			slant.mesh = sc
			slant.material_override = _rope_mat
			slant.position = Vector3((mid_x + end_x) * 0.5, (hang_y + crown + 2.6) * 0.5, side_z)
			var angle := atan2(dx, -dy)
			slant.rotation = Vector3(0.0, 0.0, -angle)
			rope_root.add_child(slant)

	_mesh_box(rope_root, "RopeBar", Vector3(0.12, 0.12, 1.35), Vector3(mid_x, grab_y, 0.0), _wood_mat)

	# Interact volume near west lip of the gap (after collapse).
	var rarea := Area3D.new()
	rarea.name = "RopeInteract"
	rarea.collision_layer = 0
	rarea.collision_mask = 1
	rarea.monitoring = true
	rarea.monitorable = false
	var rcs := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(2.4, 2.8, 3.2)
	rcs.shape = rbox
	rcs.position = Vector3(x1 - 0.15, grab_y, 0.0)
	rarea.position = Vector3.ZERO
	rarea.add_child(rcs)
	rope_root.add_child(rarea)
	_rope_area = rarea
	if not Engine.is_editor_hint():
		if not rarea.body_entered.is_connected(_on_rope_entered):
			rarea.body_entered.connect(_on_rope_entered)
		if not rarea.body_exited.is_connected(_on_rope_exited):
			rarea.body_exited.connect(_on_rope_exited)

	# Side wooden rescue beam — collision off until collapse (B alternate).
	var beam_z := -half_w + 1.05
	var beam_parent := Node3D.new()
	beam_parent.name = "Gen_RescueBeam"
	root.add_child(beam_parent)
	var segs := 10
	for i in segs:
		var xa := lerpf(x1 - 0.15, x2 + 0.15, float(i) / segs)
		var xb := lerpf(x1 - 0.15, x2 + 0.15, float(i + 1) / segs)
		var ya := _arch_y(xa) + 0.08
		var yb := _arch_y(xb) + 0.08
		var cx := (xa + xb) * 0.5
		var cy := (ya + yb) * 0.5
		var length := absf(xb - xa)
		var mi := _mesh_box(beam_parent, "BeamSeg%s" % i, Vector3(length, 0.16, 0.48), Vector3(cx, cy, beam_z), _wood_mat)
		mi.rotation_degrees.z = rad_to_deg(atan2(yb - ya, xb - xa))
	var body := StaticBody3D.new()
	body.name = "RescueBeamBody"
	body.set_meta("surface_type", "wood")
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3((x2 - x1) + 0.5, 0.22, 0.55)
	shape.shape = bshape
	shape.position = Vector3((x1 + x2) * 0.5, _arch_y(mid_x) + 0.08, beam_z)
	body.add_child(shape)
	beam_parent.add_child(body)
	_rescue_beam_body = body
	# Keep beam visible but slightly dim until usable (still present as foreshadowing).


func _on_mid_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_on_mid = true
	_player = body as Node3D
	_bind_camera(_player)
	player_entered_midspan.emit()
	if Engine.is_editor_hint():
		return
	if auto_collapse_on_midspan and allow_future_collapse and not _collapsed and not _collapsing and not _warning:
		_start_collapse_sequence(false)


func _on_mid_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_mid = false
		player_exited_midspan.emit()


func _on_rope_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player = body as Node3D
	if _collapsed and not _swinging:
		_rope_prompt_active = true
		if _prompt:
			_prompt.visible = true
			_prompt.text = "E Grab the hanging rope"


func _on_rope_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _prompt and _rope_prompt_active and str(_prompt.text).begins_with("E Grab"):
		_prompt.visible = false
	_rope_prompt_active = false


func _update_rope_prompt() -> void:
	if _prompt == null or _player == null or not _collapsed or _swinging:
		return
	if not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if _rope_near():
		_prompt.visible = true
		_prompt.text = "E Grab the hanging rope"
		_rope_prompt_active = true


func _rope_near() -> bool:
	if _rope_area == null or _player == null or not _collapsed:
		return false
	var anchor := _rope_area.global_position
	if _rope_area.get_child_count() > 0 and _rope_area.get_child(0) is CollisionShape3D:
		anchor = (_rope_area.get_child(0) as CollisionShape3D).global_position
	var offset := _player.global_position - anchor
	offset.y = 0.0
	return offset.length() <= 2.6


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _swinging or not _collapsed:
		return
	if _player == null or not (_player.has_method("can_interact") and _player.can_interact()):
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _rope_near():
		_start_rope_swing(_player as CharacterBody3D)
		get_viewport().set_input_as_handled()


func _start_rope_swing(player: CharacterBody3D) -> void:
	if player == null or _swinging or not _collapsed:
		return
	_swinging = true
	_rope_prompt_active = false
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Swinging across..."
	_bind_camera(player)
	# Lock locomotion the same way tablet reading does.
	var was_reading: bool = player.is_reading
	player.is_reading = true
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)

	var half_l := bridge_length * 0.5
	var x1 := minf(collapse_start_x, collapse_end_x)
	var x2 := maxf(collapse_start_x, collapse_end_x)
	x1 = clampf(x1, -half_l + 1.0, half_l - 2.0)
	x2 = clampf(x2, x1 + 1.5, half_l - 0.8)
	var start := to_global(Vector3(x1 - 0.35, _arch_y(x1 - 0.35) + 0.95, 0.0))
	var end := to_global(Vector3(x2 + 0.55, _arch_y(x2 + 0.55) + 0.95, 0.0))
	var mid := to_global(Vector3((x1 + x2) * 0.5, _arch_y((x1 + x2) * 0.5) + 2.35, 0.0))
	player.global_position = start

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(player):
			return
		# Quadratic Bezier through the hanging bar.
		var a: Vector3 = start.lerp(mid, t)
		var b: Vector3 = mid.lerp(end, t)
		player.global_position = a.lerp(b, t)
		player.velocity = Vector3.ZERO
	, 0.0, 1.0, rope_swing_seconds)
	await tw.finished

	if is_instance_valid(player):
		player.global_position = end
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
		player.is_reading = was_reading
	_swinging = false
	if _prompt:
		_prompt.text = "Far bank reached."
		_hide_prompt_later(1.4)
	rope_swing_finished.emit()
	print("DilapidatedBridge: rope swing complete → far bank")


func _bind_camera(p: Node3D) -> void:
	if p == null:
		return
	var cam := p.get_node_or_null("Camera3D")
	if cam is Camera3D:
		_player_cam = cam
		_cam_base = cam.position


func _begin_cam_shake(amp: float, seconds: float) -> void:
	_shake_amp = amp
	_shake_left = maxf(_shake_left, seconds)


func _update_cam_shake(delta: float) -> void:
	if _shake_left <= 0.0 or _player_cam == null or not is_instance_valid(_player_cam):
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var damp := clampf(_shake_left / 0.6, 0.0, 1.0)
	var a := _shake_amp * (0.35 + 0.65 * damp)
	_player_cam.position = _cam_base + Vector3(
		_rng.randf_range(-a, a),
		_rng.randf_range(-a * 0.6, a * 0.6),
		_rng.randf_range(-a * 0.4, a * 0.4)
	)
	if _shake_left <= 0.0:
		_player_cam.position = _cam_base


func _hide_prompt_later(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _prompt and not _rope_near():
		_prompt.visible = false
