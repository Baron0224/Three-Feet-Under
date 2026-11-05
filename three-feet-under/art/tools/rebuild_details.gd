extends SceneTree
# One-shot authoring tool: saves static MultiMesh resources/scene; never attached at runtime.
var batches: Dictionary = {}
var art: Node3D
var cube: BoxMesh
var rock: ArrayMesh
var saved_instances := 0

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use a hidden OpenGL process: dummy rendering cannot serialize MultiMesh buffers")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.hide()
	call_deferred("build")
func append_mesh(key: String, material: Material, mesh: Mesh, pos: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	if not batches.has(key): batches[key] = {"material":material,"mesh":mesh,"transforms":[]}
	var basis := Basis.from_euler(rotation).scaled(size)
	batches[key].transforms.append(Transform3D(basis,pos))
func make_rock() -> ArrayMesh:
	var v = [Vector3(-.48,-.5,-.5),Vector3(.48,-.5,-.44),Vector3(.5,-.5,.5),Vector3(-.5,-.5,.45),Vector3(-.32,.42,-.34),Vector3(.32,.5,-.3),Vector3(.38,.34,.36),Vector3(-.34,.48,.31)]
	var faces = [[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face: st.add_vertex(v[index])
	st.generate_normals()
	return st.commit()
func region(node: Node) -> String:
	var path := str(node.get_path()) if node.is_inside_tree() else str(node.name)
	var p = node
	while p != null:
		if p.name == "WestWing": return "West"
		if p.name == "EastWing": return "East"
		if p.name == "FinalWing": return "Final"
		p = p.get_parent()
	return "EntryHub"
func build() -> void:
	var materials := {}
	for name in ["wall","floor","ceiling","trim","rock","coffin","bronze","lamp_glow"]:
		materials[name] = load("res://art/materials/"+name+".tres")
	var env: Environment = load("res://art/tomb_environment.tres")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = 0
	ResourceSaver.save(env,"res://art/tomb_environment.tres")
	var source = load("res://tomb_corridor.tscn").instantiate()
	art = Node3D.new()
	art.name = "ArtDetails"
	art.set_meta("note","Static collision-free, project-authored stone trims/chips/sconces; no gameplay rebuild")
	cube = BoxMesh.new()
	cube.size = Vector3.ONE
	cube.take_over_path("res://art/detail_cube.tres")
	ResourceSaver.save(cube,"res://art/detail_cube.tres")
	rock = make_rock()
	rock.take_over_path("res://art/chipped_rock.tres")
	ResourceSaver.save(rock,"res://art/chipped_rock.tres")
	# Thin reliefs overlap existing walls; only 4mm outside a wall face, no new colliders.
	for node in source.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is BoxMesh: continue
		var authored_scale: float = source.get_meta("environment_scale",1.0)
		var world_transform: Transform3D = node.transform
		var ancestor: Node = node.get_parent()
		while ancestor != null and ancestor != source:
			if ancestor is Node3D: world_transform = ancestor.transform*world_transform
			ancestor = ancestor.get_parent()
		var size: Vector3 = node.mesh.size*world_transform.basis.get_scale()/authored_scale
		var pos: Vector3 = world_transform.origin/authored_scale
		if ("Wall" in str(node.name)) and size.y>=3 and size.y<=6 and pos.y>0:
			var band_size := Vector3(size.x+.008,.24,size.z+.008)
			append_mesh("WallFoot_"+region(node),materials.trim,cube,Vector3(pos.x,.23,pos.z),band_size)
			var h := pos.y+size.y*.5
			append_mesh("WallCornice_"+region(node),materials.trim,cube,Vector3(pos.x,h-.22,pos.z),Vector3(size.x+.008,.16,size.z+.008))
	# Door surrounds remain outside their clear aperture; upper crosspieces clear jumping.
	var doors = [Vector3(0,0,-28),Vector3(0,0,-12),Vector3(-36,0,-25),Vector3(-36,0,-35),Vector3(40,0,-35),Vector3(0,0,-53),Vector3(10,0,-69)]
	for i in range(doors.size()):
		var c: Vector3 = doors[i]
		var half := 2.0 if i==0 or i==5 else 1.5
		for side in [-1,1]:
			append_mesh("DoorStone",materials.trim,cube,c+Vector3(side*(half+.22),1.6,0),Vector3(.4,3,.32))
		append_mesh("DoorStone",materials.trim,cube,c+Vector3(0,3.23,0),Vector3(half*2+.8,.2,.34))
	for c in [Vector3(-8.1,0,-20),Vector3(-8.1,0,-25),Vector3(8.1,0,-20),Vector3(8.1,0,-15),Vector3(29,0,-61),Vector3(47,0,-65.5)]:
		for side in [-1,1]:append_mesh("DoorStone",materials.trim,cube,c+Vector3(0,1.6,side*1.72),Vector3(.32,3,.4))
		append_mesh("DoorStone",materials.trim,cube,c+Vector3(0,3.23,0),Vector3(.34,.2,3.8))
	# Exterior rock facing masks other room exteriors from the elevated entrance viewpoint.
	for x in [-31.0,31.0]: append_mesh("EntranceRockFacing",materials.rock,cube,Vector3(x,3.5,5.2),Vector3(58,9,.6))
	append_mesh("EntranceRockFacing",materials.rock,cube,Vector3(0,6.1,5.2),Vector3(4,5.2,.6))
	for x in [-7,7]: append_mesh("EntranceRockFacingFacets",materials.rock,rock,Vector3(x,3.2,5.6),Vector3(9,8,1.2))
	# A high stone frieze closes the visible ceiling-height transition above 11->12.
	# Entirely above the 3m doorway; no collision/gameplay change.
	append_mesh("HighDoorFrieze",materials.wall,cube,Vector3(47.02,4.21,-65.5),Vector3(.3,1.78,3.0))
	# 02 stone edging and corner masonry; preserve central/door/slot areas.
	for x in [-7.55,7.55]:append_mesh("FloorInlay",materials.trim,cube,Vector3(x,.106,-20),Vector3(.12,.008,14.8))
	for z in [-27.45,-12.55]:append_mesh("FloorInlay",materials.trim,cube,Vector3(0,.106,z),Vector3(14.8,.008,.12))
	# 01 bespoke chips stay near existing rubble and away from the stone tablet (z=-1.5).
	var rng := RandomNumberGenerator.new()
	rng.seed = 111205
	for i in range(26):
		var side := -1.0 if i%2==0 else 1.0
		var z := rng.randf_range(-8,4.3)
		if abs(z+1.5)<1.1: z=3.5
		var h := rng.randf_range(.045,.16)
		append_mesh("EntryChips",materials.rock,rock,Vector3(side*rng.randf_range(1.17,1.37),.1+h*.5,z),Vector3(rng.randf_range(.12,.32),h,rng.randf_range(.16,.45)),Vector3(0,rng.randf_range(0,6.28),0))
	for x in [-1.78,1.78]:
		append_mesh("EntryArch",materials.trim,cube,Vector3(x,1.7,5.3),Vector3(.22,3.2,.55))
	append_mesh("EntryArch",materials.trim,cube,Vector3(0,3.35,5.3),Vector3(3.8,.3,.55))
	# Column collars reinforce block construction without increasing collision footprint.
	for row_z in [-65.5,-56.5]:
		for x in [1,7,13,19]:
			for y in [.52,2.1,3.7,4.65]:append_mesh("ColumnCollars",materials.trim,cube,Vector3(x,y,row_z),Vector3(.808,.08,.808))
	# 11 rear-wall abstract masonry framing, no glyphs, seals or interactive objects.
	for x in [33.5,42.5]:append_mesh("TombRelief",materials.trim,cube,Vector3(x,2.5,-69.992),Vector3(.22,2.6,.025))
	for y in [1.2,3.8]:append_mesh("TombRelief",materials.trim,cube,Vector3(38,y,-69.992),Vector3(9.2,.18,.025))
	for x in [35,36.5,38,39.5,41]:
		append_mesh("TombRelief",materials.coffin,cube,Vector3(x,2.5,-69.975),Vector3(1.3,1.9,.04))
	# Low plinth edging lies on the existing base, leaving its surrounding path untouched.
	for x in [36.1,39.9]:append_mesh("TombRelief",materials.trim,cube,Vector3(x,.505,-61),Vector3(.16,.01,5.8))
	for z in [-63.9,-58.1]:append_mesh("TombRelief",materials.trim,cube,Vector3(38,.505,z),Vector3(3.8,.01,.16))
	# Faceted cliff overlays are confined to bank footprints / existing deep walls.
	for bank_x in [15.88,28.12]:
		for i in range(12):
			append_mesh("CliffFragments",materials.rock,rock,Vector3(bank_x,-.8-i*1.35,-20+rng.randf_range(-2.3,2.3)),Vector3(.28,1.9,rng.randf_range(1,2.5)),Vector3(0,0,rng.randf_range(-.08,.08)))
	for i in range(20):
		append_mesh("BottomFragments",materials.rock,rock,Vector3(rng.randf_range(15,29),-17.85,rng.randf_range(-26,-14)),Vector3(rng.randf_range(.5,1.8),.3,rng.randf_range(.5,1.8)),Vector3(0,rng.randf_range(0,6.28),0))
	# A few wall-foot debris groups in dead corners, not on route or puzzle centers.
	for c in [Vector3(-38.8,0,-33.8),Vector3(-34.7,0,-63.5),Vector3(45.7,0,-43.5),Vector3(44.7,0,-24),Vector3(-3.8,0,-67.7),Vector3(45.7,0,-53.3)]:
		for i in range(3):append_mesh("CornerChips",materials.rock,rock,c+Vector3(rng.randf_range(-.2,.2),.18,rng.randf_range(-.2,.2)),Vector3(.38,.16,.45),Vector3(0,rng.randf_range(0,6.28),0))
	# Static bronze wall fixtures and emissive cores reuse existing light pools: no extra lights.
	var lamps = [Vector3(-1.48,2.1,2),Vector3(1.48,2.1,-5),Vector3(-7.94,2.5,-24),Vector3(7.94,2.5,-24),Vector3(-23,2.1,-21.47),Vector3(-31,2.1,-21.47),Vector3(-39.94,2.1,-30),Vector3(-35.94,2.1,-60),Vector3(-22.06,2.1,-60),Vector3(34.06,2.1,-22),Vector3(45.94,2.1,-22),Vector3(33.06,2.1,-40),Vector3(46.94,2.1,-40),Vector3(1,2.5,-68.94),Vector3(13,2.5,-68.94),Vector3(7,2.5,-53.06),Vector3(19,2.5,-53.06),Vector3(29.06,2.5,-65),Vector3(46.94,2.5,-58),Vector3(34,2.5,-69.94),Vector3(42,2.5,-69.94),Vector3(53.5,3.5,-80.34)]
	for c in lamps:
		append_mesh("LampBronze",materials.bronze,cube,c+Vector3(0,-.2,0),Vector3(.24,.16,.24))
		append_mesh("LampBronze",materials.bronze,cube,c+Vector3(0,.02,0),Vector3(.035,.44,.035))
		append_mesh("LampGlow",materials.lamp_glow,cube,c,Vector3(.11,.23,.11))
	var env_node := WorldEnvironment.new()
	env_node.name="TombEnvironment"
	env_node.environment=env
	art.add_child(env_node)
	env_node.owner=art
	for key in batches:
		var data: Dictionary = batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=data.mesh
		multimesh.instance_count=data.transforms.size()
		for i in range(data.transforms.size()): multimesh.set_instance_transform(i,data.transforms[i])
		if multimesh.buffer.size() != multimesh.instance_count*12:
			push_error("Invalid persisted instance data: "+key)
			quit(1)
			return
		multimesh.take_over_path("res://art/batches/"+key+".tres")
		ResourceSaver.save(multimesh,"res://art/batches/"+key+".tres")
		var node := MultiMeshInstance3D.new()
		node.name=key
		node.multimesh=multimesh
		node.material_override=data.material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(node)
		node.owner=art
		saved_instances += multimesh.instance_count
	var packed := PackedScene.new()
	packed.pack(art)
	ResourceSaver.save(packed,"res://art/art_details.tscn")
	print("Saved static ArtDetails: ",batches.size()," MultiMesh batches / ",saved_instances," mesh instances; no added colliders or lights")
	source.free()
	art.free()
	quit(0)
