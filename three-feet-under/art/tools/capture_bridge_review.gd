# Maintained opt-in closeup capture; run with real OpenGL, never headless.
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
	output = OS.get_environment("TFU_BRIDGE_OUTPUT")
	if output.is_empty():
		push_error("Set TFU_BRIDGE_OUTPUT to a review directory")
		quit(1)
		return
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
	camera.fov = 90
	camera.far = 120
	viewport.add_child(camera)
	camera.make_current()
	var torch := player.get_node("Camera3D/SpotLight3D").duplicate()
	torch.visible = true
	camera.add_child(torch)
	var shots := [
		["bridge_side", Vector3(33,2.4,-20.7), Vector3(33,1.0,-30)],
		["bridge_player_west", Vector3(21.5,1.77,-30), Vector3(36,2.0,-30)],
		["bridge_player_crown", Vector3(33,3.75,-30), Vector3(46,0.3,-30)],
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
