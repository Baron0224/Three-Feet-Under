"""Offline tool: turn %TEMP%\tfu_candles.json into static MultiMesh .tres
batches plus art/candles.tscn, and hook the Candles node into tomb_corridor.tscn.
Run: python write_candle_batches.py   (writes resources and the scene; idempotent)
"""
import json, os

ROOT = r"D:\Codex\three feet under\Three-Feet-Under-main\three-feet-under"
D = json.load(open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_candles.json", encoding="utf-8"))
BOX = json.load(open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_scene_boxes.json", encoding="utf-8"))
floors = BOX["floors"]
walls = BOX["walls"]


def covers(b, x, z):
    px, py, pz = b["pos"]; sx, sy, sz = b["size"]
    return abs(x - px) <= sx / 2 + 0.02 and abs(z - pz) <= sz / 2 + 0.02


valid = []
dropped = 0
for c in D["candles"]:
    foot = None
    for b in floors:
        if covers(b, c["x"], c["z"]):
            top = b["pos"][1] + b["size"][1] / 2
            if abs(top - c["y"]) < 0.3:
                foot = b
                break
    if foot is None:
        dropped += 1
        continue
    valid.append(c)
print("valid", len(valid), "dropped(no floor under)", dropped)

# rebuild transformed instance lists from valid candles
import math

def matmul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]

def apply(M, v):
    return [M[i][0] * v[0] + M[i][1] * v[1] + M[i][2] * v[2] for i in range(3)]

def inst(R, sx, sy, sz, cx, cy, cz):
    c0 = apply(R, [sx, 0, 0]); c1 = apply(R, [0, sy, 0]); c2 = apply(R, [0, 0, sz])
    return [c0[0], c0[1], c0[2], cx, c1[0], c1[1], c1[2], cy, c2[0], c2[1], c2[2], cz]

bodies, pools, wicks, dishes = [], [], [], []
for c in valid:
    R = matmul(matmul(rot_y(c["yaw"]), rot_y(c["tdir"])), rot_x(c["tilt"]))
    bx, by, bz = c["x"], c["y"], c["z"]
    off = apply(R, [0, c["h"] / 2, 0])
    bodies.append(inst(R, c["r"], c["h"], c["r"], bx + off[0], by + off[1], bz + off[2]))
    off = apply(R, [0, c["h"] + 0.002, 0])
    pools.append(inst(R, c["pool_r"], 0.014, c["pool_r"], bx + off[0], by + off[1], bz + off[2]))
    off = apply(R, [0, c["h"] + 0.012, 0])
    wicks.append(inst(R, 0.0022, 0.024, 0.0022, bx + off[0], by + off[1], bz + off[2]))
    if c["dish"]:
        dishes.append(inst(R, 0.072, 0.02, 0.072, bx, by - 0.009, bz))

print("instances: bodies %d pools %d wicks %d dishes %d" % (len(bodies), len(pools), len(wicks), len(dishes)))

def buf(lst):
    return ", ".join("%.6f" % v for row in lst for v in row)

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8", newline="\n").write(text)

# ---- meshes ----
write(os.path.join(ROOT, "art/candles/candle_body.tres"), """[gd_resource type="CylinderMesh" format=3]

[resource]
top_radius = 0.82
bottom_radius = 1.0
height = 1.0
radial_segments = 20
rings = 2
""")

write(os.path.join(ROOT, "art/candles/candle_pool.tres"), """[gd_resource type="CylinderMesh" format=3]

[resource]
top_radius = 0.94
bottom_radius = 1.0
height = 1.0
radial_segments = 20
rings = 2
""")

write(os.path.join(ROOT, "art/candles/candle_wick.tres"), """[gd_resource type="CylinderMesh" format=3]

[resource]
top_radius = 0.55
bottom_radius = 1.0
height = 1.0
radial_segments = 10
rings = 1
""")

write(os.path.join(ROOT, "art/candles/candle_dish.tres"), """[gd_resource type="CylinderMesh" format=3]

[resource]
top_radius = 1.0
bottom_radius = 0.86
height = 1.0
radial_segments = 24
rings = 2
""")

# ---- materials ----
write(os.path.join(ROOT, "art/candles/wax.tres"), """[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.87, 0.83, 0.72, 1)
roughness = 0.52
metallic_specular = 0.35
""")

write(os.path.join(ROOT, "art/candles/wick.tres"), """[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.05, 0.04, 0.03, 1)
roughness = 1.0
metallic_specular = 0.1
""")

# ---- multimeshes ----
def mm(path, mesh_path, inst_list):
    write(os.path.join(ROOT, path), """[gd_resource type="MultiMesh" format=3]

[ext_resource type="CylinderMesh" path="res://art/candles/%s" id="1_mesh"]

[resource]
transform_format = 1
instance_count = %d
mesh = ExtResource("1_mesh")
buffer = PackedFloat32Array(%s)
""" % (mesh_path, len(inst_list), buf(inst_list)))

mm("art/batches/CandleBodies.tres", "candle_body.tres", bodies)
mm("art/batches/CandlePools.tres", "candle_pool.tres", pools)
mm("art/batches/CandleWicks.tres", "candle_wick.tres", wicks)
mm("art/batches/CandleDishes.tres", "candle_dish.tres", dishes)

# ---- candles scene ----
write(os.path.join(ROOT, "art/candles.tscn"), """[gd_scene format=3]

[ext_resource type="Material" path="res://art/candles/wax.tres" id="1_wax"]
[ext_resource type="Material" path="res://art/candles/wick.tres" id="2_wick"]
[ext_resource type="Material" path="res://art/materials/bronze.tres" id="3_bronze"]
[ext_resource type="MultiMesh" path="res://art/batches/CandleBodies.tres" id="4_body"]
[ext_resource type="MultiMesh" path="res://art/batches/CandlePools.tres" id="5_pool"]
[ext_resource type="MultiMesh" path="res://art/batches/CandleWicks.tres" id="6_wick_batch"]
[ext_resource type="MultiMesh" path="res://art/batches/CandleDishes.tres" id="7_dish"]

[node name="Candles" type="Node3D"]

[node name="WaxBodies" type="MultiMeshInstance3D" parent="."]
multimesh = ExtResource("4_body")
material_override = ExtResource("1_wax")

[node name="WaxPools" type="MultiMeshInstance3D" parent="."]
multimesh = ExtResource("5_pool")
material_override = ExtResource("1_wax")

[node name="Wicks" type="MultiMeshInstance3D" parent="."]
multimesh = ExtResource("6_wick_batch")
material_override = ExtResource("2_wick")

[node name="Dishes" type="MultiMeshInstance3D" parent="."]
multimesh = ExtResource("7_dish")
material_override = ExtResource("3_bronze")
""")

# ---- hook into tomb_corridor.tscn ----
scene_path = os.path.join(ROOT, "tomb_corridor.tscn")
s = open(scene_path, encoding="utf-8").read()
if "res://art/candles.tscn" not in s:
    lines = s.split("\n")
    # insert ext_resource after the last [ext_resource ...] line
    last = max(i for i, ln in enumerate(lines) if ln.startswith("[ext_resource"))
    lines.insert(last + 1, '[ext_resource type="PackedScene" path="res://art/candles.tscn" id="30_candles"]')
    s = "\n".join(lines)
    if not s.endswith("\n"):
        s += "\n"
    s += """

[node name="Candles" parent="." instance=ExtResource("30_candles")]
"""
    open(scene_path, "w", encoding="utf-8", newline="\n").write(s)
print("scene patched")
