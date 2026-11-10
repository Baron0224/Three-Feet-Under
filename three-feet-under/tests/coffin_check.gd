extends SceneTree
func _init():
	var ps = load("res://art/models/coffin_heavy.glb")
	if ps == null:
		print("COFFIN FAIL: null"); quit(1); return
	var inst = ps.instantiate()
	var mi = null
	for c in inst.get_children():
		if c is MeshInstance3D: mi = c
	if mi == null:
		print("COFFIN FAIL: no mi"); quit(1); return
	var a = mi.get_aabb()
	print("COFFIN_AABB pos=", a.position, " size=", a.size)
	print("COFFIN_OK")
	quit()
