@tool
extends Node3D

## Cascading trap_floor-style pit traps along an east-west corridor.
## Mid trigger -> shake closed panels -> segments open +X to -X (slow then fast).
## Each segment: north/south panels swing open, pit + spikes underneath.
## @tool builds meshes in the editor so the trap is visible without Play.
## Must live under an unscaled parent (Jolt Area3D breaks under scaled ancestors).
##
## Geometry build rules (Godot 4.x busy-parent):
## - Never add_child onto an in-tree node while it/ancestors are still setting up.
## - Fully construct each subtree OFF the tree, then attach once via call_deferred.
## - Wait two process frames after load before the first rebuild.

@export var corridor_length := 39.0:
	set(v):
		corridor_length = v
		_request_rebuild()

@export var corridor_width := 4.5:
	set(v):
		corridor_width = v
		_request_rebuild()

@export var floor_thickness := 0.14:
	set(v):
		floor_thickness = v
		_request_rebuild()

@export var segment_count := 12:
	set(v):
		segment_count = maxi(1, v)
		_request_rebuild()

@export var shake_seconds := 0.85
@export var shake_amplitude := 0.05

@export var first_segment_delay := 0.28
@export var last_segment_delay := 0.05

@export var open_degrees := 110.0
@export var open_speed := 120.0
@export var fall_respawn_delay := 1.4
@export var pit_y := -1.5
@export var pit_depth := -1.25

@export var respawn_path: NodePath = NodePath("../SpikeTrapRespawn")
@export var prompt_path: NodePath
@export var cascade_from_positive_x := true
@export var respawn_cooldown := 0.9
@export var show_debug_label := false:
	set(v):
		show_debug_label = v
		_request_rebuild()

var _triggered := false
var _shaking := false
var _shake_left := 0.0
var _cascading := false
var _respawn_busy := false
var _player: Node3D
var _built := false
var _rebuild_queued := false
var _boot_done := false
var _build_gen := 0

var _trigger: Area3D
var _segments: Array[Dictionary] = []
var _prompt: Label
var _rng := RandomNumberGenerator.new()
var _panel_mat: Material
var _spike_mat: StandardMaterial3D
var _pit_mat: StandardMaterial3D
var _seam_mat: Material


func _ready() -> void:
	_rng.randomize()
	# Do not build here - parent tomb_corridor may still be busy setting up children.
	_request_rebuild(true)


func _notification(what: int) -> void:
	# Generated meshes are not saved into the packed scene; never rebuild on save.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		return
	if what == NOTIFICATION_ENTER_TREE and Engine.is_editor_hint():
		_request_rebuild(true)


func _request_rebuild(from_boot: bool = false) -> void:
	if not is_inside_tree():
		return
	# During packed-scene property apply, export setters fire early - coalesce only.
	if _rebuild_queued:
		return
	_rebuild_queued = true
	if from_boot or not _boot_done:
		call_deferred("_boot_rebuild_async")
	else:
		call_deferred("_rebuild_async_idle")


func _boot_rebuild_async() -> void:
	# Two idle frames: let tomb_corridor finish add_child of siblings/instances.
	await get_tree().process_frame
	await get_tree().process_frame
	_rebuild_queued = false
	_boot_done = true
	if not is_inside_tree():
		return
	_rebuild_geometry()
	if Engine.is_editor_hint():
		print("SpikeCascadeTrap: editor preview at ", global_position, " size ", corridor_length, "x", corridor_width)
	else:
		_prompt = _resolve_prompt()
		print("SpikeCascadeTrap: ready at ", global_position, " size ", corridor_length, "x", corridor_width)


func _rebuild_async_idle() -> void:
	await get_tree().process_frame
	_rebuild_queued = false
	if not is_inside_tree():
		return
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


func _make_materials() -> void:
	var floor_mat := load("res://art/materials/floor.tres")
	if floor_mat is Material:
		_panel_mat = floor_mat
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.37, 0.35, 0.30)
		sm.roughness = 0.95
		_panel_mat = sm

	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color(0.37, 0.35, 0.30, 0.0)
	seam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	seam.roughness = 0.95
	_seam_mat = seam

	_spike_mat = StandardMaterial3D.new()
	# Rusty iron: orange-brown oxide, rough, little chrome.
	_spike_mat.albedo_color = Color(0.52, 0.26, 0.12)
	_spike_mat.metallic = 0.22
	_spike_mat.roughness = 0.82

	_pit_mat = StandardMaterial3D.new()
	_pit_mat.albedo_color = Color(0.12, 0.10, 0.09)
	_pit_mat.roughness = 1.0


