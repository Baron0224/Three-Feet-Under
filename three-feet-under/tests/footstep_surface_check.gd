extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func ticks(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var p = scene.get_node("player")
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	shape.shape = box
	floor_body.add_child(shape)
	scene.add_child(floor_body)
	floor_body.global_position = Vector3(1000, 0, 0)
	floor_body.set_meta("surface_type", "stone")
	p.global_position = Vector3(1000, 0.12, 0)
	p.velocity = Vector3.ZERO
	p._set_mouse_capture(true)
	await ticks(30)
	var fx = p._footsteps
	check(fx.samples.stone.size() == 6 and fx.samples.gravel.size() == 6, "two real banks")
	for bank in fx.samples.values():
		for stream in bank: check(stream != null and stream.get_length() > 0.2, "valid PCM sample")
	check(fx.probe_floor(p) == "stone", "ray stone")
	floor_body.set_meta("surface_type", "gravel")
	check(fx.probe_floor(p) == "gravel", "ray gravel metadata")
	floor_body.remove_meta("surface_type")
	scene.set_meta("surface_type", "gravel")
	check(fx.probe_floor(p) == "gravel", "ancestor metadata")
	scene.remove_meta("surface_type")
	check(fx.probe_floor(p) == "stone", "default stone")
	var start: int = fx.emitted
	Input.action_press("move_forward")
	await ticks(120)
	check(fx.emitted - start >= 3 and fx.emitted - start <= 5, "normal cadence ~2/s")
	Input.action_release("move_forward")
	await ticks(5)
	check(is_zero_approx(p._step_accum), "stop resets stride")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8, 4, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	scene.add_child(wall)
	wall.global_position = p.global_position + Vector3(0, 1, -0.5)
	Input.action_press("move_forward")
	await ticks(60)
	start = fx.emitted
	await ticks(120)
	check(fx.emitted == start, "pushing wall silent")
	Input.action_release("move_forward")
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	await ticks(10)
	start = fx.emitted
	await ticks(15)
	check(fx.emitted == start and is_zero_approx(p._step_accum), "airborne silent and no stride accumulation")
	await ticks(80)
	check(fx.emitted - start >= 1 and fx.emitted - start <= 2, "landing contact only, no ordinary step")
	check(fx.GAIT_DB[fx.KIND_SNEAK] < fx.GAIT_DB[fx.KIND_CROUCH] and fx.GAIT_DB[fx.KIND_CROUCH] < fx.GAIT_DB[fx.KIND_WALK], "quiet gaits")
	fx.stop_all()
	fx.play_kind(fx.KIND_WALK)
	fx.play_kind(fx.KIND_SPRINT)
	var playing := 0
	for voice in fx.pool:
		if voice.playing: playing += 1
	check(playing == 2, "pool preserves overlapping tails")
	fx.stop_all()
	for voice in fx.pool: check(not voice.playing, "stop clears pool")
	fx.play_land("stone", 6.0)
	fx.stop_all()
	await ticks(6)
	for voice in fx.pool: check(not voice.playing, "stop cancels delayed landing layer")
	var weak: WeakRef = weakref(fx)
	check(reload_current_scene() == OK, "scene reload")
	await ticks(4)
	check(weak.get_ref() == null, "reload frees old voices")
	check(AudioServer.get_bus_index("Footsteps") >= 0, "dedicated reverb bus")
	var new_fx = current_scene.get_node("player")._footsteps
	check(new_fx.room_wetness(Vector3(0, 0, -30)) > new_fx.room_wetness(Vector3(0, 0, 0)), "hub acoustic zone")
	print("SURFACE AUDIO: %d checks, failures=%d" % [checks, failures])
	current_scene.queue_free()
	await ticks(3)
	OS.delay_msec(100) # Allow audio mixer to release stopped playback references.
	quit(1 if failures else 0)
