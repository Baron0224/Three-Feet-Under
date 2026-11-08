@tool
extends Node3D

## Dilapidated but complete stone bridge across Chasm07 (深渊断桥).
## Continuous bevelled stone arch, matching triangular collision and broken parapets.
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
	_curved_stone(root,"Deck",-half_l,half_l,-half_w,half_w,-deck_thickness,0.0,_stone,true,0.07)
	# Continuous arch fascia defines the load-bearing belly; narrow coping has a rounded arris.
	for side in [-1.0,1.0]:
		var edge: float = side*half_w
		var za := minf(edge, edge-side*0.42)
		var zb := maxf(edge, edge-side*0.42)
		_curved_stone(root,"Fascia%s" % side,-half_l,half_l,za,zb,-deck_thickness-0.12,-deck_thickness,_stone_dark,false,0.07)
		# Leave bank approaches clear; small missing lengths affect only parapets.
		var ranges := [Vector2(-8.5,-3.2),Vector2(-2.6,3.8),Vector2(4.4,8.5)] if side < 0 else [Vector2(-8.5,-1.4),Vector2(-0.8,5.0),Vector2(5.6,8.5)]
		for i in ranges.size():
			var span: Vector2 = ranges[i]
			_curved_stone(root,"Parapet%s_%s" % [side,i],span.x,span.y,za,zb,0.0,0.62,_stone_dark,true,0.06)
			_curved_stone(root,"Coping%s_%s" % [side,i],span.x,span.y,za,zb,0.62,0.72,_stone,true,0.04)
	for sign_x in [-1.0,1.0]:
		_mesh_box(root,"Abutment%s" % sign_x,Vector3(1.2,1.5,bridge_width),Vector3(sign_x*(half_l-0.2),-0.85,0),_stone_dark)

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
