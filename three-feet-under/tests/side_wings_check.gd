extends SceneTree
# Godot --headless --path . --fixed-fps 60 --script res://tests/side_wings_check.gd
var failures: Array[String] = []
var scene: Node3D
var player: CharacterBody3D
var samples := 0
var legs := 0
var scene_scale := 1.0

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func ticks(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame
func clear_actions() -> void:
	for action in ["move_forward","move_back","move_left","move_right","jump","crouch","sneak"]:
		Input.action_release(action)
func floor_y(_p: Vector3) -> float:
	return .1*scene_scale
func follow(target: Vector3) -> void:
	var frames := 0
	while Vector2(player.position.x-target.x,player.position.z-target.z).length()>.08 and frames<1800:
		clear_actions()
		var dx := target.x-player.position.x
		var dz := target.z-player.position.z
		if abs(dx)>.04: Input.action_press("move_right" if dx>0 else "move_left")
		if abs(dz)>.04: Input.action_press("move_back" if dz>0 else "move_forward")
		await ticks(1)
		frames += 1
	clear_actions()
	expect(frames<1800 and abs(player.position.y-floor_y(target))<.08 and not player.is_dead,"live player route "+str(target)+" actual "+str(player.position))
	legs += 1
func run() -> void:
	scene = load("res://tomb_corridor.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("player")
	scene_scale = scene.get_meta("environment_scale",1.0)
	await ticks(6)
	var routes = [
		[Vector3(0,0,-20),Vector3(-36,0,-20),Vector3(-36,0,-30),Vector3(-36,0,-41),Vector3(-16,0,-41),Vector3(-16,0,-51),Vector3(-39,0,-51),Vector3(-39,0,-60),Vector3(-29,0,-60)],
		[Vector3(-22,0,-41),Vector3(-22,0,-29),Vector3(-11,0,-29),Vector3(-11,0,-25),Vector3(0,0,-25)],
		[Vector3(-28.5,0,-20),Vector3(-28.5,0,-12.5)],
		[Vector3(-20.5,0,-20),Vector3(-20.5,0,-12.5)],
		[Vector3(-12.5,0,-20),Vector3(-12.5,0,-9)],
		[Vector3(0,0,-20),Vector3(15.3,0,-20)],
		[Vector3(0,0,-15),Vector3(11,0,-15),Vector3(11,0,-4),Vector3(40,0,-4),Vector3(40,0,-20),Vector3(40,0,-40)],
		[Vector3(40,0,-20),Vector3(28.7,0,-20)]
	]
	for route in routes:
		for i in range(route.size()): route[i] *= scene_scale
	var space = scene.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	for route in routes:
		for seg in range(route.size()-1):
			var a: Vector3 = route[seg]
			var b: Vector3 = route[seg+1]
			var steps := int(a.distance_to(b)/.1)
			for i in range(steps+1):
				var p := a.lerp(b,float(i)/steps)
				var y := floor_y(p)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.exclude = [player.get_rid()]
				for lift in [0.0,.74]:
					query.transform.origin = p+Vector3(0,y+.95+lift,0)
					expect(space.intersect_shape(query).is_empty(),"capsule/jump clearance "+str(p)+" lift="+str(lift))
				var ray := PhysicsRayQueryParameters3D.create(p+Vector3(0,y+.3,0),p+Vector3(0,y-.3,0))
				ray.exclude = [player.get_rid()]
				var hit = space.intersect_ray(ray)
				expect(not hit.is_empty() and abs(hit.position.y-y)<.015,"support "+str(p))
				samples += 1
	var boxes := 0
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		var c = mesh.get_node_or_null("StaticBody3D/CollisionShape3D")
		if mesh.mesh is BoxMesh and c != null:
			expect(mesh.mesh.size.is_equal_approx(c.shape.size),"mesh/collider dimensions "+str(mesh.get_path()))
			boxes += 1
	for route in routes:
		player.position = route[0]+Vector3(0,floor_y(route[0])+.01,0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
		await ticks(4)
		var targets = route.slice(1)
		var back = route.duplicate()
		back.reverse()
		targets.append_array(back.slice(1))
		for target in targets: await follow(target)
	# Probe the full enlarged gap: no support at the surface, bottom remains visible/collidable.
	var abyss_samples := 0
	var saved_pos := player.position
	for x in range(17,28):
		for z in range(-25,-13):
			var p := Vector3(x*scene_scale,0,z*scene_scale)
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3(0,.5,0),p-Vector3(0,.5,0))
			ray.exclude = [player.get_rid()]
			expect(space.intersect_ray(ray).is_empty(), "no false gap support "+str(p))
			ray.to = Vector3(p.x,-20*scene_scale,p.z)
			var hit = space.intersect_ray(ray)
			expect(not hit.is_empty() and abs(hit.position.y+18*scene_scale)<.02, "scaled bottom "+str(p))
			# Includes x/z beyond the old hardcoded death rectangle, particularly east/south.
			player.position = Vector3(p.x,-6*scene_scale,p.z)
			expect(player._in_abyss_death_zone(), "death bounds cover entire enlarged gap "+str(p))
			abyss_samples += 1
	player.position = saved_pos
	print("SIDE WINGS: samples=",samples," box pairs=",boxes," actual movement legs=",legs," abyss samples=",abyss_samples," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
