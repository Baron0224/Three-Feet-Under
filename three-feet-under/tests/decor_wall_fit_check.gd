extends SceneTree
## Wall decor fit audit.
##
## Loads tomb_corridor.tscn and verifies that every relief band / wall niche in
## art/props/decor_details.tscn is actually backed by a wall: the face that sits
## against the wall must be fully covered, and nothing may stick out more than
## 15 cm from the wall surface.
##
## Run (from three-feet-under/):
##   godot --headless --path . --fixed-fps 60 --script res://tests/decor_wall_fit_check.gd
## Exit code 0 = clean, 1 = unsupported / oversized decor.

const SCENE := "res://tomb_corridor.tscn"
const COVER_MIN := 0.995

var _walls: Array = []   # Array[AABB]
var _targets: Array = [] # Array[[name, AABB]]


func _init() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		printerr("cannot load ", SCENE)
		quit(2)
		return
	var root: Node = packed.instantiate()
	_walk(root, false)
	root.free()

	var failures := 0
	var oversized := 0
	for t in _targets:
		var name: String = t[0]
		var bb: AABB = t[1]
		var axis := 0 if bb.size.x < bb.size.z else 2
		var best := -1.0
		var best_side := 0
		for side in [-1, 1]:
			var cov := _coverage(bb, axis, side)
			if cov > best:
				best = cov
				best_side = side
		var wall_face: float = bb.position[axis] if best_side < 0 else bb.end[axis]
		var front_face: float = bb.end[axis] if best_side < 0 else bb.position[axis]
		var protrusion: float = absf(front_face - wall_face)
		print("%-16s cover=%.3f protrusion=%.3fm pos=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)"
			% [name, best, protrusion, bb.position.x, bb.position.y, bb.position.z,
			bb.size.x, bb.size.y, bb.size.z])
		if best < COVER_MIN:
			failures += 1
			printerr("UNSUPPORTED %s: only %.1f%% backed by wall" % [name, best * 100.0])
		if protrusion > 0.15:
			oversized += 1
			printerr("OVERSIZED %s: sticks out %.3fm" % [name, protrusion])

	print("DECOR FIT: targets=", _targets.size(), " walls=", _walls.size(),
		" unsupported=", failures, " oversized=", oversized)
	quit(0 if failures == 0 and oversized == 0 else 1)


func _walk(node: Node, in_decor: bool) -> void:
	var is_decor := in_decor or _is_decor_root(node)
	if not is_decor and node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is BoxMesh:
			var sz: Vector3 = (mesh as BoxMesh).size
			if sz.y >= 2.0 and sz.y <= 9.0:
				_walls.append(_global_aabb(node as MeshInstance3D))
	if is_decor and not (node is MeshInstance3D):
		var nm := str(node.name)
		if nm.begins_with("ReliefBand") or nm.begins_with("Niche"):
			_targets.append([nm, _subtree_aabb(node as Node3D)])
	for c in node.get_children():
		_walk(c, is_decor)


func _is_decor_root(node: Node) -> bool:
	var nm := str(node.name)
	return nm == "DecorDetails" or nm == "decor_details" or nm.begins_with("WallReliefs") \
		or nm.begins_with("WallNiches")


func _global_aabb(mi: MeshInstance3D) -> AABB:
	return _global_xform(mi) * mi.get_aabb()


func _global_xform(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _subtree_aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var a := _global_aabb(c as MeshInstance3D)
			if first:
				bb = a
				first = false
			else:
				bb = bb.merge(a)
	return bb


func _coverage(bb: AABB, axis: int, side: int) -> float:
	var depth := 0.012
	var pos := bb.position
	var size := bb.size
	var hits := 0
	var total := 0
	var u_axis := 2 if axis == 0 else 0
	var n_u := 25
	var n_y := 3
	for i in n_u:
		for j in n_y:
			var u: float = pos[u_axis] + size[u_axis] * (float(i) + 0.5) / float(n_u)
			var y: float = pos.y + size.y * (float(j) + 0.5) / float(n_y)
			var p := Vector3.ZERO
			if axis == 0:
				p = Vector3((pos.x - depth) if side < 0 else (pos.x + size.x + depth), y, u)
			else:
				p = Vector3(u, y, (pos.z - depth) if side < 0 else (pos.z + size.z + depth))
			total += 1
			for w in _walls:
				if (w as AABB).has_point(p):
					hits += 1
					break
	return float(hits) / float(total)