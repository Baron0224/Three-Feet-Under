extends SceneTree

func _init():
    var ps = load("res://tomb_corridor.tscn")
    if ps == null:
        print("COFFIN FAIL: scene null")
        quit(1); return
    var root = ps.instantiate()
    root.add_child.call_deferred(root)  # not needed standalone
    var found = []
    _walk(root, found)
    if found.is_empty():
        print("COFFIN FAIL: no coffin instance found")
    else:
        for info in found:
            print("COFFIN_GLOBAL ", info)
    print("COFFIN_OK loaded=true found=", found.size())
    quit()

func _walk(n, out):
    if n.name == "Coffin":
        var gp = n.global_transform.origin
        var mi = null
        for c in n.get_children():
            if c is MeshInstance3D:
                mi = c
        if mi:
            var aabb = mi.get_aabb()
            # transform to global
            var g = n.global_transform
            var sz = aabb.size
            var ori = g * aabb.get_center() - Vector3(sz.x/2, sz.y/2, sz.z/2)
            out.append("%s world_origin=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)" % [n.get_path(), ori.x, ori.y, ori.z, sz.x, sz.y, sz.z])
    for c in n.get_children():
        _walk(c, out)
