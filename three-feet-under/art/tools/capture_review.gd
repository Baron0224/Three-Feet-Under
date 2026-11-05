extends SceneTree
var viewport: SubViewport
var scene: Node3D
var camera: Camera3D
var output: String
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Visual capture requires a real OpenGL display driver, not headless/dummy")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-20000,-20000))
	root.hide()
	call_deferred("capture")
func capture() -> void:
	output=OS.get_environment("TEMP").path_join("tfu_scale_review_1_5")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	root.add_child(viewport)
	scene=load("res://tomb_corridor.tscn").instantiate()
	viewport.add_child(scene)
	var player=scene.get_node("player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	scene.get_node("ClueTablet").set_process(false)
	for layer in scene.find_children("*","CanvasLayer",true,false): layer.visible=false
	player.get_node("Camera3D/SpotLight3D").visible=false
	camera=Camera3D.new()
	camera.fov=75
	camera.far=110
	viewport.add_child(camera)
	camera.make_current()
	var torch=player.get_node("Camera3D/SpotLight3D").duplicate()
	torch.visible=true
	camera.add_child(torch)
	var shots=[
		["01_entry",Vector3(0,3.14,11.4),Vector3(0,1.35,-1)],
		["01_corridor",Vector3(0,1.75,3.8),Vector3(0,1.5,-6)],
		["02_hub",Vector3(-5.3,1.8,-14),Vector3(2,1.4,-24)],
		["03_west",Vector3(-12,1.8,-20),Vector3(-31,1.5,-20)],
		["04_chamber",Vector3(-35,1.8,-26.5),Vector3(-37,1.5,-33)],
		["07_abyss",Vector3(14.6,1.8,-20),Vector3(28,.2,-20)],
		["07_depth",Vector3(15.2,2.5,-18),Vector3(24,-7,-21)],
		["10_hall",Vector3(-1,1.9,-54.5),Vector3(20,1.6,-64)],
		["11_tomb",Vector3(31,1.8,-55),Vector3(39,1.3,-64)],
		["12_exit",Vector3(53.5,1.8,-68),Vector3(53.5,2.8,-78.5)]
	]
	var authored_scale: float = scene.get_meta("environment_scale",1.0)
	for shot in shots:
		var eye: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		var base_floor := 1.54 if shot[0]=="01_entry" else .1
		eye = Vector3(eye.x*authored_scale,base_floor*authored_scale+(eye.y-base_floor),eye.z*authored_scale)
		target = Vector3(target.x*authored_scale,target.y*authored_scale if target.y<0 else .1*authored_scale+(target.y-.1),target.z*authored_scale)
		camera.position=eye
		camera.look_at(target,Vector3.UP)
		for i in range(8): await RenderingServer.frame_post_draw
		var img=viewport.get_texture().get_image()
		var err=img.save_png(output.path_join(shot[0]+".png"))
		print("CAPTURE ",shot[0]," error=",err," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	# Render the real controller's controls and death overlay in the same viewport.
	camera.position=Vector3(0,1.54*authored_scale+1.6,11.7*authored_scale)
	camera.look_at(Vector3(0,.1*authored_scale+1.4,0),Vector3.UP)
	player.get_node("PlayerControlsHUD").visible=true
	for i in range(4): await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("controls_hud.png"))
	player._die()
	for i in range(4): await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("death_hud.png"))
	print("REVIEW_OUTPUT ",output,"; actual renderer=",RenderingServer.get_video_adapter_name())
	quit(0)
