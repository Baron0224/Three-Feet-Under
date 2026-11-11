extends SceneTree

var _aabb := AABB()
var _got := false

func _init():
	var p := "res://art/models/coffin_heavy.glb"
	if not FileAccess.file_exists(p):
		print("COFFIN_MISSING: ", p)
		quit(1)
		return
	var scn : PackedScene = load(p)
	if scn == null:
		print("COFFIN_LOAD_FAIL")
		quit(1)
		return
	var inst = scn.instantiate()
	get_root().add_child(inst)
	_traverse(inst, 0)
	print("COFFIN_AABB pos=", _aabb.position, " size=", _aabb.size)
	print("COFFIN_OK loaded=", _got)
	inst.queue_free()
	quit(0)

func _traverse(n: Node, depth: int) -> void:
	if n is MeshInstance3D:
		var b := (n as MeshInstance3D).get_aabb()
		if not _got:
			_aabb = b
			_got = true
		else:
			_aabb = _aabb.merge(b)
	if depth > 10:
		return
	for ch in n.get_children():
		_traverse(ch, depth + 1)