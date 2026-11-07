@tool
extends Node3D

## West Corridor05 Floor003 rolling boulder: hatch opens, boulder drops+rolls E->W, seals west corner.

@export var corridor_width := 4.5
@export var boulder_radius := 1.75
@export var ceiling_height := 4.8
@export var hatch_length := 5.0
@export var panel_thickness := 0.16
@export var drop_local_x := 0.0
@export var rest_local_x := -28.5
@export var trigger_local_x := -4.5
@export var trigger_size := Vector3(4.5, 2.4, 4.2)
@export var open_degrees := 105.0
@export var open_speed := 140.0
@export var drop_delay := 0.15
@export var fall_speed := 18.0
@export var roll_speed := 11.0
@export var roll_spin_deg := 220.0
@export var shake_drop_amp := 0.14
@export var shake_roll_amp := 0.07
@export var shake_drop_seconds := 0.55
@export var respawn_path: NodePath = NodePath("../BoulderTrapRespawn")
@export var prompt_path: NodePath
@export var respawn_cooldown := 0.9
@export var disable_ceiling_path: NodePath = NodePath("../WestWing/Corridor05/Ceiling003")

var _triggered := false
var _opening := false
var _open_t := 0.0
var _dropping := false
var _rolling := false
var _resting := false
var _respawn_busy := false
var _shake_left := 0.0
var _shake_amp := 0.0
var _player: Node3D
var _player_cam: Camera3D
var _cam_base := Vector3.ZEROvar _built := false
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0
var _trigger: Area3D
var _north_panel: Node3D
var _south_panel: Node3D
var _north_body: StaticBody3D
var _south_body: StaticBody3D
var _boulder: AnimatableBody3D
var _boulder_kill: Area3D
var _prompt: Label
var _rng := RandomNumberGenerator.new()
var _panel_mat: Material
var _boulder_mat: Material
var _ceiling_patched := false

func _ready() -> void:
	_rng.randomize()
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
	_rebuild_queued = false	_boot_done = true
	if not is_inside_tree():
		return
	_rebuild_geometry()
	if not Engine.is_editor_hint():
		_prompt = _resolve_prompt()
		_patch_overlapping_ceiling()
		print("RollingBoulderTrap: ready at ", global_position)

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

func _patch_overlapping_ceiling() -> void:
	if _ceiling_patched or disable_ceiling_path.is_empty():
		return
	var ceil_node := get_node_or_null(disable_ceiling_path)
	if ceil_node == null:
		return
	if ceil_node is VisualInstance3D:
		(ceil_node as VisualInstance3D).visible = false
	var body := ceil_node.get_node_or_null("StaticBody3D")
	if body is StaticBody3D:
		body.collision_layer = 0
		body.collision_mask = 0
	_ceiling_patched = true
func _make_materials() -> void:
	var floor_mat := load("res://art/materials/floor.tres")
	_panel_mat = floor_mat if floor_mat is Material else null
	if _panel_mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.37, 0.35, 0.30)
		sm.roughness = 0.95
		_panel_mat = sm
	var rock_mat := load("res://art/materials/rock.tres")
	_boulder_mat = rock_mat if rock_mat is Material else null
	if _boulder_mat == null:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.42, 0.38, 0.34)
		bm.roughness = 0.92
		_boulder_mat = bm

func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n in ["TriggerArea", "HatchNorth", "HatchSouth", "Boulder", "CeilingFillWest", "CeilingFillEast"] or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_trigger = null
	_north_panel = null
	_south_panel = null
	_north_body = null
	_south_body = null
	_boulder = null
	_boulder_kill = null
	_built = false

func _rebuild_geometry() -> void:
	if not is_inside_tree():
		return
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_make_materials()
	_build_geometry(gen)
	_built = true
	if not Engine.is_editor_hint():
		_connect_runtime_signals()

func _configure_area(area: Area3D) -> void:
	area.collision_layer = 1
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false

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

