extends SceneTree
# Godot --headless --path . --fixed-fps 60 --script res://tests/final_wing_check.gd
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
func floor_y(p: Vector3) -> float:
	var base := p/scene_scale
	if base.x>51.9 and base.z<-73:
		return (.1+clampf((-base.z-73)/5.4,0,1)*1.44)*scene_scale
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
		[Vector3(0,0,-20),Vector3(0,0,-61),Vector3(32,0,-61),Vector3(32,0,-66),Vector3(44,0,-66),Vector3(44,0,-65.5),Vector3(53.5,0,-65.5),Vector3(53.5,0,-79.4)],
		[Vector3(-3,0,-67.5),Vector3(23,0,-67.5),Vector3(23,0,-54.5),Vector3(-3,0,-54.5),Vector3(-3,0,-67.5)],
		[Vector3(10,0,-54.5),Vector3(10,0,-75)],
		[Vector3(32,0,-66),Vector3(44,0,-66),Vector3(44,0,-56),Vector3(32,0,-56),Vector3(32,0,-66)]
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
	# Architectural columns/coffin must be real physical obstacles.
	for p in [Vector3(1,1.05,-65.5),Vector3(38,1.05,-61)]:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform.origin = Vector3(p.x*scene_scale,.1*scene_scale+.95,p.z*scene_scale)
		q.exclude = [player.get_rid()]
		expect(not space.intersect_shape(q).is_empty(),"solid column/coffin "+str(p))
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
	player.position = Vector3(53.5*scene_scale,1.54*scene_scale+.01,-79.4*scene_scale)
	player.velocity = Vector3.ZERO
	await ticks(4)
	Input.action_press("move_forward")
	await ticks(60)
	clear_actions()
	expect(player.position.z>=-80.4*scene_scale+.28 and player.position.z<-80.4*scene_scale+.4 and abs(player.position.y-1.54*scene_scale)<.05,"visible exit end wall prevents walking out")
	print("FINAL WING: samples=",samples," box pairs=",boxes," actual movement legs=",legs," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
