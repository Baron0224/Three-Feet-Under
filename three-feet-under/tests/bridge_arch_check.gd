extends SceneTree
var failures := 0
var checks := 0
var enters := 0
var exits := 0
var collapse := 0
var collapse_done := 0
var swing_done := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func ticks(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://tomb_corridor.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var bridge = scene.get_node("DilapidatedBridge")
	var p = scene.get_node("player")
	bridge.player_entered_midspan.connect(func(): enters += 1)
	bridge.player_exited_midspan.connect(func(): exits += 1)
	bridge.collapse_requested.connect(func(): collapse += 1)
	bridge.collapse_finished.connect(func(): collapse_done += 1)
	bridge.rope_swing_finished.connect(func(): swing_done += 1)
	# Keep intact for bank-to-bank regression before exercising A→B→C.
	bridge.auto_collapse_on_midspan = false
	await ticks(12)
	bridge.enable_midspan_shake = false
	for i in 49:
		var x: float = -12.0 + i * 0.5
		var world: Vector3 = bridge.global_position + Vector3(x,bridge._arch_y(x),0)
		var ray := PhysicsRayQueryParameters3D.create(world+Vector3.UP,world-Vector3.UP,1,[p.get_rid()])
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty(), "continuous top collision x=%s" % x)
		if not hit.is_empty(): check(absf(hit.position.y-world.y)<0.025 and hit.normal.y>0.9, "collision follows curved deck")
	# Standing capsule at jump apex at regular positions must clear real cave roof.
	for i in 13:
		var probe := PhysicsShapeQueryParameters3D.new()
		probe.shape = p.standing_probe
		probe.transform = Transform3D(Basis.IDENTITY,Vector3(21.0+i*2,bridge._arch_y(-12+i*2)+0.76+0.9,-30))
		probe.exclude = [p.get_rid()]
		check(p.get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(),"standing jump envelope clear")
	check(absf(bridge._arch_y(0)-2.15)<0.001 and absf(bridge._arch_y(12)-0.15)<0.001, "arch crown and banks")
	check(bridge.get_node("Gen_Bridge/DeckWest").mesh is ArrayMesh,"west continuous array mesh")
	check(bridge.get_node("Gen_Bridge/Gen_CollapseSpan/DeckCollapse").mesh is ArrayMesh,"collapse span mesh")
	bridge.enable_midspan_shake = true
	for direction in [1.0,-1.0]:
		p.global_position = Vector3(33-direction*12.5,0.18,-30)
		p.rotation = Vector3.ZERO
		p.velocity = Vector3.ZERO
		p._set_mouse_capture(true)
		await ticks(8)
		Input.action_press("move_right" if direction>0 else "move_left")
		await ticks(520)
		Input.action_release("move_right" if direction>0 else "move_left")
		check(direction*(p.position.x-33)>12,"live bank-to-bank standing walk")
		check(not p.is_dead and p.is_on_floor(),"no gap or step at bridge joints")
	for action in ["crouch","sneak"]:
		p.global_position = Vector3(21.0,0.18,-30)
		p.velocity = Vector3.ZERO
		await ticks(6)
		Input.action_press(action)
		Input.action_press("move_right")
		await ticks(1550 if action=="crouch" else 1300)
		Input.action_release(action)
		Input.action_release("move_right")
		check(p.position.x>45 and p.is_on_floor(),"live complete slow crossing "+action)
	p.global_position = Vector3(33,2.17,-30)
	p.velocity = Vector3.ZERO
	await ticks(8)
	check(p._footsteps.probe_floor(p) == "stone", "arch remains stone footsteps")
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	var peak: float = p.position.y
	for i in 55:
		await ticks(1)
		peak = maxf(peak,p.position.y)
	check(peak>2.65 and p.is_on_floor(),"full jump crown clearance and landing")
	check(enters>=4 and exits>=3,"midspan enter/exit preserved")

	# --- A→B→C collapse ---
	bridge.request_collapse()
	check(collapse==1,"collapse_requested emitted")
	await ticks(int(ceil(bridge.collapse_fall_seconds * 60.0)) + 20)
	check(collapse_done==1 and bridge.has_collapsed(),"collapse finished and gap open")
	# Forward span collision gone; west lip still solid.
	var gap_x: float = (bridge.collapse_start_x + bridge.collapse_end_x) * 0.5
	var gap_world: Vector3 = bridge.global_position + Vector3(gap_x, bridge._arch_y(gap_x), 0)
	var gap_ray := PhysicsRayQueryParameters3D.create(gap_world+Vector3.UP*2.0,gap_world-Vector3.UP*3.0,1,[p.get_rid()])
	var gap_hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(gap_ray)
	# Rescue beam may catch the ray if it lies under mid_x; prefer center Z=0 which beam is offset from.
	if not gap_hit.is_empty():
		check(absf(gap_hit.position.z) > 0.2 or gap_hit.position.y < gap_world.y - 0.3, "center gap has no full deck collision")
	else:
		check(true, "center gap open")
	var west_x: float = bridge.collapse_start_x - 1.0
	var west_world: Vector3 = bridge.global_position + Vector3(west_x, bridge._arch_y(west_x), 0)
	var west_ray := PhysicsRayQueryParameters3D.create(west_world+Vector3.UP,west_world-Vector3.UP,1,[p.get_rid()])
	check(not p.get_world_3d().direct_space_state.intersect_ray(west_ray).is_empty(), "west lip remains solid after collapse")

	# B rope swing → C far bank.
	p.global_position = bridge.to_global(Vector3(bridge.collapse_start_x - 0.4, bridge._arch_y(bridge.collapse_start_x - 0.4) + 0.95, 0))
	p.velocity = Vector3.ZERO
	p._set_mouse_capture(true)
	p.is_reading = false
	await ticks(6)
	bridge._start_rope_swing(p)
	await ticks(int(ceil(bridge.rope_swing_seconds * 60.0)) + 30)
	check(swing_done==1, "rope swing finished signal")
	check(p.position.x > bridge.global_position.x + bridge.collapse_end_x, "landed past collapse span")
	check(not p.is_dead, "survived rope swing")

	# Guard: allow_future_collapse false blocks further collapses (already collapsed so count stays).
	var prev_collapse := collapse
	bridge.allow_future_collapse=false
	bridge.request_collapse()
	check(collapse==prev_collapse,"collapse guard preserved when already done / disallowed")

	bridge.auto_collapse_on_midspan = false
	bridge._request_rebuild()
	bridge._request_rebuild()
	await ticks(8)
	check(bridge.get_child_count()==1,"rebuild coalesces to one generated root")
	print("BRIDGE ARCH: %d checks, failures=%d" % [checks,failures])
	scene.queue_free()
	await ticks(3)
	OS.delay_msec(100)
	quit(1 if failures else 0)
