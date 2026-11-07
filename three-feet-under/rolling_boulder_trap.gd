@tool
extends Node3D

## West Corridor05 Floor003 rolling boulder trap.
## One sideways-sliding ceiling hatch -> boulder drops -> rolls E->W -> blocks west corner.
## Must sit under unscaled tomb_corridor root (WestWing is x1.5).

@export var corridor_width := 4.5
@export var boulder_radius := 1.75
@export var ceiling_height := 4.8
@export var hatch_length := 5.5
@export var hatch_width := 4.3
@export var panel_thickness := 0.18
@export var drop_local_x := 0.0
@export var rest_local_x := -26.5
@export var trigger_local_x := 0.0
@export var trigger_size := Vector3(4.0, 2.4, 4.0)
@export var slide_distance := 4.6
@export var slide_seconds := 0.55
@export var drop_delay := 0.08
@export var fall_seconds := 0.55
@export var roll_speed := 12.0
@export var roll_spin_deg := 240.0
@export var shake_drop_amp := 0.16
@export var shake_roll_amp := 0.08
@export var shake_drop_seconds := 0.6
@export var respawn_path: NodePath = NodePath("../BoulderTrapRespawn")
@export var prompt_path: NodePath
@export var respawn_cooldown := 0.9
@export var disable_ceiling_path: NodePath = NodePath("../WestWing/Corridor05/Ceiling003")

var _triggered := false
var _sliding := false
var _slide_t := 0.0
var _dropping := false
var _drop_t := 0.0
var _rolling := false
var _resting := false
var _respawn_busy := false
var _shake_left := 0.0
var _shake_amp := 0.0
var _player: Node3D
var _player_cam: Camera3D
var _cam_base := Vector3.ZERO
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _trigger: Area3D
var _hatch: Node3D
var _hatch_body: StaticBody3D
var _hatch_base := Vector3.ZERO
var _boulder: Node3D
var _boulder_mesh: Node3D
var _boulder_kill: Area3D
var _boulder_block: StaticBody3D
var _boulder_start := Vector3.ZERO
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
	_rebuild_queued = false
	_boot_done = true
	if not is_inside_tree():
		return
	_rebuild_geometry()
	if not Engine.is_editor_hint():
		_prompt = _resolve_prompt()
		_patch_overlapping_ceiling()
		print("RollingBoulderTrap: ready at ", global_position, " drop=", drop_local_x, " rest=", rest_local_x)


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
	if floor_mat is Material:
		_panel_mat = floor_mat
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.37, 0.35, 0.30)
		sm.roughness = 0.95
		_panel_mat = sm
	var rock_mat := load("res://art/materials/rock.tres")
	if rock_mat is Material:
		_boulder_mat = rock_mat
	else:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.42, 0.38, 0.34)
		bm.roughness = 0.92
		_boulder_mat = bm


func _clear_generated() -> void:
	for c in get_children():
		var n := String(c.name)
		if n in ["TriggerArea", "HatchPanel", "Boulder", "CeilingFillWest", "CeilingFillEast"] or n.ends_with("_old"):
			c.name = n + "_old"
			remove_child(c)
			c.queue_free()
	_trigger = null
	_hatch = null
	_hatch_body = null
	_boulder = null
	_boulder_mesh = null
	_boulder_kill = null
	_boulder_block = null


func _rebuild_geometry() -> void:
	if not is_inside_tree():
		return
	_build_gen += 1
	var gen := _build_gen
	_clear_generated()
	_make_materials()
	_build_geometry(gen)
	if not Engine.is_editor_hint():
		call_deferred("_connect_runtime_signals")


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
	add_child(node)


func _build_geometry(gen: int) -> void:
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

	var west_end := minf(rest_local_x, drop_x) - boulder_radius - 0.5
	var east_end := maxf(drop_x, 0.0) + hatch_half + 1.5
	_attach(_make_fill("CeilingFillWest", west_end, drop_x - hatch_half, hatch_y), gen)
	_attach(_make_fill("CeilingFillEast", drop_x + hatch_half, east_end, hatch_y), gen)

	# Single horizontal sliding hatch (slides +Z into north wall recess).
	_hatch = Node3D.new()
	_hatch.name = "HatchPanel"
	_hatch_base = Vector3(drop_x, hatch_y, 0.0)
	_hatch.position = _hatch_base
	var size := Vector3(hatch_length, panel_thickness, hatch_width)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _panel_mat
	_hatch.add_child(mi)
	_hatch_body = StaticBody3D.new()
	_hatch_body.name = "StaticBody3D"
	_hatch_body.collision_layer = 1
	_hatch_body.collision_mask = 1
	var hcs := CollisionShape3D.new()
	var hsh := BoxShape3D.new()
	hsh.size = size
	hcs.shape = hsh
	_hatch_body.add_child(hcs)
	_hatch.add_child(_hatch_body)
	_attach(_hatch, gen)

	_boulder = Node3D.new()
	_boulder.name = "Boulder"
	_boulder_start = Vector3(drop_x, hatch_y + boulder_radius + 0.25, 0.0)
	_boulder.position = _boulder_start
	_boulder.visible = true

	_boulder_mesh = MeshInstance3D.new()
	_boulder_mesh.name = "Mesh"
	var sphere := SphereMesh.new()
	sphere.radius = boulder_radius
	sphere.height = boulder_radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	(_boulder_mesh as MeshInstance3D).mesh = sphere
	(_boulder_mesh as MeshInstance3D).material_override = _boulder_mat
	_boulder.add_child(_boulder_mesh)

	_boulder_kill = Area3D.new()
	_boulder_kill.name = "KillArea"
	_configure_area(_boulder_kill)
	_boulder_kill.monitoring = false
	var kcs := CollisionShape3D.new()
	var ksh := SphereShape3D.new()
	ksh.radius = boulder_radius * 1.08
	kcs.shape = ksh
	_boulder_kill.add_child(kcs)
	_boulder.add_child(_boulder_kill)

	_boulder_block = StaticBody3D.new()
	_boulder_block.name = "BlockBody"
	_boulder_block.collision_layer = 0
	_boulder_block.collision_mask = 0
	var bcs := CollisionShape3D.new()
	var bsh := SphereShape3D.new()
	bsh.radius = boulder_radius
	bcs.shape = bsh
	_boulder_block.add_child(bcs)
	_boulder.add_child(_boulder_block)
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


