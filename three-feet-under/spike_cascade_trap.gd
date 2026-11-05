extends Node3D

## Cascading rising-spike trap for an east-west corridor span.
## Mid trigger -> floor shake -> rows rise from +X (right) to -X (left), slow then fast.

@export var corridor_length := 11.0
@export var corridor_width := 3.0
@export var floor_thickness := 0.2
@export var row_count := 12
@export var spikes_per_row := 3

@export var shake_seconds := 0.85
@export var shake_amplitude := 0.045

@export var first_row_delay := 0.28
@export var last_row_delay := 0.05
@export var spike_rise_time := 0.18
@export var spike_height := 0.9
@export var spike_bottom_radius := 0.15

@export var respawn_path: NodePath
@export var prompt_path: NodePath
@export var cascade_from_positive_x := true
@export var respawn_cooldown := 0.85

var _triggered := false
var _shaking := false
var _shake_left := 0.0
var _cascading := false
var _respawn_busy := false

var _floor_root: Node3D
var _floor_base_pos := Vector3.ZERO
var _rows: Array[Dictionary] = []
var _prompt: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_prompt = _resolve_prompt()
	_build_geometry()
	var trigger: Area3D = $TriggerArea
	trigger.body_entered.connect(_on_trigger_entered)


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


func _build_geometry() -> void:
	var floor_mat: Material = load("res://art/materials/floor.tres")
	if floor_mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.37, 0.35, 0.30)
		sm.roughness = 0.95
		floor_mat = sm

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.62, 0.62, 0.68)
	spike_mat.metallic = 0.35
	spike_mat.roughness = 0.45

	_floor_root = Node3D.new()
	_floor_root.name = "FloorRoot"
	add_child(_floor_root)
	_floor_base_pos = Vector3.ZERO
	_floor_root.position = _floor_base_pos

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box := BoxMesh.new()
	box.size = Vector3(corridor_length, floor_thickness, corridor_width)
	floor_mesh.mesh = box
	floor_mesh.material_override = floor_mat
	_floor_root.add_child(floor_mesh)

	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	var floor_cs := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(corridor_length, floor_thickness, corridor_width)
	floor_cs.shape = floor_shape
	floor_body.add_child(floor_cs)
	_floor_root.add_child(floor_body)

	# Mid-span trigger volume (player walks to middle).
	var trigger := Area3D.new()
	trigger.name = "TriggerArea"
	trigger.monitoring = true
	trigger.monitorable = false
	var trigger_cs := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(maxf(1.6, corridor_length * 0.28), 1.4, corridor_width * 0.85)
	trigger_cs.shape = trigger_shape
	trigger_cs.position = Vector3(0.0, 0.7, 0.0)
	trigger.add_child(trigger_cs)
	add_child(trigger)

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = spike_bottom_radius
	spike_mesh.height = spike_height
	spike_mesh.radial_segments = 8
	spike_mesh.material = spike_mat

	var half_len := corridor_length * 0.5
	var margin := 0.55
	var usable := corridor_length - margin * 2.0
	var row_span := usable / float(maxi(row_count - 1, 1))

	for i in range(row_count):
		var t := float(i) / float(maxi(row_count - 1, 1))
		var x: float
		if cascade_from_positive_x:
			x = half_len - margin - row_span * float(i)
		else:
			x = -half_len + margin + row_span * float(i)

		var row := Node3D.new()
		row.name = "SpikeRow_%02d" % i
		row.position = Vector3(x, 0.0, 0.0)
		add_child(row)

		var down_y := -spike_height * 0.52
		var up_y := floor_thickness * 0.5 + spike_height * 0.42

		var z_positions: Array[float] = []
		if spikes_per_row <= 1:
			z_positions.append(0.0)
		else:
			var half_w := corridor_width * 0.5 - 0.35
			for s in range(spikes_per_row):
				var u := float(s) / float(spikes_per_row - 1)
				z_positions.append(lerpf(-half_w, half_w, u))

		var spike_nodes: Array[Node3D] = []
		for zi in range(z_positions.size()):
			var holder := Node3D.new()
			holder.name = "Spike_%d" % zi
			holder.position = Vector3(0.0, down_y, z_positions[zi])
			var mi := MeshInstance3D.new()
			mi.mesh = spike_mesh
			holder.add_child(mi)
			row.add_child(holder)
			spike_nodes.append(holder)

		var hit := Area3D.new()
		hit.name = "HitArea"
		hit.monitoring = false
		hit.monitorable = false
		var hit_cs := CollisionShape3D.new()
		var hit_shape := BoxShape3D.new()
		hit_shape.size = Vector3(row_span * 0.95 + 0.15, spike_height * 0.85, corridor_width * 0.92)
		hit_cs.shape = hit_shape
		hit_cs.position = Vector3(0.0, floor_thickness * 0.5 + spike_height * 0.35, 0.0)
		hit.add_child(hit_cs)
		row.add_child(hit)
		hit.body_entered.connect(_on_spike_hit)

		_rows.append({
			"row": row,
			"spikes": spike_nodes,
			"hit": hit,
			"down_y": down_y,
			"up_y": up_y,
			"rise_t": 0.0,
			"rising": false,
			"raised": false,
		})