func _build_geometry(gen: int) -> void:
	var half_w := corridor_width * 0.5
	var hatch_y := ceiling_height
	var drop_x := drop_local_x
	var hatch_half := hatch_length * 0.5

	_trigger = Area3D.new()
	_trigger.name = "TriggerArea"
	_configure_area(_trigger)
	_trigger.position = Vector3(trigger_local_x, trigger_size.y * 0.5, 0.0)
	var tcs := CollisionShape3D.new()
	var tsh := BoxShape3D.new()
	tsh.size = trigger_size
	tcs.shape = tsh
	_trigger.add_child(tcs)
	_trigger.monitoring = false
	_attach(_trigger, gen)

	var west_end := rest_local_x - boulder_radius - 0.4
	var east_end := drop_x + hatch_half + 2.0
	_attach(_make_fill("CeilingFillWest", west_end, drop_x - hatch_half, hatch_y), gen)
	_attach(_make_fill("CeilingFillEast", drop_x + hatch_half, east_end, hatch_y), gen)

	_north_panel = Node3D.new()
	_north_panel.name = "HatchNorth"
	_north_panel.position = Vector3(drop_x, hatch_y, half_w)
	_add_panel(_north_panel, Vector3(0.0, 0.0, -half_w * 0.5), Vector3(hatch_length, panel_thickness, half_w))
	_north_body = _north_panel.get_node("StaticBody3D")
	_attach(_north_panel, gen)

	_south_panel = Node3D.new()
	_south_panel.name = "HatchSouth"
	_south_panel.position = Vector3(drop_x, hatch_y, -half_w)
	_add_panel(_south_panel, Vector3(0.0, 0.0, half_w * 0.5), Vector3(hatch_length, panel_thickness, half_w))
	_south_body = _south_panel.get_node("StaticBody3D")
	_attach(_south_panel, gen)

	_boulder = AnimatableBody3D.new()
	_boulder.name = "Boulder"
	_boulder.sync_to_physics = true
	_boulder.position = Vector3(drop_x, hatch_y + boulder_radius + 0.35, 0.0)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = boulder_radius
	sphere.height = boulder_radius * 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	mesh.mesh = sphere
	mesh.material_override = _boulder_mat
	_boulder.add_child(mesh)
	var bcs := CollisionShape3D.new()
	var bsh := SphereShape3D.new()
	bsh.radius = boulder_radius	bcs.shape = bsh
	_boulder.add_child(bcs)
	_boulder_kill = Area3D.new()
	_boulder_kill.name = "KillArea"
	_configure_area(_boulder_kill)
	var kcs := CollisionShape3D.new()
	var ksh := SphereShape3D.new()
	ksh.radius = boulder_radius * 1.05
	kcs.shape = ksh
	_boulder_kill.add_child(kcs)
	_boulder.add_child(_boulder_kill)
	_boulder.collision_layer = 0
	_boulder.collision_mask = 0
	_boulder_kill.monitoring = false
	_attach(_boulder, gen)

func _make_fill(fill_name: String, x0: float, x1: float, y: float) -> Node3D:
	var root := Node3D.new()
	root.name = fill_name
	var length := absf(x1 - x0)
	if length < 0.05:
		return root
	root.position = Vector3((x0 + x1) * 0.5, y, 0.0)
	var size := Vector3(length, panel_thickness, corridor_width)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _panel_mat
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	return root

