"""Offline tool: build art/props/decor_details.tscn (stone lions, hall guardians,
seal pedestals, sarcophagus) and hook it into tomb_corridor.tscn.

Run: python build_decor_details.py
Idempotent: re-running rewrites the decor scene and re-patches the main scene once.
All props are authored in world metres at the root (unit scale), like the candles.
"""
import io
import math
import os

ROOT = r"D:\Codex\three feet under\Three-Feet-Under-main\three-feet-under"
SCENE = os.path.join(ROOT, "tomb_corridor.tscn")
OUT = os.path.join(ROOT, "art", "props", "decor_details.tscn")

MAT = {
    "wall": "res://art/materials/wall.tres",
    "trim": "res://art/materials/trim.tres",
    "coffin": "res://art/materials/coffin.tres",
    "bronze": "res://art/materials/bronze.tres",
    "rock": "res://art/materials/rock.tres",
    "gold": "res://art/materials/seal_gold.tres",
    "blue": "res://art/materials/seal_blue.tres",
}

NEW_MATERIALS = {
    "res://art/materials/seal_gold.tres": """[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.86, 0.63, 0.26, 1)
metallic = 0.75
metallic_specular = 0.6
roughness = 0.3
""",
    "res://art/materials/seal_blue.tres": """[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.18, 0.46, 0.86, 1)
metallic = 0.55
metallic_specular = 0.65
roughness = 0.24
""",
}

# box: (kind, (sx, sy, sz), (x, y, z), material)
# cyl: (kind, (height, top_r, bottom_r, segments), (x, y, z), material)
LION = [
    ("Plinth", ("box", (1.02, 0.22, 0.86), (0, 0.11, 0), "trim")),
    ("Haunch", ("box", (0.64, 0.50, 0.60), (0, 0.47, -0.10), "wall")),
    ("Spine", ("box", (0.46, 0.34, 0.34), (0, 0.92, -0.04), "wall")),
    ("Chest", ("box", (0.50, 0.54, 0.30), (0, 0.55, 0.24), "wall")),
    ("Neck", ("box", (0.32, 0.24, 0.28), (0, 0.88, 0.28), "wall")),
    ("Mane", ("box", (0.68, 0.46, 0.26), (0, 1.02, 0.08), "wall")),
    ("Head", ("box", (0.40, 0.34, 0.36), (0, 1.10, 0.34), "wall")),
    ("Muzzle", ("box", (0.22, 0.14, 0.10), (0, 1.02, 0.55), "wall")),
    ("Jaw", ("box", (0.20, 0.08, 0.12), (0, 0.94, 0.54), "wall")),
    ("EyeL", ("box", (0.05, 0.04, 0.03), (-0.10, 1.16, 0.52), "bronze")),
    ("EyeR", ("box", (0.05, 0.04, 0.03), (0.10, 1.16, 0.52), "bronze")),
    ("EarL", ("box", (0.09, 0.12, 0.08), (-0.17, 1.31, 0.16), "wall")),
    ("EarR", ("box", (0.09, 0.12, 0.08), (0.17, 1.31, 0.16), "wall")),
    ("ForelegL", ("box", (0.12, 0.50, 0.13), (-0.20, 0.42, 0.28), "wall")),
    ("ForelegR", ("box", (0.12, 0.50, 0.13), (0.20, 0.42, 0.28), "wall")),
    ("PawL", ("box", (0.18, 0.10, 0.26), (-0.20, 0.20, 0.46), "wall")),
    ("PawR", ("box", (0.18, 0.10, 0.26), (0.20, 0.20, 0.46), "wall")),
    ("Tail", ("box", (0.12, 0.40, 0.14), (0, 0.58, -0.40), "wall")),
]


def pedestal(seal_mat):
    return [
        ("Base", ("box", (1.6, 0.20, 1.6), (0, 0.10, 0), "trim")),
        ("Step", ("box", (1.3, 0.16, 1.3), (0, 0.28, 0), "trim")),
        ("Column", ("box", (0.92, 0.78, 0.92), (0, 0.75, 0), "wall")),
        ("Cap", ("box", (1.14, 0.14, 1.14), (0, 1.21, 0), "trim")),
        ("SealRim", ("cyl", (0.10, 0.42, 0.42, 16), (0, 1.33, 0), "bronze")),
        ("SealDisc", ("cyl", (0.34, 0.34, 0.34, 16), (0, 1.55, 0), seal_mat)),
        ("SealBoss", ("cyl", (0.10, 0.10, 0.10, 8), (0, 1.77, 0), seal_mat)),
    ]


PEDESTAL_GOLD = pedestal("gold")
PEDESTAL_BLUE = pedestal("blue")

