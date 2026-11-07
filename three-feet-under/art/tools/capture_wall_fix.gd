# Verification shots for the wall-decoration fit fix; run with real OpenGL, never headless.
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
	output = OS.get_environment("TFU_WALLFIX_OUTPUT")
	if output.is_empty():
		push_error("Set TFU_WALLFIX_OUTPUT to a review directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
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
	camera.fov = 45
	camera.far = 120
	viewport.add_child(camera)
	camera.make_current()
	var torch := player.get_node("Camera3D/SpotLight3D").duplicate()
	torch.visible = true
	camera.add_child(torch)
	var shots := [
		["hall_south_door", Vector3(0.0, 1.7, -93.0), Vector3(0.0, 2.9, -79.5)],
		["hall_south_wall", Vector3(12.0, 1.7, -86.0), Vector3(16.0, 3.0, -79.5)],
		["hall_north_door", Vector3(15.0, 1.7, -92.0), Vector3(15.0, 2.9, -103.5)],
		["tomb_east_door", Vector3(60.0, 1.7, -98.25), Vector3(70.5, 2.8, -98.25)],
		["tomb_west_gate", Vector3(56.0, 1.7, -91.5), Vector3(43.5, 2.8, -91.5)],
		["niche_close", Vector3(6.0, 1.55, -101.0), Vector3(6.0, 1.05, -103.5)],
		["band_close", Vector3(13.6, 1.7, -82.9), Vector3(13.6, 2.95, -79.5)],
		["stopper", Vector3(48.0, 1.5, -86.4), Vector3(44.3, 0.95, -87.4)],
	]
	for shot in shots:
		camera.position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for i in range(10):
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join(shot[0] + ".png"))
		print("CAPTURE ", shot[0])
	print("WALLFIX_OUTPUT ", output)
	quit(0)