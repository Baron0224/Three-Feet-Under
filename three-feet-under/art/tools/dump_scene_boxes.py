"""Offline tool: parse tomb_corridor.tscn node transforms and dump world-space
boxes of floors/walls/ceilings/rocks/others to %TEMP%\tfu_scene_boxes.json.
Run: python dump_scene_boxes.py   (read-only; scene must be saved first)

Handles both serializations: explicit `position`/`scale` properties (older saves)
and `transform = Transform3D(...)` (Godot 4.7 editor re-saves). Rotation is
honoured when present; the reported box is the axis-aligned bound of the
transformed box.
"""
import json, re, io

PATH = r"D:\Codex\three feet under\Three-Feet-Under-main\three-feet-under\tomb_corridor.tscn"
text = open(PATH, "r", encoding="utf-8").read()

lines = text.splitlines()
sections = []
cur = None
for ln in lines:
    if ln.startswith("["):
        if cur:
            sections.append(cur)
        cur = {"header": ln, "props": [], "order": len(sections)}
    elif cur is not None and ln.strip():
        cur["props"].append(ln.strip())
if cur:
    sections.append(cur)


def parse_header(h):
    m = re.match(r'\[(\w+)(.*)\]$', h)
    kind = m.group(1)
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(2)))
    return kind, attrs


subres = {}
extres = {}
nodes = []
for s in sections:
    kind, attrs = parse_header(s["header"])
    props = {}
    for p in s["props"]:
        if "=" in p:
            k, v = p.split("=", 1)
            props[k.strip()] = v.strip()
    if kind == "sub_resource":
        subres[attrs["id"]] = {"type": attrs.get("type"), "props": props}
    elif kind == "ext_resource":
        extres[attrs["id"]] = {"path": attrs.get("path"), "type": attrs.get("type")}
    elif kind == "node":
        nodes.append({"attrs": attrs, "props": props})


def vec(s):
    m = re.match(r'Vector3\(([^)]*)\)', s or "")
    if not m:
        return (0.0, 0.0, 0.0)
    return tuple(float(x) for x in m.group(1).split(","))


def floats(s):
    m = re.search(r'\(([^)]*)\)', s or "")
    body = m.group(1) if m else (s or "")
    return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:e[-+]?\d+)?', body)]


def sub_id(s):
    m = re.match(r'SubResource\("([^"]+)"\)', s or "")
    return m.group(1) if m else None


IDENT = (1.0, 0.0, 0.0, 0.0,
         0.0, 1.0, 0.0, 0.0,
         0.0, 0.0, 1.0, 0.0)


def parse_transform(props):
    """Return 12 floats: basis columns x,y,z then origin (Godot Transform3D order)."""
    t = props.get("transform")
    if t:
        v = floats(t)
        if len(v) >= 12:
            return tuple(v[:12])
    pos = vec(props.get("position"))
    sc = vec(props.get("scale", "Vector3(1,1,1)"))
    return (sc[0], 0.0, 0.0,
            0.0, sc[1], 0.0,
            0.0, 0.0, sc[2],
            pos[0], pos[1], pos[2])


def mat_mul(a, b):
    """a @ b for 3x4 row-major-ish transform tuples (columns x,y,z + origin)."""
    def col(m, i):
        return (m[i * 3 + 0], m[i * 3 + 1], m[i * 3 + 2])
    ax, ay, az = col(a, 0), col(a, 1), col(a, 2)
    ao = (a[9], a[10], a[11])
    bx, by, bz = col(b, 0), col(b, 1), col(b, 2)
    bo = (b[9], b[10], b[11])

    def apply(v):
        return (ax[0] * v[0] + ay[0] * v[1] + az[0] * v[2],
                ax[1] * v[0] + ay[1] * v[1] + az[1] * v[2],
                ax[2] * v[0] + ay[2] * v[1] + az[2] * v[2])

    ox, oy, oz = apply(bo)
    return (*(apply(bx)), *(apply(by)), *(apply(bz)),
            ox + ao[0], oy + ao[1], oz + ao[2])


def build_local(props):
    return parse_transform(props)


def mat_apply(m, v):
    return (m[0] * v[0] + m[3] * v[1] + m[6] * v[2] + m[9],
            m[1] * v[0] + m[4] * v[1] + m[7] * v[2] + m[10],
            m[2] * v[0] + m[5] * v[1] + m[8] * v[2] + m[11])


byname = {}
for n in nodes:
    parent = n["attrs"].get("parent")
    name = n["attrs"]["name"]
    path = name if parent in (None, ".") else parent + "/" + name
    n["path"] = path
    byname[path] = n

world_cache = {}


def world(n):
    path = n["path"]
    if path in world_cache:
        return world_cache[path]
    local = build_local(n["props"])
    parent = n["attrs"].get("parent")
    if parent in (None, "."):
        w = local
    else:
        p = byname.get(parent)
        w = mat_mul(world(p), local) if p else local
    world_cache[path] = w
    return w


def mesh_size(n):
    mid = sub_id(n["props"].get("mesh"))
    if mid and mid in subres:
        s = subres[mid]["props"].get("size")
        if s:
            return vec(s)
    return None


out = {"floors": [], "walls": [], "ceilings": [], "rocks": [], "others": []}
for n in nodes:
    ntype = n["attrs"].get("type")
    if ntype != "MeshInstance3D":
        continue
    mat = n["props"].get("material_override", "")
    pos_m = n["props"].get("position")
    path = n["path"]
    m = world(n)
    size = mesh_size(n)
    if size is None:
        continue  # primitives without explicit size are skipped
    center = mat_apply(m, (0.0, 0.0, 0.0))
    half = [size[i] * 0.5 for i in range(3)]
    # AABB half extents = |B| @ half
    axes = ((m[0], m[3], m[6]), (m[1], m[4], m[7]), (m[2], m[5], m[8]))
    wext = [sum(abs(axes[i][j]) * half[j] for j in range(3)) for i in range(3)]
    entry = {"name": n["attrs"]["name"], "path": path,
             "parent": n["attrs"].get("parent"),
             "pos": [round(v, 4) for v in center],
             "size": [round(max(0.0, 2 * wext[i]), 4) for i in range(3)],
             "mat": mat}
    if "Art_floor" in mat:
        out["floors"].append(entry)
    elif "Art_wall" in mat:
        out["walls"].append(entry)
    elif "Art_ceiling" in mat:
        out["ceilings"].append(entry)
    elif "Art_rock" in mat:
        out["rocks"].append(entry)
    else:
        out["others"].append(entry)

print("counts:", {k: len(v) for k, v in out.items()})
json.dump(out, open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_scene_boxes.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)

for f in sorted(out["floors"], key=lambda f: -f["size"][0] * f["size"][2])[:14]:
    print("FLOOR", f["name"], f["pos"], f["size"])