func _connect_runtime_signals() -> void:
	if Engine.is_editor_hint():
		return
	if _trigger:
		if not _trigger.body_entered.is_connected(_on_trigger):
			_trigger.body_entered.connect(_on_trigger)
		_trigger.monitoring = true
	if _boulder_kill and not _boulder_kill.body_entered.is_connected(_on_boulder_hit):
		_boulder_kill.body_entered.connect(_on_boulder_hit)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _triggered and _trigger != null and _trigger.monitoring:
		for body in _trigger.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_trigger(body)
				break

	if _sliding and is_instance_valid(_hatch):
		_slide_t = move_toward(_slide_t, 1.0, delta / maxf(slide_seconds, 0.05))
		var z := lerpf(0.0, slide_distance, _slide_t)
		_hatch.position = _hatch_base + Vector3(0.0, 0.0, z)
		if _slide_t >= 1.0:
			_sliding = false
			if _hatch_body:
				_hatch_body.collision_layer = 0
				_hatch_body.collision_mask = 0
			if _prompt:
				_prompt.text = "Boulder!"
			_begin_drop()

	if _dropping and is_instance_valid(_boulder):
		_drop_t = move_toward(_drop_t, 1.0, delta / maxf(fall_seconds, 0.05))
		var floor_y := boulder_radius + 0.02
		var y := lerpf(_boulder_start.y, floor_y, _ease_in(_drop_t))
		_boulder.position = Vector3(drop_local_x, y, 0.0)
		_boulder_mesh.rotate_z(deg_to_rad(roll_spin_deg * 0.4) * delta)
		if _drop_t >= 1.0:
			_dropping = false
			_boulder.position = Vector3(drop_local_x, floor_y, 0.0)
			_rolling = true
			_begin_shake(shake_roll_amp, 2.8)
			if _prompt:
				_prompt.text = "Run!"
			print("RollingBoulderTrap: rolling start")

	if _rolling and is_instance_valid(_boulder):
		var pos := _boulder.position
		var dir := -1.0 if rest_local_x < drop_local_x else 1.0
		pos.x = move_toward(pos.x, rest_local_x, roll_speed * delta)
		pos.y = boulder_radius + 0.02
		pos.z = 0.0
		_boulder.position = pos
		_boulder_mesh.rotate_z(deg_to_rad(roll_spin_deg) * delta * dir)
		_begin_shake(shake_roll_amp, 0.25)
		if absf(pos.x - rest_local_x) <= 0.05:
			_rolling = false
			_resting = true
			_boulder.position = Vector3(rest_local_x, boulder_radius + 0.02, 0.0)
			if _boulder_block:
				_boulder_block.collision_layer = 1
				_boulder_block.collision_mask = 1
			if _boulder_kill:
				_boulder_kill.monitoring = false
			_begin_shake(shake_drop_amp * 0.5, 0.4)
			if _prompt:
				_prompt.text = "Path sealed."
				_hide_prompt_later(1.2)
			print("RollingBoulderTrap: resting at ", _boulder.global_position)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shake_left > 0.0 and _player_cam and is_instance_valid(_player_cam):
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


func _ease_in(t: float) -> float:
	return t * t


func _on_trigger(body: Node) -> void:
	if Engine.is_editor_hint() or _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_player = body as Node3D
	_bind_camera(_player)
	print("RollingBoulderTrap: triggered at ", _player.global_position)
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The ceiling slides open..."
	_sliding = true
	_slide_t = 0.0
	_begin_shake(shake_drop_amp * 0.7, slide_seconds + 0.2)


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


func _begin_drop() -> void:
	await get_tree().create_timer(drop_delay).timeout
	if not is_instance_valid(_boulder):
		return
	_dropping = true
	_drop_t = 0.0
	_boulder.visible = true
	if _boulder_kill:
		_boulder_kill.monitoring = true
	_begin_shake(shake_drop_amp, shake_drop_seconds)
	print("RollingBoulderTrap: dropping")


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
	_respawn_busy = false
