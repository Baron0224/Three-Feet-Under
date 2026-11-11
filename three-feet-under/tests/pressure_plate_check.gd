extends SceneTree

## Headless smoke for Room04 pressure-plate puzzle.
## Godot --headless --path . --script res://tests/pressure_plate_check.gd

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func ticks(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://tomb_corridor.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var puzzle: Node3D = scene.get_node("PressurePlatePuzzle")
	var player: CharacterBody3D = scene.get_node("player")
	await ticks(12)

	check(puzzle != null, "PressurePlatePuzzle present")
	check(player != null, "player present")
	var seq: PackedInt32Array = puzzle.correct_sequence
	check(seq == PackedInt32Array([0, 1, 2, 3]), "default clockwise sequence NW→NE→SE→SW")
	check(not puzzle.is_solved(), "starts unsolved")

	var plates := puzzle.get_node_or_null("Gen_Plates")
	check(plates != null and plates.get_child_count() == 4, "four generated plates")
	var gate := puzzle.get_node_or_null("Gen_Gate")
	check(gate != null and gate.get_node_or_null("Slab") != null, "gate slab present")
	var clue := puzzle.get_node_or_null("Gen_ClueCarving")
	check(clue != null, "clue carving present")

	var gate_world: Vector3 = puzzle.to_global(puzzle.gate_local_offset)
	check(absf(gate_world.x + 54.0) < 0.4, "gate near Room04 north opening X")
	check(absf(gate_world.z + 52.65) < 0.5, "gate near Room04 north opening Z")

	# Soft-fail path: step SE first (index 2) which is wrong for start.
	player.global_position = puzzle.to_global(Vector3(puzzle.plate_spacing * 0.5, 1.1, puzzle.plate_spacing * 0.5))
	player.velocity = Vector3.ZERO
	await ticks(20)
	check(not puzzle.is_solved(), "wrong first plate does not solve")
	await ticks(40)
	check(int(puzzle.get("_progress")) == 0, "progress reset after soft fail")

	# Correct clockwise walk: NW → NE → SE → SW.
	var order := [0, 1, 2, 3]
	for idx in order:
		var half := puzzle.plate_spacing * 0.5
		var local := Vector3.ZERO
		match int(idx):
			0: local = Vector3(-half, 1.1, -half)
			1: local = Vector3(half, 1.1, -half)
			2: local = Vector3(half, 1.1, half)
			3: local = Vector3(-half, 1.1, half)
		player.global_position = puzzle.to_global(local)
		player.velocity = Vector3.ZERO
		await ticks(18)

	await ticks(30)
	check(puzzle.is_solved(), "clockwise sequence solves puzzle")
	# Gate should be rising or open.
	var slab: Node3D = gate.get_node("Slab")
	check(slab.position.y > puzzle.opening_height * 0.5 + 0.2 or puzzle.get("_opening") or (puzzle.get_node("Gen_Gate/Slab/StaticBody3D") as StaticBody3D).collision_layer == 0, "gate rises after solve")

	print("pressure_plate_check: %s/%s passed" % [checks - failures, checks])
	quit(1 if failures else 0)
