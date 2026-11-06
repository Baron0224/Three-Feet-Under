extends SceneTree
# Validates world dimensions, not just local mesh resources, at 1.5x environment scale.
var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://tomb_corridor.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.get_node("player")
	var spawn: Vector3 = player.position
	check(scene.scale.is_equal_approx(Vector3.ONE),"scene root unscaled")
	check(player.global_basis.get_scale().is_equal_approx(Vector3.ONE),"player has no inherited environment scale")
	check(player.body_collision.global_basis.get_scale().is_equal_approx(Vector3.ONE),"player collision world scale unchanged")
	check(is_equal_approx(player.capsule.radius,.3) and is_equal_approx(player.capsule.height,1.8),"world player capsule radius/height")
	check(is_equal_approx(player.camera.position.y,1.6),"eye height 1.6m")
	check(player.MOVE_SPEED==3.0 and player.SNEAK_SPEED==1.2 and player.CROUCH_SPEED==1.0 and player.JUMP_VELOCITY==3.8,"person speed/jump constants")
	check(player.SPRINT_SPEED==5.2,"sprint toggle speed 5.2 m/s")
	check(is_equal_approx(player.get_node("Camera3D/SpotLight3D").spot_range,12),"flashlight remains 12m")
	check(spawn.is_equal_approx(Vector3(0,2.41,17.55)),"adapted entrance spawn, not player scale")
	var meshes := 0
	var decor_meshes := 0
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		var path := str(mesh.get_path())
		var sc: Vector3 = mesh.global_basis.get_scale()
		if path.contains("DecorDetails"):
			# Human-scale props are authored in world meters with their own prop scale,
			# so they must never inherit the environment's 1.5x.
			check(not sc.is_equal_approx(Vector3.ONE*1.5) and sc.x>0.2 and sc.x<3.0,"decor prop not environment-scaled "+path)
			decor_meshes += 1
		else:
			var expected := Vector3.ONE if mesh.name=="ClueTablet" else Vector3.ONE*1.5
			check(sc.is_equal_approx(expected),"mesh world scale exactly once "+path)
			meshes += 1
	for batch in scene.get_node("ArtDetails").find_children("*","MultiMeshInstance3D",true,false):
		check(batch.global_basis.get_scale().is_equal_approx(Vector3.ONE*1.5),"art inherits scale exactly once "+str(batch.name))
	for light in scene.find_children("*","OmniLight3D",true,false):
		check(light.global_basis.get_scale().is_equal_approx(Vector3.ONE),"light transform unit scale, range explicit "+str(light.get_path()))
	var hub = scene.get_node("Hub02Floor")
	check((hub.mesh.size*hub.global_basis.get_scale()).is_equal_approx(Vector3(24,.3,24)),"hub is 24x24 meters")
	check((scene.get_node("Floor01").mesh.size*scene.get_node("Floor01").global_basis.get_scale()).is_equal_approx(Vector3(4.5,.3,12)),"entrance width is 4.5 meters")
	var tablet = scene.get_node("ClueTablet")
	check(tablet.position.is_equal_approx(Vector3(-2.21,1.45,-2.25)),"tablet on new wall at human eye height")
	check(tablet.read_distance==2.0 and is_equal_approx(tablet.leave_distance,2.2),"tablet range remains 2/2.2 meters")
	var wall = load("res://art/materials/wall.tres")
	var floor_material = load("res://art/materials/floor.tres")
	check(wall.get_shader_parameter("block_size").is_equal_approx(Vector2(1.1,.46)),"wall blocks still 1.1x0.46m")
	check(floor_material.get_shader_parameter("block_size").is_equal_approx(Vector2(.85,.85)),"paving still 0.85m")
	var bounds: AABB = scene.get_meta("abyss_death_bounds")
	check(bounds.has_point(Vector3(40,-8,-30)) and bounds.has_point(Vector3(33,-8,-18)),"east/south gap death coverage beyond old hardcoded bounds")
	for frame in range(16): await physics_frame
	check(abs(player.position.y-2.31)<.03,"spawn settles on expanded entrance landing")
	# Actually jump off C in the expanded eastern half, outside both old x/z limits.
	# Drop south of the new Chasm07 stone bridge deck (z -35..-25), still inside the abyss.
	player.position = Vector3(43.5,.16,-38)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	for frame in range(4): await physics_frame
	Input.action_press("move_left")
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var fall_frames := 0
	while not player.is_dead and fall_frames<240:
		await physics_frame
		fall_frames += 1
	Input.action_release("move_left")
	check(player.is_dead and player.position.x>31 and player.position.z<-28 and player.position.y>-27,"actual eastern fall dies outside old bounds before bottom")
	var old_id: int = player.get_instance_id()
	for frame in range(160):
		if not is_instance_valid(player): break
		await physics_frame
	var restarted = current_scene.get_node("player")
	for frame in range(12): await physics_frame
	check(restarted.get_instance_id()!=old_id and abs(restarted.position.z-17.55)<.03 and abs(restarted.position.y-2.31)<.04,"eastern abyss death reloads to scaled entrance")
	print("SCALE AUDIT: ",assertions," assertions, ",meshes," architectural/tablet meshes, ",decor_meshes," human-scale decor meshes, failures=",failures)
	quit(0 if failures==0 else 1)