SARCOPHAGUS = [
    ("Base", ("box", (4.7, 0.26, 2.0), (0, 0.13, 0), "trim")),
    ("Body", ("box", (4.3, 0.98, 1.72), (0, 0.75, 0), "coffin")),
    ("Lid", ("box", (4.58, 0.20, 1.98), (0, 1.34, 0), "trim")),
    ("LidTop", ("box", (4.2, 0.10, 1.66), (0, 1.49, 0), "coffin")),
    ("PostA", ("box", (0.26, 1.34, 0.26), (-2.02, 0.67, -0.76), "trim")),
    ("PostB", ("box", (0.26, 1.34, 0.26), (2.02, 0.67, -0.76), "trim")),
    ("PostC", ("box", (0.26, 1.34, 0.26), (-2.02, 0.67, 0.76), "trim")),
    ("PostD", ("box", (0.26, 1.34, 0.26), (2.02, 0.67, 0.76), "trim")),
    ("PanelW", ("box", (0.06, 0.62, 1.40), (-2.17, 0.80, 0), "trim")),
    ("PanelE", ("box", (0.06, 0.62, 1.40), (2.17, 0.80, 0), "trim")),
    ("FootBlock", ("box", (1.1, 0.30, 1.9), (0, 0.15, 0), "rock")),
]

LAMPSTAND = [
    ("Base", ("box", (0.56, 0.16, 0.56), (0, 0.08, 0), "trim")),
    ("Column", ("cyl", (0.98, 0.085, 0.11, 10), (0, 0.65, 0), "wall")),
    ("Collar", ("box", (0.24, 0.08, 0.24), (0, 1.18, 0), "trim")),
    ("Bowl", ("cyl", (0.18, 0.30, 0.12, 12), (0, 1.31, 0), "bronze")),
]

GUARD = [
    ("Base", ("box", (0.94, 0.22, 0.74), (0, 0.11, 0), "trim")),
    ("BootL", ("box", (0.22, 0.16, 0.32), (-0.17, 0.30, 0.06), "wall")),
    ("BootR", ("box", (0.22, 0.16, 0.32), (0.17, 0.30, 0.06), "wall")),
    ("LegL", ("box", (0.18, 0.64, 0.20), (-0.16, 0.70, 0), "wall")),
    ("LegR", ("box", (0.18, 0.64, 0.20), (0.16, 0.70, 0), "wall")),
    ("Skirt", ("box", (0.58, 0.52, 0.36), (0, 1.14, 0), "wall")),
    ("Torso", ("box", (0.62, 0.50, 0.40), (0, 1.62, 0), "wall")),
    ("Shoulders", ("box", (0.80, 0.16, 0.44), (0, 1.92, 0), "wall")),
    ("Neck", ("box", (0.20, 0.10, 0.20), (0, 2.02, 0), "wall")),
    ("Head", ("box", (0.30, 0.32, 0.30), (0, 2.20, 0), "wall")),
    ("Helmet", ("cyl", (0.28, 0.03, 0.23, 10), (0, 2.49, 0), "wall")),
    ("HelmetBrim", ("box", (0.42, 0.05, 0.42), (0, 2.36, 0), "trim")),
    ("Shield", ("box", (0.07, 0.78, 0.58), (-0.44, 1.55, 0.12), "trim")),
    ("SpearShaft", ("cyl", (2.40, 0.028, 0.028, 8), (0.46, 1.30, 0.08), "wall")),
    ("SpearBlade", ("box", (0.06, 0.34, 0.06), (0.46, 2.66, 0.08), "bronze")),
    ("SpearBase", ("cyl", (0.08, 0.06, 0.06, 8), (0.46, 0.15, 0.08), "bronze")),
]

GROUPS = {
    "lion": ("StoneLions", LION),
    "pedestal_gold": ("SealPedestals", PEDESTAL_GOLD),
    "pedestal_blue": ("SealPedestals", PEDESTAL_BLUE),
    "sarcophagus": ("Sarcophagus", SARCOPHAGUS),
    "guard": ("HallGuards", GUARD),
    "lampstand": ("TombLampStands", LAMPSTAND),
}

# name, kind, world position (x, y, z), yaw degrees
PLACEMENTS = [
    ("Lion06West", "lion", (-36.6, 0.15, -92.4), -90, 1.4),
    ("Lion06East", "lion", (-36.6, 0.15, -87.6), -90, 1.4),
    ("Pedestal06", "pedestal_gold", (-35.2, 0.15, -90.0), -90),
    ("Lion09West", "lion", (57.6, 0.15, -64.6), 0, 1.4),
    ("Lion09East", "lion", (62.4, 0.15, -64.6), 0, 1.4),
    ("Pedestal09", "pedestal_blue", (60.0, 0.15, -65.6), 180),
    ("Sarcophagus11", "sarcophagus", (57.0, 0.75, -91.5), 90),
    ("Lamp11A", "lampstand", (54.7, 0.75, -95.3), 0),
    ("Lamp11B", "lampstand", (59.3, 0.75, -95.3), 0),
    ("Lamp11C", "lampstand", (54.7, 0.75, -87.7), 0),
    ("Lamp11D", "lampstand", (59.3, 0.75, -87.7), 0),
    ("GuardN1", "guard", (5.0, 0.15, -102.4), 0),
    ("GuardN2", "guard", (14.0, 0.15, -102.4), 0),
    ("GuardN3", "guard", (23.0, 0.15, -102.4), 0),
    ("GuardN4", "guard", (32.0, 0.15, -102.4), 0),
    ("GuardS1", "guard", (5.0, 0.15, -80.6), 180),
    ("GuardS2", "guard", (14.0, 0.15, -80.6), 180),
    ("GuardS3", "guard", (23.0, 0.15, -80.6), 180),
    ("GuardS4", "guard", (32.0, 0.15, -80.6), 180),
]