func _clear_generated() -> void:
	var to_free: Array[Node] = []
	for c in get_children():
		var n := String(c.name)
		if n == "TriggerArea" or n == "CenterSeam" or n == "DebugTag" or n.begins_with("PitSegment_"):
			to_free.append(c)
		elif n.ends_with("_old"):
			to_free.append(c)
	for c in to_free:
		c.name = String(c.name) + "_old"
		remove_child(c)
		c.queue_free()
	_segments.clear()
	_trigger = null
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


func _connect_runtime_signals() -> void:
	if Engine.is_editor_hint():
		return
	if _trigger:
		if not _trigger.body_entered.is_connected(_on_mid_trigger):
			_trigger.body_entered.connect(_on_mid_trigger)
		_trigger.set_deferred("monitoring", true)
	for seg in _segments:
		var pit: Node = seg["root"].get_node_or_null("Pit")
		if pit == null:
			continue
		var spike_area := pit.get_node_or_null("SpikeArea")
		if spike_area is Area3D and not spike_area.body_entered.is_connected(_on_spike_entered):
			spike_area.body_entered.connect(_on_spike_entered)


func _configure_area(area: Area3D) -> void:
	area.collision_layer = 1
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false


func _attach_root_child(node: Node, gen: int) -> void:
	# Always defer attaching onto this in-tree trap root.
	call_deferred("_attach_root_child_now", node, gen)


func _attach_root_child_now(node: Node, gen: int) -> void:
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
	# Parent scene can still be busy after boot frames on large tomb_corridor.
	add_child.call_deferred(node)


