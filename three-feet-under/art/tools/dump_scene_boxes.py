"""Offline tool: parse tomb_corridor.tscn node transforms and dump world-space
boxes of floors/walls/ceilings/rocks/others to %TEMP%\tfu_scene_boxes.json.
Run: python dump_scene_boxes.py   (read-only; scene must be saved first)
"""
import json, re, sys, io

PATH = r"D:\Codex\three feet under\Three-Feet-Under-main\three-feet-under\tomb_corridor.tscn"
text = open(PATH, "r", encoding="utf-8").read()

lines = text.splitlines()
sections = []  # (header, props dict, order)
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

def sub_id(s):
    m = re.match(r'SubResource\("([^"]+)"\)', s or "")
    return m.group(1) if m else None

# build hierarchy
byname = {}
for n in nodes:
    path = (n["attrs"].get("parent") or ".") + "/" + n["attrs"]["name"] if n["attrs"].get("parent") not in (None, ".") else n["attrs"]["name"]
    n["path"] = path
    byname[path] = n

def world_of(n):
    # returns (pos, scale, parent_path)
    p = n["attrs"].get("parent")
    if p in (None, "."):
        base_pos = (0.0, 0.0, 0.0); base_scale = (1.0, 1.0, 1.0)
    else:
        parent = byname.get(p)
        if parent is None:
            base_pos = (0.0, 0.0, 0.0); base_scale = (1.0, 1.0, 1.0)
        else:
            base_pos, base_scale, _ = world_of(parent)
    lp = vec(n["props"].get("position"))
    ls = vec(n["props"].get("scale", "Vector3(1,1,1)"))
    return (tuple(base_pos[i] + base_scale[i] * lp[i] for i in range(3)),
            tuple(base_scale[i] * ls[i] for i in range(3)),
            p)

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
    path = n["path"]
    pos, sc, parent = world_of(n)
    sz = mesh_size(n)
    if sz is None:
        sz = (1.0, 1.0, 1.0)
    wsize = tuple(sz[i] * abs(sc[i]) for i in range(3))
    entry = {"name": n["attrs"]["name"], "path": path, "parent": parent,
             "pos": [round(v, 4) for v in pos],
             "size": [round(v, 4) for v in wsize],
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
json.dump(out, open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_scene_boxes.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# print floors compactly
for f in out["floors"]:
    print("FLOOR", f["name"], f["pos"], f["size"])