# ------------------------------------------------------------------- emit .tscn
sub_by_key = {}
sub_lines = []
sub_counter = [0]


def mesh_sub(shape):
    key = repr(shape)
    if key in sub_by_key:
        return sub_by_key[key]
    idx = sub_counter[0]
    sub_counter[0] += 1
    sid = "Mesh_%d" % idx
    sub_by_key[key] = sid
    if shape[0] == "box":
        sub_lines.append('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%g, %g, %g)\n'
                         % (sid, shape[1][0], shape[1][1], shape[1][2]))
    else:
        h, tr, br, seg = shape[1]
        sub_lines.append('[sub_resource type="CylinderMesh" id="%s"]\n'
                         'top_radius = %g\nbottom_radius = %g\nheight = %g\nradial_segments = %d\n'
                         % (sid, tr, br, h, seg))
    return sid


def xform(pos, yaw_deg, scale=1.0):
    c = math.cos(math.radians(yaw_deg)) * scale
    s = math.sin(math.radians(yaw_deg)) * scale
    return "Transform3D(%g, 0, %g, 0, %g, 0, %g, 0, %g, %g, %g, %g)" % (
        c, -s, scale, s, c, pos[0], pos[1], pos[2])


body = []
emitted_groups = []
for kind, (gname, parts) in GROUPS.items():
    items = [p for p in PLACEMENTS if p[1] == kind]
    if not items:
        continue
    unique_gname = gname if gname not in emitted_groups else gname + "_" + kind.split("_")[-1]
    emitted_groups.append(unique_gname)
    body.append('\n[node name="%s" type="Node3D" parent="."]' % unique_gname)
    for name, _, pos, yaw, *rest in items:
        sc = rest[0] if rest else 1.0
        body.append('\n[node name="%s" type="Node3D" parent="%s"]' % (name, unique_gname))
        body.append("transform = %s" % xform(pos, yaw, sc))
        for pname, spec in parts:
            shape = (spec[0], spec[1])
            ppos = spec[2]
            mat = spec[3]
            sid = mesh_sub(shape)
            body.append('\n[node name="%s" type="MeshInstance3D" parent="%s/%s"]'
                        % (pname, unique_gname, name))
            body.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)"
                        % (ppos[0], ppos[1], ppos[2]))
            body.append('mesh = SubResource("%s")' % sid)
            body.append('material_override = ExtResource("m_%s")' % mat)

ext_lines = []
for key, path in MAT.items():
    ext_lines.append('[ext_resource type="Material" path="%s" id="m_%s"]' % (path, key))

load_steps = len(ext_lines) + len(sub_lines) + 1
text = ('[gd_scene load_steps=%d format=3]\n\n' % load_steps
        + "\n".join(ext_lines) + "\n\n"
        + "\n".join(sub_lines) + "\n"
        + '\n[node name="DecorDetails" type="Node3D"]\n'
        + "\n".join(body) + "\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
for path, mat_text in NEW_MATERIALS.items():
    io.open(os.path.join(ROOT, path.replace("res://", "").replace("/", os.sep)),
            "w", encoding="utf-8", newline="\n").write(mat_text)
io.open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("wrote", OUT, len(text), "bytes, meshes", len(sub_lines), "placements", len(PLACEMENTS))

# --------------------------------------------------------- hook into main scene
s = io.open(SCENE, encoding="utf-8").read()
if 'ExtResource("40_decor")' in s:
    print("main scene already hooked")
else:
    lines = s.split("\n")
    last_ext = max(i for i, ln in enumerate(lines) if ln.startswith("[ext_resource"))
    lines.insert(last_ext + 1,
                 '[ext_resource type="PackedScene" path="res://art/props/decor_details.tscn" id="40_decor"]')
    ci = next(i for i, ln in enumerate(lines) if ln.startswith('[node name="Candles"'))
    j = ci + 1
    while j < len(lines) and not lines[j].startswith("[node "):
        j += 1
    lines.insert(j, '[node name="DecorDetails" parent="." instance=ExtResource("40_decor")]')
    gi = next(i for i, ln in enumerate(lines) if ln.startswith('[node name="GreyboxCoffin"'))
    if "visible = false" not in "\n".join(lines[gi:gi + 6]):
        k = gi + 1
        while k < len(lines) and not lines[k].startswith("[node "):
            k += 1
        lines.insert(k, "visible = false")
    s = "\n".join(lines)
    if not s.endswith("\n"):
        s += "\n"
    io.open(SCENE, "w", encoding="utf-8", newline="\n").write(s)
    print("main scene patched")