func _build_geometry(gen: int) -> void:
	var half_len := corridor_length * 0.5
	var seg_len := corridor_length / float(maxi(segment_count, 1))
	var half_w := corridor_width * 0.5
	var half_panel_z := half_w
	var panel_y := 0.06

	# Build TriggerArea fully offline, then deferred-attach.
	_trigger = Area3D.new()
	_trigger.name = "TriggerArea"
	_configure_area(_trigger)
	var trigger_cs := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(
		maxf(3.0, corridor_length * 0.5),
		2.2,
		corridor_width
	)
	trigger_cs.shape = trigger_shape
	trigger_cs.position = Vector3(0.0, 1.1, 0.0)
	_trigger.add_child(trigger_cs)
	if Engine.is_editor_hint():
		_trigger.monitoring = false
	else:
		_trigger.monitoring = false  # enabled deferred in _connect_runtime_signals
	_attach_root_child(_trigger, gen)

	var seam := MeshInstance3D.new()
	seam.name = "CenterSeam"
	seam.visible = false
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(corridor_length * 0.98, 0.01, 0.01)
	seam.mesh = seam_mesh
	seam.material_override = _seam_mat
	seam.position = Vector3(0.0, panel_y + floor_thickness * 0.5 + 0.006, 0.0)
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach_root_child(seam, gen)

	if show_debug_label:
		var tag := Label3D.new()
		tag.name = "DebugTag"
		tag.text = "地刺陷阱 PIT TRAP"
		tag.font_size = 72
		tag.modulate = Color(1.0, 0.85, 0.15)
		tag.outline_modulate = Color(0, 0, 0, 1)
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0.0, 2.0, 0.0)
		_attach_root_child(tag, gen)

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.07
	spike_mesh.height = 1.05
	spike_mesh.radial_segments = 7
	spike_mesh.material = _spike_mat

	for i in range(segment_count):
		var x: float
		if cascade_from_positive_x:
			x = half_len - seg_len * (float(i) + 0.5)
		else:
			x = -half_len + seg_len * (float(i) + 0.5)

		# CRITICAL: finish the entire segment subtree OFF the tree, then attach once.
		var seg := Node3D.new()
		seg.name = "PitSegment_%02d" % i
		seg.position = Vector3(x, panel_y, 0.0)

		var south := Node3D.new()
		south.name = "SouthPanel"
		south.position = Vector3(0.0, 0.0, -half_w)
		seg.add_child(south)
		_add_panel_half(south, Vector3(0.0, 0.0, half_panel_z * 0.5), Vector3(seg_len * 0.98, floor_thickness, half_panel_z))

		var north := Node3D.new()
		north.name = "NorthPanel"
		north.position = Vector3(0.0, 0.0, half_w)
		seg.add_child(north)
		_add_panel_half(north, Vector3(0.0, 0.0, -half_panel_z * 0.5), Vector3(seg_len * 0.98, floor_thickness, half_panel_z))

		var south_body: StaticBody3D = south.get_node("StaticBody3D")
		var north_body: StaticBody3D = north.get_node("StaticBody3D")

		var pit := Node3D.new()
		pit.name = "Pit"
		pit.position = Vector3(0.0, pit_depth - panel_y, 0.0)
		seg.add_child(pit)

		var pit_floor := MeshInstance3D.new()
		pit_floor.name = "PitFloor"
		var pit_box := BoxMesh.new()
		pit_box.size = Vector3(seg_len * 0.98, 0.05, corridor_width * 0.98)
		pit_floor.mesh = pit_box
		pit_floor.material_override = _pit_mat
		pit.add_child(pit_floor)

		var spike_area := Area3D.new()
		spike_area.name = "SpikeArea"
		_configure_area(spike_area)
		if Engine.is_editor_hint():
			spike_area.monitoring = false
		var spike_cs := CollisionShape3D.new()
		var spike_shape := BoxShape3D.new()
		spike_shape.size = Vector3(seg_len * 0.95, 0.9, corridor_width * 0.95)
		spike_cs.shape = spike_shape
		spike_cs.position = Vector3(0.0, 0.45, 0.0)
		spike_area.add_child(spike_cs)
		pit.add_child(spike_area)

		var rows_x := 4
		var rows_z := 5
		var spike_i := 0
		for ix in range(rows_x):
			for iz in range(rows_z):
				var u := (float(ix) + 0.5) / float(rows_x)
				var v := (float(iz) + 0.5) / float(rows_z)
				var base_x := lerpf(-seg_len * 0.38, seg_len * 0.38, u)
				var base_z := lerpf(-corridor_width * 0.38, corridor_width * 0.38, v)
				var jx := _rng.randf_range(-seg_len * 0.07, seg_len * 0.07)
				var jz := _rng.randf_range(-corridor_width * 0.07, corridor_width * 0.07)
				var spike := MeshInstance3D.new()
				spike.name = "Spike_%d" % spike_i
				spike.mesh = spike_mesh
				var tall := _rng.randf_range(0.88, 1.18)
				var thin := _rng.randf_range(0.75, 1.05)
				spike.scale = Vector3(thin, tall, thin)
				spike.position = Vector3(base_x + jx, 0.42 * tall, base_z + jz)
				spike.rotation = Vector3(
					_rng.randf_range(-0.12, 0.12),
					_rng.randf_range(0.0, TAU),
					_rng.randf_range(-0.12, 0.12)
				)
				pit.add_child(spike)
				spike_i += 1

		_segments.append({
			"root": seg,
			"south": south,
			"north": north,
			"south_body": south_body,
			"north_body": north_body,
			"base_pos": seg.position,
			"opening": false,
			"opened": false,
			"open_t": 0.0,
		})
		# Attach only after the full segment tree exists offline.
		_attach_root_child(seg, gen)


func _add_panel_half(hinge: Node3D, mesh_pos: Vector3, size: Vector3) -> void:
	# hinge is guaranteed off-tree here; direct add_child is safe.
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
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


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _triggered or _trigger == null:
		return
	if not _trigger.monitoring:
		return
	for body in _trigger.get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_mid_trigger(body)
			return


