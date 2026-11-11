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
    "clay": "res://art/materials/clay.tres",
    "brick": "res://art/materials/brick.tres",
    "vermilion": "res://art/materials/vermilion.tres",
    "gold_ink": "res://art/materials/gold_ink.tres",
    "relief": "res://art/materials/relief.tres",
    "dark": "res://art/materials/stone_dark.tres",
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
    "res://art/materials/clay.tres": """[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://art/shaders/world_clay.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/clay_color = Color(0.62, 0.42, 0.28, 1)
shader_parameter/dark_color = Color(0.46, 0.30, 0.20, 1)
shader_parameter/scale_m = 1.0
""",
    "res://art/materials/gold_ink.tres": """[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.93, 0.78, 0.30, 1)
metallic = 0.8
metallic_specular = 0.6
roughness = 0.25
""",
    # 画像石面板：比墙石料亮一档的浅灰暖石，让"嵌进墙里的浮雕"自己读得出来
    "res://art/materials/relief.tres": """[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://art/shaders/world_stone.gdshader" id="1"]

[resource]
shader = ExtResource("1")
shader_parameter/stone_color = Color(0.44, 0.41, 0.36, 1)
shader_parameter/block_size = Vector2(4.0, 1.4)
shader_parameter/joint_width = 0.004
shader_parameter/relief = 0.008
shader_parameter/rock_mode = 0
shader_parameter/wear = 0.55
""",
    # 深色暖灰石：顶门石、壁龛内壁（原来用冷灰 rock，在火光下发蓝像金属）
    "res://art/materials/stone_dark.tres": """[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://art/shaders/world_stone.gdshader" id="1"]

[resource]
shader = ExtResource("1")
shader_parameter/stone_color = Color(0.30, 0.27, 0.23, 1)
shader_parameter/block_size = Vector2(1, 1)
shader_parameter/joint_width = 0.018
shader_parameter/relief = 0.012
shader_parameter/rock_mode = 1
shader_parameter/wear = 0.75
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

# Rounded coffin modeled in Blender (build_coffin_han.py -> coffin_heavy.glb).
# The GLB is grounded at local y=0 and spans ~4.6 long (X) x 2.0 wide (Z) x 1.49 tall.
# Original boxy SARCOPHAGUS replaced by a single packed-scene instance; the
# "glb" part special-cases the writer to emit an instance node instead of a
# MeshInstance3D built from primitives.
SARCOPHAGUS = [
    ("Coffin", ("glb", "res://art/models/coffin_heavy.glb", (0, 0.0, 0), "coffin")),
]

LAMPSTAND = [
    ("Base", ("box", (0.56, 0.16, 0.56), (0, 0.08, 0), "trim")),
    ("Column", ("cyl", (0.98, 0.085, 0.11, 10), (0, 0.65, 0), "wall")),
    ("Collar", ("box", (0.24, 0.08, 0.24), (0, 1.18, 0), "trim")),
    ("Bowl", ("cyl", (0.18, 0.30, 0.12, 12), (0, 1.31, 0), "bronze")),
]

# burial pottery jar, ~0.65 m tall
VESSEL = [
    ("Body", ("cyl", (0.36, 0.15, 0.095, 14), (0, 0.22, 0), "clay")),
    ("Neck", ("cyl", (0.12, 0.075, 0.075, 12), (0, 0.46, 0), "clay")),
    ("Rim", ("cyl", (0.05, 0.085, 0.085, 14), (0, 0.545, 0), "clay")),
    ("Lid", ("cyl", (0.07, 0.055, 0.085, 12), (0, 0.61, 0), "bronze")),
]

# bronze tripod ding (cauldron), ~0.42 m tall including handle span
DING = [
    ("Bowl", ("cyl", (0.20, 0.27, 0.16, 14), (0, 0.13, 0), "bronze")),
    ("RimBand", ("cyl", (0.06, 0.29, 0.28, 14), (0, 0.26, 0), "bronze")),
    ("LegA", ("box", (0.07, 0.16, 0.07), (-0.14, 0.08, 0.12), "bronze")),
    ("LegB", ("box", (0.07, 0.16, 0.07), (0.14, 0.08, 0.12), "bronze")),
    ("LegC", ("box", (0.07, 0.16, 0.07), (0, 0.08, -0.16), "bronze")),
    ("HandleL", ("box", (0.24, 0.05, 0.06), (-0.31, 0.24, 0), "bronze")),
    ("HandleR", ("box", (0.24, 0.05, 0.06), (0.31, 0.24, 0), "bronze")),
]

# wall niche: trim frame + dark recess + little figurine and offering bowl
# 原点在墙面：框只凸出 10cm，背板贴在墙面上（不再整只壁龛浮空 8–30cm）
NICHE = [
    ("Top", ("box", (1.02, 0.09, 0.08), (0, 0.95, 0.04), "trim")),
    ("Bottom", ("box", (1.02, 0.09, 0.08), (0, 0.045, 0.04), "trim")),
    ("PostL", ("box", (0.09, 0.86, 0.08), (-0.465, 0.5, 0.04), "trim")),
    ("PostR", ("box", (0.09, 0.86, 0.08), (0.465, 0.5, 0.04), "trim")),
    ("Back", ("box", (1.02, 0.86, 0.03), (0, 0.5, 0.012), "dark")),
    ("Figurine", ("box", (0.10, 0.22, 0.06), (0, 0.30, 0.055), "trim")),
    ("Bowl", ("cyl", (0.05, 0.055, 0.055, 12), (0, 0.16, 0.045), "bronze")),
]

# stone offering table in front of the sarcophagus
ALTAR = [
    ("Top", ("box", (2.4, 0.12, 0.9), (0, 0.66, 0), "trim")),
    ("LeftLeg", ("box", (0.2, 0.60, 0.7), (-1.0, 0.30, 0), "wall")),
    ("RightLeg", ("box", (0.2, 0.60, 0.7), (1.0, 0.30, 0), "wall")),
    ("BowlL", ("cyl", (0.12, 0.14, 0.08, 12), (-0.7, 0.78, 0), "bronze")),
    ("BowlC", ("cyl", (0.12, 0.14, 0.08, 12), (0, 0.78, 0), "bronze")),
    ("BowlR", ("cyl", (0.12, 0.14, 0.08, 12), (0.7, 0.78, 0), "bronze")),
]

# vertical spear stand with two spears
SPEARRACK = [
    ("Base", ("box", (0.7, 0.10, 0.26), (0, 0.05, 0), "trim")),
    ("PostL", ("box", (0.08, 0.8, 0.08), (-0.28, 0.45, 0), "wall")),
    ("PostR", ("box", (0.08, 0.8, 0.08), (0.28, 0.45, 0), "wall")),
    ("Cross", ("box", (0.64, 0.07, 0.07), (0, 0.75, 0), "trim")),
    ("Spear1", ("cyl", (1.35, 0.025, 0.025, 8), (-0.12, 0.73, 0), "wall")),
    ("Blade1", ("box", (0.05, 0.18, 0.05), (-0.12, 1.5, 0), "bronze")),
    ("Spear2", ("cyl", (1.35, 0.025, 0.025, 8), (0.11, 0.73, 0), "wall")),
    ("Blade2", ("box", (0.05, 0.18, 0.05), (0.11, 1.5, 0), "bronze")),
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

# ---- 东汉画像石浮雕带：嵌进墙里的浅浮雕长条 + 低凸纹样 ----
# 每段面板宽 w（沿墙方向）、高 1.02m。石板只 5cm 厚、3cm 埋进墙里、只凸出 2cm，
# 纹样再压在 4.5cm 浅层上（合计外凸不到 6cm）——看上去像"刻在墙上"，
# 而不是一块浮离墙面 20cm、隔着缝的黑板。
def relief_band(w, pattern):
    """w: band width in metres. pattern: 'procession' | 'cloud' | 'guardian'.
    Returns parts in local coords: origin on the wall face, +z 朝室内（由 yaw 决定）."""
    parts = [
        # 石板：后脸 -0.03（埋进墙 3cm），前脸 +0.02（凸出 2cm）
        ("Slab", ("box", (w, 1.02, 0.05), (0, 3.10, -0.005), "relief")),
        ("RimL", ("box", (0.10, 1.06, 0.06), (-w / 2 + 0.05, 3.10, 0.005), "bronze")),
        ("RimR", ("box", (0.10, 1.06, 0.06), (w / 2 - 0.05, 3.10, 0.005), "bronze")),
        ("RimT", ("box", (w, 0.10, 0.06), (0, 3.63, 0.005), "bronze")),
        ("RimB", ("box", (w, 0.10, 0.06), (0, 2.57, 0.005), "bronze")),
    ]
    if pattern == "procession":
        # 车马出行：两轮车 + 一马 + 驭者，块状剪影，沿墙方向排开
        parts += [
            ("WheelL", ("box", (0.80, 0.80, 0.16), (-w / 2 + 1.1, 3.10, 0.06), "wall")),
            ("WheelR", ("box", (0.80, 0.80, 0.16), (-w / 2 + 2.2, 3.10, 0.06), "wall")),
            ("Cart", ("box", (1.30, 0.55, 0.14), (-w / 2 + 1.65, 3.42, 0.06), "vermilion")),
            ("Shaft", ("box", (1.8, 0.10, 0.10), (0.1, 3.10, 0.06), "wall")),
            ("HorseBody", ("box", (1.6, 0.62, 0.16), (1.35, 3.10, 0.06), "wall")),
            ("HorseHead", ("box", (0.55, 0.40, 0.14), (2.35, 3.25, 0.06), "wall")),
            ("HorseLeg1", ("box", (0.14, 0.55, 0.12), (1.0, 2.85, 0.06), "wall")),
            ("HorseLeg2", ("box", (0.14, 0.55, 0.12), (1.7, 2.85, 0.06), "wall")),
            ("Driver", ("box", (0.35, 0.75, 0.14), (2.5, 3.30, 0.06), "vermilion")),
            ("HubL", ("box", (0.14, 0.14, 0.08), (-w / 2 + 1.1, 3.10, 0.10), "gold_ink")),
            ("HubR", ("box", (0.14, 0.14, 0.08), (-w / 2 + 2.2, 3.10, 0.10), "gold_ink")),
        ]
    elif pattern == "cloud":
        # 云气纹：四组 S 形云头 + 小圆点，抽象回旋；云头尖涂朱、云心点金
        n = 4
        step = (w - 0.8) / n
        for i in range(n):
            cx = -w / 2 + 0.65 + i * step
            parts += [
                ("CloudA%d" % i, ("box", (0.55, 0.30, 0.14), (cx - 0.15, 3.30, 0.06), "wall")),
                ("CloudB%d" % i, ("box", (0.42, 0.34, 0.14), (cx + 0.12, 3.12, 0.06), "wall")),
                ("CloudC%d" % i, ("box", (0.24, 0.20, 0.14), (cx + 0.05, 3.48, 0.06), "vermilion")),
                ("CloudD%d" % i, ("box", (0.14, 0.14, 0.14), (cx - 0.28, 3.05, 0.06), "wall")),
                ("CloudDot%d" % i, ("box", (0.09, 0.09, 0.09), (cx + 0.24, 3.28, 0.10), "gold_ink")),
            ]
    elif pattern == "guardian":
        # 双武士/门吏剪影：左右对称；日轮与矛杆涂朱、日轮描金边
        cx = w / 2
        for sign in (1, -1):
            ox = sign * cx * 0.62
            parts += [
                ("GHead%d" % (0 if sign > 0 else 1), ("box", (0.42, 0.40, 0.14), (ox, 3.48, 0.06), "wall")),
                ("GBody%d" % (0 if sign > 0 else 1), ("box", (0.70, 0.72, 0.16), (ox, 3.10, 0.06), "wall")),
                ("GArm%d" % (0 if sign > 0 else 1), ("box", (0.30, 0.55, 0.14), (ox + sign * 0.45, 3.12, 0.06), "wall")),
                ("GShaft%d" % (0 if sign > 0 else 1), ("box", (0.08, 1.1, 0.10), (ox + sign * 1.0, 3.10, 0.06), "vermilion")),
                ("GHem%d" % (0 if sign > 0 else 1), ("box", (0.74, 0.05, 0.10), (ox, 2.74, 0.08), "gold_ink")),
            ]
        parts += [
            # 日轮/月轮：薄圆盘立起来贴墙（pitch 90 把圆柱轴从 Y 转到 Z），否则会平躺着扎出墙 30cm
            ("Sun", ("cyl", (0.045, 0.16, 0.16, 12), (0, 3.42, 0.10), "vermilion", 0.0, 90.0)),
            ("SunRim", ("cyl", (0.045, 0.19, 0.19, 12), (0, 3.42, 0.04), "gold_ink", 0.0, 90.0)),
            ("Moon", ("cyl", (0.045, 0.13, 0.13, 12), (0, 2.86, 0.04), "wall", 0.0, 90.0)),
        ]
    # 纹样压成浅浮雕：厚度统一 4.5cm，出墙偏移 = 0.015 + 原偏移*0.3（原 0.06→0.033）
    shallow = []
    for name, spec in parts:
        kind, size, pos, mat = spec[0], spec[1], spec[2], spec[3]
        extra = spec[4:]
        if mat not in ("trim", "relief"):
            if kind == "box":
                size = (size[0], size[1], 0.045)
            else:
                size = (0.045,) + tuple(size[1:])
            pos = (pos[0], pos[1], 0.015 + pos[2] * 0.3)
        shallow.append((name, (kind, size, pos, mat) + tuple(extra)))
    return shallow


# ---- 博山炉（汉代熏香炉）：底盘 + 立柱 + 炉身 + 仙山峰形盖 ----
BOSHAN = [
    ("Base", ("cyl", (0.06, 0.30, 0.30, 14), (0, 0.03, 0), "bronze")),
    ("Stem", ("cyl", (0.34, 0.05, 0.05, 8), (0, 0.23, 0), "bronze")),
    ("Bowl", ("cyl", (0.16, 0.20, 0.12, 12), (0, 0.46, 0), "bronze")),
    ("LidLow", ("cyl", (0.12, 0.22, 0.18, 12), (0, 0.60, 0), "bronze")),
    ("LidPeak", ("sphere", (0.11, 24, 12), (0, 0.72, 0), "bronze")),
    ("Knob", ("sphere", (0.035, 24, 12), (0, 0.84, 0), "bronze")),
    ("FinL", ("box", (0.06, 0.14, 0.06), (-0.12, 0.66, 0), "bronze")),
    ("FinR", ("box", (0.06, 0.14, 0.06), (0.12, 0.66, 0), "bronze")),
]

# ---- 陶俑（随葬小人）----
FIGURINE = [
    ("Base", ("box", (0.16, 0.05, 0.16), (0, 0.025, 0), "clay")),
    ("Skirt", ("box", (0.13, 0.22, 0.12), (0, 0.14, 0), "clay")),
    ("Body", ("box", (0.10, 0.22, 0.09), (0, 0.35, 0), "clay")),
    ("Head", ("sphere", (0.05, 24, 12), (0, 0.50, 0), "clay")),
    ("Hat", ("box", (0.11, 0.035, 0.11), (0, 0.57, 0), "clay")),
    ("ArmL", ("box", (0.03, 0.16, 0.08), (-0.07, 0.36, 0), "clay")),
    ("ArmR", ("box", (0.03, 0.16, 0.08), (0.07, 0.36, 0), "clay")),
]

# ---- 五铢钱（几枚小铜钱平铺，局部 yaw 旋转、pitch 90° 平放）----
def coin(x, z, ry):
    return ("Coin", ("cyl", (0.025, 0.11, 0.11, 12), (x, 0.16, z), "bronze"), ry, 90)


# ---- 陶仓（东汉明器：圆身带顶盖粮仓）约 1.05 m 高 ----
GRANARY = [
    ("Base", ("box", (0.88, 0.10, 0.88), (0, 0.05, 0), "clay")),
    ("RimBase", ("cyl", (0.10, 0.45, 0.50, 14), (0, 0.18, 0), "clay")),
    ("Body", ("cyl", (0.62, 0.34, 0.42, 14), (0, 0.55, 0), "clay")),
    ("GirthL", ("cyl", (0.05, 0.35, 0.43, 14), (0, 0.55, 0), "trim")),
    ("GirthU", ("cyl", (0.05, 0.33, 0.35, 14), (0, 0.82, 0), "trim")),
    ("Door", ("box", (0.14, 0.22, 0.06), (0, 0.45, 0.46), "brick")),
    ("Vent", ("box", (0.08, 0.08, 0.05), (0.24, 0.68, 0.45), "trim")),
    ("RoofLid", ("cyl", (0.16, 0.40, 0.44, 14), (0, 0.95, 0), "clay")),
    ("RoofPeak", ("cyl", (0.12, 0.14, 0.14, 10), (0, 1.03, 0), "bronze")),
    ("Knob", ("cyl", (0.04, 0.05, 0.05, 8), (0, 1.11, 0), "gold_ink")),
]

# ---- 陶楼（东汉明器：三檐望楼/宝塔式陶楼）约 2.0 m 高 ----
TOWER = [
    ("Base", ("box", (1.30, 0.12, 1.30), (0, 0.06, 0), "clay")),
    ("Floor1", ("box", (1.00, 0.62, 1.00), (0, 0.40, 0), "clay")),
    ("Door1", ("box", (0.20, 0.34, 0.07), (0, 0.38, 0.51), "brick")),
    ("Eave1", ("box", (1.44, 0.08, 1.44), (0, 0.78, 0), "trim")),
    ("Floor2", ("box", (0.84, 0.52, 0.84), (0, 1.05, 0), "clay")),
    ("Window2", ("box", (0.16, 0.16, 0.06), (0.22, 1.08, 0.43), "brick")),
    ("Eave2", ("box", (1.24, 0.08, 1.24), (0, 1.38, 0), "trim")),
    ("Floor3", ("box", (0.68, 0.46, 0.68), (0, 1.60, 0), "clay")),
    ("Eave3", ("box", (1.04, 0.08, 1.04), (0, 1.92, 0), "trim")),
    ("Roof", ("box", (0.30, 0.22, 0.30), (0, 2.04, 0), "clay")),
    ("Finial", ("box", (0.08, 0.14, 0.08), (0, 2.22, 0), "bronze")),
    ("GiltBand1", ("box", (1.02, 0.045, 1.02), (0, 0.70, 0.01), "gold_ink")),
    ("GiltBand2", ("box", (0.86, 0.045, 0.86), (0, 1.28, 0.01), "gold_ink")),
]

# ---- 陶井（东汉明器：井栏 + 木架 + 小井亭）约 1.0 m ----
WELL = [
    ("Base", ("box", (1.06, 0.10, 1.06), (0, 0.05, 0), "clay")),
    ("RimL", ("cyl", (0.28, 0.46, 0.40, 14), (0, 0.26, 0), "clay")),
    ("RimTop", ("cyl", (0.05, 0.50, 0.50, 14), (0, 0.44, 0), "trim")),
    ("PostA", ("box", (0.07, 0.62, 0.07), (-0.30, 0.72, 0.30), "trim")),
    ("PostB", ("box", (0.07, 0.62, 0.07), (0.30, 0.72, 0.30), "trim")),
    ("PostC", ("box", (0.07, 0.62, 0.07), (-0.30, 0.72, -0.30), "trim")),
    ("PostD", ("box", (0.07, 0.62, 0.07), (0.30, 0.72, -0.30), "trim")),
    ("Roof", ("box", (0.98, 0.06, 0.98), (0, 1.08, 0), "trim")),
    ("RoofPeak", ("box", (0.36, 0.10, 0.36), (0, 1.16, 0), "clay")),
    ("Winch", ("box", (0.08, 0.06, 0.34), (0.42, 0.95, 0.0), "trim")),
]

# ---- 陶灶（东汉明器：灶台 + 灶眼 + 釜炊）约 0.5 m ----
STOVE = [
    ("Base", ("box", (0.94, 0.12, 0.66), (0, 0.06, 0), "clay")),
    ("Top", ("box", (0.78, 0.06, 0.50), (0, 0.16, 0), "clay")),
    ("Hearth", ("box", (0.62, 0.22, 0.34), (0, 0.28, 0.02), "clay")),
    ("HoleL", ("cyl", (0.06, 0.16, 0.16, 10), (-0.15, 0.34, 0.10), "wall")),
    ("HoleR", ("cyl", (0.06, 0.16, 0.16, 10), (0.15, 0.34, 0.10), "wall")),
    ("PotL", ("cyl", (0.20, 0.16, 0.16, 12), (-0.15, 0.50, 0.10), "bronze")),
    ("PotR", ("cyl", (0.20, 0.16, 0.16, 12), (0.15, 0.50, 0.10), "bronze")),
    ("Chimney", ("cyl", (0.30, 0.07, 0.09, 8), (0.42, 0.48, -0.12), "clay")),
    ("GiltFront", ("box", (0.66, 0.03, 0.04), (0, 0.22, -0.25), "gold_ink")),
]

# ---- 陶猪圈（东汉明器：圈栏 + 食槽 + 两头陶猪）约 1.3 x 1.0 m ----
PIGPEN = [
    ("Floor", ("box", (1.3, 0.06, 1.0), (0, 0.03, 0), "clay")),
    ("WallL", ("box", (0.08, 0.28, 1.06), (-0.61, 0.17, 0), "clay")),
    ("WallR", ("box", (0.08, 0.28, 1.06), (0.61, 0.17, 0), "clay")),
    ("WallB", ("box", (1.3, 0.28, 0.08), (0, 0.17, -0.46), "clay")),
    ("WallF", ("box", (1.0, 0.20, 0.08), (0, 0.13, 0.46), "clay")),
    ("Trough", ("box", (0.9, 0.06, 0.14), (0, 0.09, 0.36), "trim")),
    ("Pig1Body", ("capsule", (0.10, 0.14, 24, 8), (-0.15, 0.27, -0.12), "clay", 0.0, 90.0)),
    ("Pig1Head", ("sphere", (0.06, 24, 12), (-0.02, 0.30, 0.02), "clay")),
    ("Pig2Body", ("capsule", (0.09, 0.12, 24, 8), (0.25, 0.25, -0.20), "clay", 0.0, 90.0)),
    ("Pig2Head", ("sphere", (0.055, 24, 12), (0.37, 0.28, -0.08), "clay")),
]

# ---- 谷仓罐/魂瓶（东汉堆塑五联罐）约 0.6 m ----
HUNPING = [
    ("JarBody", ("cyl", (0.34, 0.22, 0.18, 12), (0, 0.28, 0), "clay")),
    ("Rim", ("cyl", (0.05, 0.17, 0.17, 12), (0, 0.48, 0), "clay")),
    ("Lid", ("cyl", (0.10, 0.20, 0.20, 12), (0, 0.55, 0), "clay")),
    ("LidTop", ("sphere", (0.055, 24, 12), (0, 0.63, 0), "bronze")),
    ("MiniN", ("cyl", (0.12, 0.09, 0.09, 8), (0, 0.50, -0.17), "clay")),
    ("MiniS", ("cyl", (0.12, 0.09, 0.09, 8), (0, 0.50, 0.17), "clay")),
    ("MiniE", ("cyl", (0.12, 0.09, 0.09, 8), (0.17, 0.50, 0), "clay")),
    ("MiniW", ("cyl", (0.12, 0.09, 0.09, 8), (-0.17, 0.50, 0), "clay")),
]

# ---- 漆耳杯（朱漆描金，汉代饮酒器，单件）约 0.3 m ----
ERBEI = [
    ("Cup", ("box", (0.24, 0.05, 0.15), (0, 0.025, 0), "vermilion")),
    ("Rim", ("box", (0.26, 0.012, 0.17), (0, 0.053, 0), "gold_ink")),
    ("EarL", ("box", (0.05, 0.03, 0.09), (-0.145, 0.04, 0), "trim")),
    ("EarR", ("box", (0.05, 0.03, 0.09), (0.145, 0.04, 0), "trim")),
]

# ---- 顶门石（防盗石杠：竖直石杠绕 X 倾斜 25°，底部贴地、顶部倒向墙）约 2.4 m ----
# 注意：pitch>0 时顶部倒向局部 +z；放置 yaw 需让局部 +z 指向墙面方向。
STOPPER = [
    ("Bar", ("box", (0.5, 2.4, 0.34), (0, 1.2, 0), "dark", 0.0, 25.0)),
    ("Chock", ("box", (0.7, 0.1, 0.7), (0, 0.05, 0), "trim")),
]


GROUPS = {
    "lion": ("StoneLions", LION),
    "pedestal_gold": ("SealPedestals", PEDESTAL_GOLD),
    "pedestal_blue": ("SealPedestals", PEDESTAL_BLUE),
    "sarcophagus": ("Sarcophagus", SARCOPHAGUS),
    "guard": ("HallGuards", GUARD),
    "lampstand": ("TombLampStands", LAMPSTAND),
    "vessel": ("BurialVessels", VESSEL),
    "ding": ("BronzeDings", DING),
    "niche": ("WallNiches", NICHE),
    "altar": ("OfferingAltar", ALTAR),
    "spearrack": ("SpearRacks", SPEARRACK),
    "boshan": ("BoshanBurners", BOSHAN),
    "figurine": ("ClayFigurines", FIGURINE),
    "granary": ("Granaries", GRANARY),
    "tower": ("Towers", TOWER),
    "well": ("Wells", WELL),
    "stove": ("Stoves", STOVE),
    "pigpen": ("Pigpens", PIGPEN),
    "hunping": ("Hunpings", HUNPING),
    "erbei": ("Erbeis", ERBEI),
    "stopper": ("DoorStops", STOPPER),
    "relief_procession": ("WallReliefs", relief_band(6.0, "procession")),
    "relief_cloud": ("WallReliefs", relief_band(6.0, "cloud")),
    "relief_guardian": ("WallReliefs", relief_band(6.0, "guardian")),
}

# ---- 门额（门洞上方补齐墙体）----
# 主墓道各门的门洞是全高度的洞：走廊顶 4.65、墓室/主厅顶 7.65，中间那段本来是空的，
# 从厅里看就是门上一个黑洞。补一块与墙同厚同材质的门额把它封上，并在洞口上沿加一条门楣。
DOOR_HEAD_TOP = 7.65
DOOR_HEAD_BOTTOM = 4.60


def door_header(w):
    h = DOOR_HEAD_TOP - DOOR_HEAD_BOTTOM
    return [
        ("Head", ("box", (w + 0.04, h, 0.38), (0, (DOOR_HEAD_BOTTOM + DOOR_HEAD_TOP) * 0.5, 0), "wall")),
        ("Lintel", ("box", (w + 0.40, 0.22, 0.10), (0, DOOR_HEAD_BOTTOM + 0.15, 0.20), "trim")),
        ("LintelRib", ("box", (w + 0.40, 0.05, 0.14), (0, DOOR_HEAD_BOTTOM + 0.02, 0.21), "bronze")),
    ]


# (kind, x, z, yaw, 门洞净宽)
DOOR_GAPS = [
    ("doorhead_halln", 15.00, -103.50, 0, 4.12),
    ("doorhead_halls", 0.00, -79.50, 180, 5.62),
    ("doorhead_halle", 37.50, -91.50, -90, 4.12),
    ("doorhead_tombw", 43.50, -91.50, 90, 4.12),
    ("doorhead_tombe", 70.50, -98.25, -90, 4.12),
    ("doorhead_tombe_gate", 70.50, -72.75, -90, 10.12),
]
for _kind, _x, _z, _yaw, _w in DOOR_GAPS:
    GROUPS[_kind] = ("DoorHeaders", door_header(_w))

# ---- 券顶（拱券肋骨，画在 11 主墓室天花下）----
# 拱：半跨 s=13.5（墓室宽 27 的中间段），矢高 rise=1.3，起拱线 y_spring=6.2，
# 圆心在 (z_mid, y_spring - d)，R = d + rise，s^2 = R^2 - d^2。
def vault_rib_parts(x_r, segment_centers, spring=6.2, rise=1.3, half_span=13.5,
                    rib_len=0.30, seg_w=4.0, seg_h=0.12, mat="wall", z_center=0.0):
    """Return parts of one arch rib at x=x_r (world X). segment_centers: z offsets."""
    s = half_span
    d = (s * s - rise * rise) / (2.0 * rise)
    R = d + rise
    parts = []
    for k, zk in enumerate(segment_centers):
        yk = spring + (math.sqrt(R * R - zk * zk) - d)  # arc height at zk
        pitch = math.degrees(math.atan(zk / math.sqrt(R * R - zk * zk)))
        parts.append(("Rib%d_%d" % (int(round(x_r)), k),
                      ("box", (rib_len, seg_h, seg_w), (x_r, yk, z_center + zk), mat,
                       0.0, pitch)))
    return parts


VAULT_Z = [-11.57, -7.71, -3.86, 0.0, 3.86, 7.71, 11.57]
# 五条肋骨（x=45/51/57/63/69）+ 四条肋间抹板（x=48/54/60/66），连成连续拱面
# 拱心 z => 墓室中心 z=-91.5（z_center 平移全部肋段），x 已是世界绝对 X
VAULT_RIBS = []
for xr in (45.0, 51.0, 57.0, 63.0, 69.0):
    VAULT_RIBS += vault_rib_parts(xr, VAULT_Z, seg_w=4.0, z_center=-91.5, mat="brick")
for xm in (48.0, 54.0, 60.0, 66.0):
    VAULT_RIBS += vault_rib_parts(xm, VAULT_Z, rib_len=5.7, seg_h=0.08, seg_w=3.9,
                                  mat="brick", z_center=-91.5)

# 券顶组（肋段坐标已是世界绝对 X/Z，故组原点放在 (0,0,0)）
GROUPS["vault"] = ("VaultRibs", VAULT_RIBS)
# 五铢钱：平放铜钱（薄圆柱，轴沿 Y，无需旋转）
GROUPS["coin"] = ("CoinScatter", [("CoinDisc", ("cyl", (0.025, 0.11, 0.11, 12), (0, 0.0, 0), "bronze"))])

COIN_SCATTER = [
    (51.9, -89.4, 40), (52.6, -90.6, -25), (53.3, -92.2, 15), (52.1, -93.5, -60),
    (50.8, -90.2, 85), (53.9, -91.0, -15), (52.5, -88.9, 200), (53.1, -93.9, 130),
    (51.5, -92.4, -110), (53.6, -88.6, 320),
    (46.6, -95.6, 20), (46.0, -96.8, -40), (46.9, -98.0, 180), (45.8, -94.7, 90),
]

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
    ("VaseHallN1", "vessel", (8.0, 0.15, -102.0), 0),
    ("VaseHallN2", "vessel", (17.5, 0.15, -102.0), 0),
    ("VaseHallN3", "vessel", (26.5, 0.15, -102.0), 0),
    ("VaseHallN4", "vessel", (34.5, 0.15, -102.0), 0),
    ("VaseHallS1", "vessel", (3.2, 0.15, -80.9), 180),
    ("VaseHallS2", "vessel", (8.0, 0.15, -80.9), 180),
    ("VaseHallS3", "vessel", (17.5, 0.15, -80.9), 180),
    ("VaseHallS4", "vessel", (26.5, 0.15, -80.9), 180),
    ("VaseHallS5", "vessel", (34.5, 0.15, -80.9), 180),
    ("VaseTmbNW", "vessel", (46.0, 0.15, -103.2), 0),
    ("VaseTmbNE", "vessel", (68.0, 0.15, -103.2), 0),
    ("VaseTmbSW", "vessel", (46.0, 0.15, -79.8), 0),
    ("VaseTmbSE", "vessel", (68.0, 0.15, -79.8), 0),
    ("DingHall1", "ding", (3.5, 0.15, -96.8), 180),
    ("DingHall2", "ding", (26.5, 0.15, -96.8), 0),
    ("DingTmb1", "ding", (66.5, 0.15, -84.0), 0),
    ("DingTmb2", "ding", (47.5, 0.15, -98.0), 90),
    ("NicheHallN1", "niche", (-2.0, 0.15, -103.5), 0),
    ("NicheHallN2", "niche", (6.0, 0.15, -103.5), 0),
    ("NicheHallN3", "niche", (21.5, 0.15, -103.5), 0),
    ("NicheHallN4", "niche", (30.0, 0.15, -103.5), 0),
    ("NicheHallS1", "niche", (6.5, 0.15, -79.5), 180),
    ("NicheHallS2", "niche", (15.5, 0.15, -79.5), 180),
    ("NicheHallS3", "niche", (24.5, 0.15, -79.5), 180),
    ("NicheHallS4", "niche", (33.5, 0.15, -79.5), 180),
    ("NicheTmbE", "niche", (70.5, 0.15, -91.0), -90),
    ("NicheTmbW", "niche", (43.5, 0.15, -86.5), 90),
    ("Altar11", "altar", (52.8, 0.15, -91.5), 90),
    ("RackHall1", "spearrack", (9.5, 0.15, -80.6), 0),
    ("RackHall2", "spearrack", (18.5, 0.15, -80.6), 0),
    # 博山炉 & 陶俑 & 五铢钱（柱基顶 y=0.605）
    ("BoshanHall", "boshan", (1.5, 0.605, -98.25), 45),
    ("BoshanTmb", "boshan", (54.5, 0.15, -95.8), -30),
    ("FigurineHallA", "figurine", (10.5, 0.605, -98.25), 90),
    ("FigurineHallB", "figurine", (28.5, 0.605, -84.75), -90),
    ("FigurineTmbA", "figurine", (49.0, 0.15, -80.0), 0),
    ("FigurineTmbB", "figurine", (65.0, 0.15, -80.0), 180),
    ("FigurineTmbC", "figurine", (65.0, 0.15, -101.0), 0),
]

# 画像石浮雕带：浅浮雕嵌墙（石板凸 2cm + 纹样 3.5cm），原点落在墙面。
# 墙面内面：大厅 z=-103.5(北)/-79.5(南)、x=37.5(东)/-7.5(西)；
#          墓室 z=-105.0(北)/-78.0(南)、x=70.5(东)/43.5(西)
# 硬约束：6m 整段必须落在一段连续墙面上、两端各留 ≥0.3m，绝不跨门洞。
# 上一版 #4/#20 跨门洞悬空 2.8m/2.3m，就是"墙里戳出一块黑板"的根源。
RELIEF_SPOTS = [
    # 大厅北墙：门洞(-12.94..-17.06 之外)两段各三块
    (-3.81, -103.5, 0), (2.62, -103.5, 0), (9.06, -103.5, 0),
    (20.94, -103.5, 0), (27.38, -103.5, 0), (33.81, -103.5, 0),
    # 大厅南墙：门洞右侧 34.9m 连续段，五块均布
    (6.92, -79.5, 180), (13.59, -79.5, 180), (20.25, -79.5, 180),
    (26.91, -79.5, 180), (33.58, -79.5, 180),
    # 大厅东墙 / 西墙
    (37.5, -98.62, -90), (37.5, -84.37, -90),
    (-7.5, -99.10, 90), (-7.5, -91.50, 90), (-7.5, -83.90, 90),
    # 墓室北墙 / 南墙
    (47.26, -105.0, 0), (53.75, -105.0, 0), (60.25, -105.0, 0), (66.74, -105.0, 0),
    (47.26, -78.0, 180), (53.75, -78.0, 180), (60.25, -78.0, 180), (66.74, -78.0, 180),
    # 墓室西墙 / 东墙（避开 08 通道缺口：西 -93.56..-89.44、东 -100.31..-96.19）
    (43.5, -99.37, 90), (43.5, -83.62, 90),
    (70.5, -90.91, -90), (70.5, -83.09, -90),
]

# 墙段运行区间（y 2.6–3.6 实测，见 tools/audit_wall_decor.py），生成时强制校验
WALL_RUNS = {
    ("z", -103.5): [(-7.69, 12.94), (17.06, 37.69)],
    ("z", -79.5): [(-56.44, -21.38), (-7.69, -2.81), (2.81, 37.69)],
    ("x", 37.5): [(-103.69, -93.56), (-89.44, -79.31)],
    ("x", -7.5): [(-103.69, -79.31)],
    ("z", -105.0): [(43.31, 70.69)],
    ("z", -78.0): [(43.31, 70.69)],
    ("x", 70.5): [(-105.19, -100.31), (-96.19, -77.81), (-67.69, -52.31)],
    ("x", 43.5): [(-105.19, -93.56), (-89.44, -77.81)],
}
BAND_MARGIN = 0.3


def check_band_fit(x, z, yaw, w=6.0):
    axis = "x" if abs(yaw) == 90 else "z"
    plane = x if axis == "x" else z
    span = (z - w / 2, z + w / 2) if axis == "x" else (x - w / 2, x + w / 2)
    for lo, hi in WALL_RUNS.get((axis, plane), []):
        if span[0] >= lo + BAND_MARGIN and span[1] <= hi - BAND_MARGIN:
            return True
    return False


for i, (x, z, yaw) in enumerate(RELIEF_SPOTS):
    if not check_band_fit(x, z, yaw):
        raise SystemExit("relief band crosses an opening: #%d (%.2f, %.2f, yaw %d) span %.2f..%.2f"
                         % (i, x, z, yaw, (z if abs(yaw) == 90 else x) - 3.0,
                            (z if abs(yaw) == 90 else x) + 3.0))
    kind = ("relief_cloud", "relief_guardian", "relief_procession")[i % 3]
    PLACEMENTS.append(("ReliefBand%02d" % i, kind, (x, 0.0, z), yaw, 1.0))

# 门额：把各门洞上方的空档补成墙（见 DOOR_GAPS）
for _kind, _x, _z, _yaw, _w in DOOR_GAPS:
    PLACEMENTS.append(("%sHead" % _kind.split("_")[-1].upper(), _kind, (_x, 0.0, _z), _yaw))

# 五铢钱：散落在地面（薄圆柱轴沿 Y，y=0.163 使底面贴地 0.15）
for i, (cx, cz, ry) in enumerate(COIN_SCATTER):
    PLACEMENTS.append(("Coin%02d" % i, "coin", (cx, 0.163, cz), ry, 1.0))

# 券顶：一组即可（组原点 (0,0,0)，所有肋段已是世界坐标）
PLACEMENTS.append(("VaultTomb", "vault", (0.0, 0.0, 0.0), 0))

# ---- 明器：陶仓/陶楼/陶井/陶灶（04/08 空房间与 06/09 空角落）----
# 04 房间 (-60..-48, -52.5..-37.5)：陶仓×2 + 陶井×1 + 陶灶×1
for i, (x, z, yaw) in enumerate([(-56.5, -41.0, 0), (-51.5, -45.5, 25)]):
    PLACEMENTS.append(("Granary04%d" % i, "granary", (x, 0.15, z), yaw, 1.0))
PLACEMENTS.append(("Well04", "well", (-53.0, 0.15, -39.5), 90))
PLACEMENTS.append(("Stove04", "stove", (-57.5, 0.15, -50.0), 90))
# 08 房间 (54..66, -40.5..-19.5)：陶楼×2
for i, (x, z, yaw) in enumerate([(58.0, -25.5, 20), (62.5, -35.0, -15)]):
    PLACEMENTS.append(("Tower08%d" % i, "tower", (x, 0.15, z), yaw, 1.0))
# 06 封印室西侧空角 / 09 封印室北侧空角：陶灶各一
PLACEMENTS.append(("Stove06", "stove", (-51.5, 0.15, -85.0), 45))
PLACEMENTS.append(("Stove09", "stove", (52.5, 0.15, -54.0), 90))

# ---- 第二轮明器：陶猪圈 / 谷仓罐魂瓶 / 漆耳杯 / 顶门石 ----
# 猪圈：06 西北空角 + 09 西南空角
PLACEMENTS.append(("Pigpen06", "pigpen", (-49.0, 0.15, -94.0), 30))
PLACEMENTS.append(("Pigpen09", "pigpen", (51.5, 0.15, -63.0), -20))
# 魂瓶：04 东侧空地 + 09 东北角
PLACEMENTS.append(("Hunping04", "hunping", (-49.0, 0.15, -38.5), 15))
PLACEMENTS.append(("Hunping09", "hunping", (67.5, 0.15, -55.5), -30))
# 漆耳杯：祭案台面（Altar11 顶面 0.72）两杯 + 封印台前地面两杯（y=0.175 贴地 0.15）
PLACEMENTS.append(("ErbeiAltarA", "erbei", (51.1, 0.745, -91.5), 90))
PLACEMENTS.append(("ErbeiAltarB", "erbei", (54.5, 0.745, -91.5), 90))
PLACEMENTS.append(("Erbei06", "erbei", (-35.6, 0.175, -87.8), 10))
PLACEMENTS.append(("Erbei09", "erbei", (59.8, 0.175, -62.2), -20))
# 顶门石（石杠斜靠墙）：局部 +z 指向墙面方向。
# 11 北墙内面 z=-105.0 → 墙在 -z，yaw=180；09 南墙内面 z=-52.5 → 墙在 +z，yaw=0；
# 11 西墙内面 x=43.5 → 墙在 -x，yaw=-90。
PLACEMENTS.append(("StopperTombN", "stopper", (52.0, 0.15, -104.4), 180))
PLACEMENTS.append(("Stopper09S", "stopper", (60.0, 0.15, -53.4), 0))
PLACEMENTS.append(("Stopper11W", "stopper", (44.3, 0.15, -87.5), -90))

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
    kind = shape[0]
    p = shape[1]
    if kind == "box":
        sub_lines.append('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%g, %g, %g)\n'
                         % (sid, p[0], p[1], p[2]))
    elif kind == "sphere":
        # sphere: (radius, radial_segments, rings)
        sub_lines.append('[sub_resource type="SphereMesh" id="%s"]\n'
                         'radius = %g\nheight = %g\nradial_segments = %d\nrings = %d\n'
                         % (sid, p[0], p[0] * 2.0, max(p[1], 24), max(p[2], 12)))
    elif kind == "capsule":
        # capsule: (radius, height_of_cylinder_body, radial_segments, rings)
        sub_lines.append('[sub_resource type="CapsuleMesh" id="%s"]\n'
                         'radius = %g\nheight = %g\nradial_segments = %d\nrings = %d\n'
                         % (sid, p[0], p[1] + 2.0 * p[0], max(p[2], 24), max(p[3], 8)))
    else:
        h, tr, br, seg = shape[1]
        sub_lines.append('[sub_resource type="CylinderMesh" id="%s"]\n'
                         'top_radius = %g\nbottom_radius = %g\nheight = %g\nradial_segments = %d\n'
                         % (sid, tr, br, h, max(seg, 24)))
    return sid


def xform(pos, yaw_deg, scale=1.0):
    c = math.cos(math.radians(yaw_deg)) * scale
    s = math.sin(math.radians(yaw_deg)) * scale
    return "Transform3D(%g, 0, %g, 0, %g, 0, %g, 0, %g, %g, %g, %g)" % (
        c, -s, scale, s, c, pos[0], pos[1], pos[2])


def part_tform(pos, yaw_deg, pitch_deg):
    """Transform for a part with optional yaw (around Y) and pitch (around X).

    Composition: R = Ry(yaw) * Rx(pitch). With column-vector convention and
    Godot's Transform3D(xx,xy,xz, yx,yy,yz, zx,zy,zz, ox,oy,oz) where the
    first three numbers are basis.x, etc. We compute basis columns as
    Ry * (Rx column), matching the convention used in xform() above.
    """
    cy = math.cos(math.radians(yaw_deg))
    sy = math.sin(math.radians(yaw_deg))
    cp = math.cos(math.radians(pitch_deg))
    sp = math.sin(math.radians(pitch_deg))
    # Rx columns: x=(1,0,0), y=(0,cp,sp), z=(0,-sp,cp)
    # Ry(v): (cy*vx + sy*vz, vy, -sy*vx + cy*vz)
    cols = []
    for v in ((1.0, 0.0, 0.0), (0.0, cp, sp), (0.0, -sp, cp)):
        cols.append((cy * v[0] + sy * v[2], v[1], -sy * v[0] + cy * v[2]))
    flat = [f for col in cols for f in col]
    return "Transform3D(%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g)" % (
        flat[0], flat[1], flat[2], flat[3], flat[4], flat[5],
        flat[6], flat[7], flat[8], pos[0], pos[1], pos[2])


glb_sub = set()


def glb_ref_id(gpath):
    glb_sub.add(gpath)
    return "glb%d" % (hash(gpath) % 100000)


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
            pkind = spec[0]
            if pkind == "glb":
                # Packed-scene instance (rounded Blender model). GLB is grounded
                # at local y=0, so keep the part at its placement's local origin.
                glb_path = spec[1]
                ppos = spec[2]
                body.append('\n[node name="%s" parent="%s/%s" instance=ExtResource("p_%s")]'
                            % (pname, unique_gname, name, glb_ref_id(glb_path)))
                body.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)"
                            % (ppos[0], ppos[1], ppos[2]))
                continue
            shape = (pkind, spec[1])
            ppos = spec[2]
            mat = spec[3]
            pyaw = spec[4] if len(spec) > 4 else 0.0
            ppitch = spec[5] if len(spec) > 5 else 0.0
            sid = mesh_sub(shape)
            body.append('\n[node name="%s" type="MeshInstance3D" parent="%s/%s"]'
                        % (pname, unique_gname, name))
            if pyaw or ppitch:
                body.append("transform = %s" % part_tform(ppos, pyaw, ppitch))
            else:
                body.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)"
                            % (ppos[0], ppos[1], ppos[2]))
            body.append('mesh = SubResource("%s")' % sid)
            body.append('material_override = ExtResource("m_%s")' % mat)


ext_lines = []
for key, path in MAT.items():
    ext_lines.append('[ext_resource type="Material" path="%s" id="m_%s"]' % (path, key))
for gpath in sorted(glb_sub):
    ext_lines.append('[ext_resource type="PackedScene" path="%s" id="p_%s"]' % (gpath, glb_ref_id(gpath)))

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