func _on_trigger_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_start_shake_then_cascade()


func _start_shake_then_cascade() -> void:
	_shaking = true
	_shake_left = shake_seconds
	if _prompt:
		_prompt.visible = true
		_prompt.text = "The floor trembles..."
	await get_tree().create_timer(shake_seconds).timeout
	_shaking = false
	if is_instance_valid(_floor_root):
		_floor_root.position = _floor_base_pos
	if _prompt:
		_prompt.text = "Spikes!"
	_cascading = true
	await _run_cascade()


func _run_cascade() -> void:
	for i in range(_rows.size()):
		var t := float(i) / float(maxi(_rows.size() - 1, 1))
		var delay := lerpf(first_row_delay, last_row_delay, t)
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		_begin_row_rise(i)
	# Keep prompt briefly after last row starts rising.
	await get_tree().create_timer(spike_rise_time + 0.35).timeout
	_cascading = false
	if _prompt:
		_prompt.visible = false


func _begin_row_rise(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var info: Dictionary = _rows[index]
	if info["raised"] or info["rising"]:
		return
	info["rising"] = true
	info["rise_t"] = 0.0
	_rows[index] = info


func _process(delta: float) -> void:
	if _shaking and is_instance_valid(_floor_root):
		_shake_left = maxf(0.0, _shake_left - delta)
		var damp := clampf(_shake_left / maxf(shake_seconds, 0.001), 0.0, 1.0)
		var amp := shake_amplitude * (0.35 + 0.65 * damp)
		_floor_root.position = _floor_base_pos + Vector3(
			_rng.randf_range(-amp, amp),
			_rng.randf_range(-amp * 0.35, amp * 0.55),
			_rng.randf_range(-amp, amp)
		)

	for i in range(_rows.size()):
		var info: Dictionary = _rows[i]
		if not info["rising"] or info["raised"]:
			continue
		info["rise_t"] = minf(1.0, float(info["rise_t"]) + delta / maxf(spike_rise_time, 0.001))
		var ease_t := _ease_out_cubic(float(info["rise_t"]))
		var y := lerpf(float(info["down_y"]), float(info["up_y"]), ease_t)
		for spike in info["spikes"]:
			if is_instance_valid(spike):
				spike.position.y = y
		var hit: Area3D = info["hit"]
		if float(info["rise_t"]) >= 0.45 and hit and not hit.monitoring:
			hit.monitoring = true
		if float(info["rise_t"]) >= 1.0:
			info["rising"] = false
			info["raised"] = true
		_rows[i] = info


func _ease_out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


func _on_spike_hit(body: Node) -> void:
	if _respawn_busy:
		return
	if not body.is_in_group("player"):
		return
	_respawn_busy = true
	_respawn(body)
	await get_tree().create_timer(respawn_cooldown).timeout
	_respawn_busy = false


func _respawn(body: Node) -> void:
	var marker := get_node_or_null(respawn_path)
	if marker == null:
		push_warning("SpikeCascadeTrap: respawn_path not set or invalid")
		return
	if body is Node3D:
		body.global_position = marker.global_position
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Spikes! Sent back."
		await get_tree().create_timer(1.1).timeout
		if _prompt and not _cascading and not _shaking:
			_prompt.visible = false