func _on_mid_trigger(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_player = body as Node3D
	print("SpikeCascadeTrap: triggered by ", body.name, " at ", (body as Node3D).global_position)
	push_warning("SpikeCascadeTrap: triggered (pit cascade)")
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The floor trembles..."
	_start_shake_then_cascade()


func _start_shake_then_cascade() -> void:
	_shaking = true
	_shake_left = shake_seconds
	await get_tree().create_timer(shake_seconds).timeout
	_shaking = false
	for info in _segments:
		var root: Node3D = info["root"]
		if is_instance_valid(root):
			root.position = info["base_pos"]
	if _prompt:
		_prompt.text = "Floor opens!"
	_cascading = true
	await _run_cascade()


func _run_cascade() -> void:
	for i in range(_segments.size()):
		var t := float(i) / float(maxi(_segments.size() - 1, 1))
		var delay := lerpf(first_segment_delay, last_segment_delay, t)
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		_begin_segment_open(i)
		print("SpikeCascadeTrap: opening segment ", i)
	var open_time := open_degrees / maxf(open_speed, 1.0)
	await get_tree().create_timer(open_time + 0.2).timeout
	_cascading = false
	if _prompt and not _respawn_busy:
		_prompt.visible = false


func _begin_segment_open(index: int) -> void:
	if index < 0 or index >= _segments.size():
		return
	var info: Dictionary = _segments[index]
	if info["opened"] or info["opening"]:
		return
	info["opening"] = true
	info["open_t"] = 0.0
	_segments[index] = info


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shaking:
		_shake_left = maxf(0.0, _shake_left - delta)
		var damp := clampf(_shake_left / maxf(shake_seconds, 0.001), 0.0, 1.0)
		var amp := shake_amplitude * (0.4 + 0.6 * damp)
		for info in _segments:
			if info["opened"] or info["opening"]:
				continue
			var root: Node3D = info["root"]
			if is_instance_valid(root):
				var base: Vector3 = info["base_pos"]
				root.position = base + Vector3(
					_rng.randf_range(-amp, amp),
					_rng.randf_range(0.0, amp * 0.6),
					_rng.randf_range(-amp, amp)
				)

	for i in range(_segments.size()):
		var info: Dictionary = _segments[i]
		if not info["opening"] or info["opened"]:
			continue
		info["open_t"] = move_toward(float(info["open_t"]), 1.0, (open_speed / maxf(open_degrees, 1.0)) * delta)
		var ang := deg_to_rad(open_degrees * float(info["open_t"]))
		var south: Node3D = info["south"]
		var north: Node3D = info["north"]
		if is_instance_valid(south):
			south.rotation.x = ang
		if is_instance_valid(north):
			north.rotation.x = -ang
		if float(info["open_t"]) >= 1.0:
			info["opening"] = false
			info["opened"] = true
			var sb: StaticBody3D = info["south_body"]
			var nb: StaticBody3D = info["north_body"]
			if sb:
				sb.collision_layer = 0
				sb.collision_mask = 0
			if nb:
				nb.collision_layer = 0
				nb.collision_mask = 0
			if _player and is_instance_valid(_player):
				var root: Node3D = info["root"]
				var local_pos := to_local(_player.global_position)
				var seg_len := corridor_length / float(maxi(segment_count, 1))
				if absf(local_pos.x - root.position.x) <= seg_len * 0.55:
					_fall_and_respawn(_player)
		_segments[i] = info

	if _player and is_instance_valid(_player) and _triggered:
		if _player.global_position.y < global_position.y + pit_y:
			_respawn(_player)


func _on_spike_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		_respawn(body)


func _fall_and_respawn(body: Node) -> void:
	await get_tree().create_timer(fall_respawn_delay).timeout
	if is_instance_valid(body):
		_respawn(body)


func _respawn(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if _respawn_busy:
		return
	if not is_instance_valid(body):
		return
	var marker := get_node_or_null(respawn_path)
	if marker == null:
		var scene := get_tree().current_scene
		if scene:
			marker = scene.get_node_or_null("SpikeTrapRespawn")
	if marker == null:
		push_warning("SpikeCascadeTrap: respawn marker missing (%s)" % str(respawn_path))
		return
	_respawn_busy = true
	if body is Node3D:
		body.global_position = marker.global_position
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
	print("SpikeCascadeTrap: respawned to ", marker.global_position)
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Spikes! Sent back."
	await get_tree().create_timer(respawn_cooldown).timeout
	_respawn_busy = false
	if _prompt and not _cascading and not _shaking:
		await get_tree().create_timer(0.4).timeout
		if _prompt and not _cascading:
			_prompt.visible = false
