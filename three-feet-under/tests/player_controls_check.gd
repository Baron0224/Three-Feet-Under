extends SceneTree
# Run: Godot --headless --path <project> --fixed-fps 60 --script res://tests/player_controls_check.gd
var failures: Array[String] = []
var checks := 0
var scene: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func clear_actions() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sneak", "crouch"]:
		Input.action_release(action)

func teleport(pos: Vector3) -> void:
	clear_actions()
	player.position = pos
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await ticks(4)

func key_tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(1)

func load_test_scene(path: String) -> void:
	clear_actions()
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("player")
	await ticks(6)

func run() -> void:
	expect(InputMap.action_get_events("sneak")[0].physical_keycode == KEY_SHIFT, "Shift binding")
	expect(InputMap.action_get_events("crouch")[0].physical_keycode == KEY_CTRL, "Ctrl binding")
	for path in ["res://main.tscn", "res://tomb_corridor.tscn"]:
		await load_test_scene(path)
		expect(player.get_node("PlayerControlsHUD/ControlsHint").visible, path+": controls visible")
		expect(player.has_abyss == (path=="res://tomb_corridor.tscn"), path+": abyss detection limited to tomb")
		await teleport(Vector3(0,.11,0))
		var start_z := player.position.z
		Input.action_press("move_forward")
		await ticks(40)
		var walk_distance: float = start_z-player.position.z
		clear_actions()
		expect(abs(player.velocity.z+3.0)<.01 and abs(walk_distance-2.0)<.12, path+": walk 3 m/s")
		await teleport(Vector3(0,.11,0))
		start_z = player.position.z
		Input.action_press("move_forward")
		Input.action_press("sneak")
		await ticks(40)
		var sneak_distance: float = start_z-player.position.z
		expect(abs(player.velocity.z+1.2)<.01 and sneak_distance<walk_distance*.5, path+": sneak is slower at 1.2 m/s")
		await teleport(Vector3(0,.11,0))
		Input.action_press("crouch")
		await ticks(1)
		expect(player.is_crouching and abs(player.capsule.height-1.1)<.001 and abs(player.body_collision.position.y-.55)<.001, path+": actual crouch capsule")
		expect(player.camera.position.y>.95 and player.camera.position.y<1.6, path+": camera smooth transition")
		await ticks(35)
		expect(abs(player.camera.position.y-.95)<.01, path+": crouched eye height")
		Input.action_press("move_forward")
		await ticks(10)
		expect(abs(player.velocity.z+1.0)<.01, path+": crouch speed 1 m/s")
		clear_actions()
		await ticks(35)
		expect(not player.is_crouching and abs(player.capsule.height-1.8)<.001 and abs(player.camera.position.y-1.6)<.01, path+": release restores stance")
		await teleport(Vector3(0,.11,0))
		Input.action_press("crouch")
		await ticks(3)
		var ceiling := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6,.3,1.6)
		shape.shape = box
		ceiling.add_child(shape)
		scene.add_child(ceiling)
		ceiling.position = Vector3(0,1.5,0)
		await ticks(3)
		Input.action_release("crouch")
		await ticks(10)
		expect(player.is_crouching and not player._can_stand(), path+": ceiling blocks standing")
		Input.action_press("move_forward")
		await ticks(90)
		clear_actions()
		await ticks(35)
		expect(not player.is_crouching and abs(player.capsule.height-1.8)<.001, path+": stands after leaving low ceiling")
		ceiling.queue_free()
		await ticks(2)
		await teleport(Vector3(0,.11,0))
		Input.action_press("jump")
		await ticks(1)
		expect(player.velocity.y>3.0 and not player.is_on_floor(), path+": ground jump")
		Input.action_release("jump")
		await ticks(3)
		var before_velocity: float = player.velocity.y
		Input.action_press("jump")
		await ticks(1)
		expect(player.velocity.y<before_velocity, path+": no airborne second jump")
		Input.action_release("jump")
		var peak: float = player.position.y
		for frame in range(65):
			await ticks(1)
			peak = maxf(peak,player.position.y)
		expect(player.is_on_floor() and abs(player.position.y-.1)<.03 and peak<.9 and peak>.6, path+": jump height and landing")
		Input.action_press("crouch")
		await ticks(2)
		Input.action_press("jump")
		await ticks(2)
		expect(player.is_on_floor(), path+": no crouched jump")
		clear_actions()
		await teleport(Vector3(0,.11,-1.5))
		var tablet = scene.get_node("ClueTablet")
		await ticks(3)
		expect(tablet.can_read and tablet.prompt.visible, path+": tablet proximity")
		await key_tap(KEY_E)
		expect(tablet.reading and player.is_reading and "按 E 关闭" in tablet.prompt.text, path+": E opens tablet")
		var reading_pos := player.position
		Input.action_press("move_forward")
		Input.action_press("jump")
		await ticks(12)
		expect(player.position.distance_to(reading_pos)<.03, path+": reading locks walk/jump")
		clear_actions()
		await key_tap(KEY_E)
		expect(not tablet.reading and not player.is_reading, path+": E closes tablet")
		await key_tap(KEY_ESCAPE)
		expect(not player.mouse_captured and not player.can_interact(), path+": Esc releases mouse")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		Input.parse_input_event(mouse)
		await ticks(2)
		expect(player.mouse_captured, path+": click captures mouse")
		print("Checked shared controls: ",path)
	# Crouching on the entrance ramp must not leave the player stuck crouched.
	await teleport(Vector3(0,.8,8))
	Input.action_press("crouch")
	await ticks(5)
	Input.action_release("crouch")
	await ticks(35)
	expect(not player.is_crouching and player.is_on_floor(), "stand up on staircase ramp")
	# Tomb-specific actual staircase movement using the live control script.
	await teleport(Vector3(0,1.64,11.7))
	Input.action_press("move_forward")
	await ticks(320)
	clear_actions()
	expect(player.position.z < -3.5 and player.position.y>0.0 and not player.is_dead, "stairs down and corridor")
	Input.action_press("move_back")
	await ticks(320)
	clear_actions()
	expect(player.position.z>11 and abs(player.position.y-1.54)<.05, "stairs back up")
	# Try an ordinary running jump from A: it must fall, never reach C.
	await teleport(Vector3(15,.11,-20))
	Input.action_press("move_right")
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	var death_frames := 0
	var forced_reading := false
	while not player.is_dead and death_frames<200:
		await ticks(1)
		death_frames += 1
		if not player.is_dead and player.position.y < -2 and not forced_reading:
			# A fall can continue under gravity while a reading overlay is open.
			forced_reading = true
			scene.get_node("ClueTablet").reading = true
			player.set_reading(true)
	clear_actions()
	expect(player.is_dead and player.position.x<28 and player.position.y>-18, "12m gap cannot be jumped; death before bottom")
	expect(player.death_overlay.visible and "深渊" in player.death_message.text and player.velocity==Vector3.ZERO, "visible death overlay and frozen velocity")
	expect(not player.can_interact(), "death blocks interaction")
	expect(forced_reading and not player.is_reading and not scene.get_node("ClueTablet").reading and not scene.get_node("HUD/InteractPrompt").visible, "death closes reading and tablet HUD")
	player._die() # Repeated calls must not start another timer or restart the delay.
	var old_player_id := player.get_instance_id()
	var death_pos := player.position
	Input.action_press("move_left")
	Input.action_press("jump")
	await ticks(5)
	expect(player.position.is_equal_approx(death_pos), "death blocks movement")
	clear_actions()
	var restart_wait_frames := 0
	for frame in range(160):
		if not is_instance_valid(player): break
		await ticks(1)
		restart_wait_frames += 1
	expect(restart_wait_frames>=55 and restart_wait_frames<=90, "one delayed restart after visible death pause")
	scene = current_scene
	player = scene.get_node("player")
	await ticks(8)
	expect(player.get_instance_id()!=old_player_id and not player.is_dead, "scene actually reloaded once")
	expect(abs(player.position.x)<.01 and abs(player.position.z-11.7)<.03 and abs(player.position.y-1.54)<.08, "restart from tomb entrance")
	expect(not player.death_overlay.visible and player.mouse_captured, "restart clears death HUD and captures mouse")
	# Missing current scene exercises the guarded reload-error fallback without a login or scene change.
	player.is_dead = true
	player.death_overlay.show()
	current_scene = null
	player._try_reload()
	expect(player.reload_failed and not player.reload_in_progress and "按 R" in player.death_message.text, "reload failure shows retry and releases guard")
	current_scene = scene
	var retry_old_id := player.get_instance_id()
	await key_tap(KEY_R)
	await ticks(8)
	scene = current_scene
	player = scene.get_node("player")
	expect(player.get_instance_id()!=retry_old_id and not player.is_dead, "R retry reloads after prior failure")
	print("CHECKS: ",checks,"; FAILURES: ",failures.size())
	quit(0 if failures.is_empty() else 1)
