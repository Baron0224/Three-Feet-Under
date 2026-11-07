extends SceneTree
var viewport: SubViewport
var output: String

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("needs OpenGL")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-20000, -20000))
	root.hide()
	call_deferred("capture")

func capture() -> void:
	output = OS.get_environment("TEMP").path_join("tfu_decor_review")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var scene: Node3D = load("res://tomb_corridor.tscn").instantiate()
	viewport.add_child(scene)
	var player = scene.get_node("player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	scene.get_node("ClueTablet").set_process(false)
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	camera.fov = 70
	camera.far = 120
	viewport.add_child(camera)
	camera.make_current()
	var torch := player.get_node("Camera3D/SpotLight3D").duplicate()
	torch.visible = true
	camera.add_child(torch)
	var shots := [
		["06_seal", Vector3(-49.0, 1.65, -90.0), Vector3(-35.2, 0.9, -90.0)],
		["09_seal", Vector3(60.0, 1.65, -55.2), Vector3(60.0, 0.9, -65.6)],
		["11_coffin", Vector3(57.0, 1.95, -85.2), Vector3(57.0, 1.2, -91.5)],
		["lion_close", Vector3(-39.4, 1.25, -92.4), Vector3(-36.6, 0.85, -92.4)],
		["guard_close", Vector3(5.0, 1.5, -98.6), Vector3(5.0, 1.3, -102.4)],
		["hall_axis", Vector3(0.5, 2.0, -91.5), Vector3(36.0, 1.5, -91.5)],
		["vessel_row", Vector3(17.5, 1.5, -97.5), Vector3(20.0, 0.5, -102.0)],
		["vessel_close", Vector3(8.0, 1.35, -98.6), Vector3(8.0, 0.55, -102.0)],
		["ding_close", Vector3(26.5, 1.25, -93.6), Vector3(26.5, 0.4, -96.8)],
		["niche_close", Vector3(16.5, 1.45, -100.5), Vector3(16.5, 0.9, -103.0)],
		["niche_tomb", Vector3(46.5, 1.45, -86.5), Vector3(43.4, 0.9, -86.5)],
		["altar_shot", Vector3(50.4, 1.7, -91.5), Vector3(52.8, 0.8, -91.5)],
		["rack_close", Vector3(9.5, 1.45, -84.8), Vector3(9.5, 0.85, -80.6)],
		["tomb_vessel", Vector3(53.0, 1.4, -101.0), Vector3(46.0, 0.5, -103.0)],
		["tomb_axis", Vector3(44.5, 2.2, -91.5), Vector3(64.0, 2.6, -91.5)],
		["vault_look", Vector3(57.0, 3.0, -91.5), Vector3(57.0, 7.0, -91.5)],
		["relief_hall", Vector3(20.0, 3.4, -99.0), Vector3(20.0, 3.1, -103.43)],
		["relief_tomb", Vector3(65.0, 3.4, -91.5), Vector3(69.0, 3.1, -91.5)],
		["boshan_close", Vector3(1.5, 1.0, -94.3), Vector3(1.5, 0.65, -98.25)],
		["figurine_close", Vector3(29.0, 1.0, -88.5), Vector3(28.5, 0.6, -84.75)],
		["coin_close", Vector3(51.9, 0.9, -89.0), Vector3(52.6, 0.17, -89.5)],
	]
	for shot in shots:
		camera.position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for i in range(10):
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join(shot[0] + ".png"))
		print("CAPTURE ", shot[0])
	print("DECOR_OUTPUT ", output)
	quit(0)