func _add_panel(hinge: Node3D, mesh_pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _panel_mat
	mi.position = mesh_pos
	hinge.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = mesh_pos
	body.add_child(cs)
	hinge.add_child(body)

func _connect_runtime_signals() -> void:
	if _trigger and not _trigger.body_entered.is_connected(_on_trigger):
		_trigger.body_entered.connect(_on_trigger)
		_trigger.set_deferred("monitoring", true)
	if _boulder_kill and not _boulder_kill.body_entered.is_connected(_on_boulder_hit):
		_boulder_kill.body_entered.connect(_on_boulder_hit)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _triggered or _trigger == null or not _trigger.monitoring:
		return
	for body in _trigger.get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_trigger(body)
			return

func _on_trigger(body: Node) -> void:
	if Engine.is_editor_hint() or _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_player = body as Node3D
	_bind_camera(_player)
	print("RollingBoulderTrap: triggered")
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The ceiling cracks..."
	_opening = true
	_open_t = 0.0
	_begin_shake(shake_drop_amp, shake_drop_seconds + 0.35)

func _bind_camera(p: Node3D) -> void:
	if p == null:
		return
	var cam := p.get_node_or_null("Camera3D")
	if cam is Camera3D:
		_player_cam = cam
		_cam_base = cam.position

func _begin_shake(amp: float, seconds: float) -> void:
	_shake_amp = amp
	_shake_left = maxf(_shake_left, seconds)

func _hide_prompt_later(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _prompt and _resting:
		_prompt.visible = false

func _start_drop() -> void:
	await get_tree().create_timer(drop_delay).timeout
	if not is_instance_valid(_boulder):
		return
	_dropping = true
	_boulder.collision_layer = 1
	_boulder.collision_mask = 1
	if _boulder_kill:
		_boulder_kill.set_deferred("monitoring", true)
	_begin_shake(shake_drop_amp, shake_drop_seconds)
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shake_left > 0.0 and _player_cam and is_instance_valid(_player_cam):
		_shake_left = maxf(0.0, _shake_left - delta)
		var damp := clampf(_shake_left / 0.6, 0.0, 1.0)
		var a := _shake_amp * (0.35 + 0.65 * damp)
		_player_cam.position = _cam_base + Vector3(_rng.randf_range(-a, a), _rng.randf_range(-a * 0.6, a * 0.6), _rng.randf_range(-a * 0.4, a * 0.4))
		if _shake_left <= 0.0:
			_player_cam.position = _cam_base

	if _opening:
		_open_t = move_toward(_open_t, 1.0, (open_speed / maxf(open_degrees, 1.0)) * delta)
		var ang := deg_to_rad(open_degrees * _open_t)
		if is_instance_valid(_north_panel):
			_north_panel.rotation.x = -ang
		if is_instance_valid(_south_panel):
			_south_panel.rotation.x = ang
		if _open_t >= 1.0:
			_opening = false
			if _north_body:
				_north_body.collision_layer = 0
				_north_body.collision_mask = 0
			if _south_body:
				_south_body.collision_layer = 0
				_south_body.collision_mask = 0
			if _prompt:
				_prompt.text = "Boulder!"
			_start_drop()

	if _dropping and is_instance_valid(_boulder):
		var floor_y := boulder_radius + 0.02
		var pos := _boulder.position
		pos.y = move_toward(pos.y, floor_y, fall_speed * delta)
		pos.x = move_toward(pos.x, drop_local_x, 2.0 * delta)
		_boulder.position = pos
		_boulder.rotation.z += deg_to_rad(roll_spin_deg * 0.35) * delta
		if absf(pos.y - floor_y) <= 0.03:
			_dropping = false
			_boulder.position = Vector3(drop_local_x, floor_y, 0.0)
			_rolling = true
			_begin_shake(shake_roll_amp, 2.5)
			if _prompt:
				_prompt.text = "Run!"

	if _rolling and is_instance_valid(_boulder):
		var pos2 := _boulder.position
		var dir := -1.0 if rest_local_x < drop_local_x else 1.0
		pos2.x = move_toward(pos2.x, rest_local_x, roll_speed * delta)
		pos2.y = boulder_radius + 0.02
		pos2.z = 0.0
		_boulder.position = pos2
		_boulder.rotation.z += deg_to_rad(roll_spin_deg) * delta * dir
		_begin_shake(shake_roll_amp, 0.2)
		if absf(pos2.x - rest_local_x) <= 0.04:
			_rolling = false
			_resting = true
			_boulder.position = Vector3(rest_local_x, boulder_radius + 0.02, 0.0)
			_boulder.collision_layer = 1
			_boulder.collision_mask = 1
			if _boulder_kill:
				_boulder_kill.monitoring = false
			_begin_shake(shake_drop_amp * 0.6, 0.35)
			if _prompt:
				_prompt.text = "Path sealed."
				_hide_prompt_later(1.1)

func _on_boulder_hit(body: Node) -> void:
	if Engine.is_editor_hint() or _resting:
		return
	if not (_dropping or _rolling):
		return
	if body.is_in_group("player"):
		_respawn(body)

func _respawn(body: Node) -> void:
	if Engine.is_editor_hint() or _respawn_busy or not is_instance_valid(body):
		return
	var marker := get_node_or_null(respawn_path)
	if marker == null:
		var scene := get_tree().current_scene
		if scene:
			marker = scene.get_node_or_null("BoulderTrapRespawn")
	if marker == null:
		push_warning("RollingBoulderTrap: respawn marker missing")
		return
	_respawn_busy = true
	if body is Node3D:
		body.global_position = marker.global_position
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
	if _player_cam and is_instance_valid(_player_cam):
		_player_cam.position = _cam_base
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Crushed! Sent back."
	await get_tree().create_timer(respawn_cooldown).timeout
	_respawn_busy = false\n
