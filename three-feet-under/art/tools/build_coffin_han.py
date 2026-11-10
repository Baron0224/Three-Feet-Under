"""Build a late-Eastern-Han-style lacquered coffin (东汉末年髹漆木棺).

Robust primitive build (axis-aligned + vertex-loop scale), no hand-authored faces:
 * Stone plinth box.
 * Trapezoid lacquer body: a solid block, foot-end vertex loop scaled narrower
   and slightly shorter  => 头大尾小 (head wider & taller than foot).
 * Arched barrel lid: half-cylinder along X, resting on the body top opening.
 * Black lacquer body + vermilion (朱砂) inlay band + stone plinth.

Blender 4+ is Z-UP. Coffin length X, width Y, height Z.
Final dims approx: length 4.5, width 1.6..1.85, height ~1.35.
"""
import bpy
import os
import sys
import math
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.engine = "BLENDER_EEVEE"

# Deltas for the two rect ends of the coffin (meters). +X end = head (wide), -X = foot.
LEN     = 4.40    # along X
HEAD_W  = 1.82    # width at head end
FOOT_W  = 1.56    # width at foot end
HEAD_H  = 0.92    # body height at head end
FOOT_H  = 0.78    # body height at foot end
PLINT_H = 0.20
PLINT_WALL = 0.10   # plinth overhang beyond the body widest point

LID_RISE   = 0.42    # arch height (half-cylinder radius drives this)
LID_OVER   = 0.06    # lid overhang beyond body width

def add_material(name, color, roughness=0.5, metallic=0.0, clearcoat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Clearcoat" in bsdf.inputs:
            bsdf.inputs["Clearcoat"].default_value = clearcoat
    return mat

BLACK = ("Lacquer_Black", (0.030, 0.024, 0.024, 1.0), 0.30, 0.0, 0.8)
RED   = ("Lacquer_Red", (0.72, 0.16, 0.10, 1.0), 0.45, 0.0, 0.6)
STONE = ("Stone_Plinth", (0.24, 0.20, 0.16, 1.0), 0.85)

def mat_assign(obj, mats):
    for m in mats:
        obj.data.materials.append(add_material(m[0], m[1], m[2]))

def apply_t(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def bevel(obj, width, segments=4):
    for o in bpy.data.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_add(type="BEVEL")
    mod = bpy.context.object.modifiers[-1]
    mod.width = width
    mod.segments = segments
    mod.limit_method = "NONE"
    bpy.ops.object.modifier_apply(modifier=mod.name)

def smooth_normals(obj):
    for p in obj.data.polygons:
        p.use_smooth = True

# ---------------------------------------------------------------------------
# 1. Stone plinth
# ---------------------------------------------------------------------------
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, PLINT_H / 2.0))
plinth = bpy.context.active_object
plinth.name = "Coffin_Plinth"
plinth.scale = (LEN + 2 * PLINT_WALL, HEAD_W + 2 * PLINT_WALL, PLINT_H)
apply_t(plinth)
mat_assign(plinth, [STONE])
bevel(plinth, 0.04)

# ---------------------------------------------------------------------------
# 2. Trapezoid lacquer body (头大尾小)
#    Solid block from a cube; scale the foot-end (-X) vertex loop to narrow
#    width & height. Head remains full-size. Parked so head center sits at +X.
# ---------------------------------------------------------------------------
body_obj = None
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, PLINT_H + HEAD_H / 2.0))
body = bpy.context.active_object
body.name = "Coffin_Body"
body.scale = (LEN, HEAD_W, HEAD_H)
apply_t(body)

# enter edit mode, select the foot-side (-X) half vertices, scale them along
# Y(width) and Z(height) to turn the box into a taper.
split_x = -LEN * 0.28   # verts with x < this belong to foot side
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")

me = body.data
import bmesh as _bmesh
_bm = _bmesh.new()
_bm.from_mesh(me)
for v in _bm.verts:
    if v.co.x < split_x:
        v.select = True
_bm.select_flush(True)
_bm.to_mesh(me)
_bm.free()

# scale selected (foot half) about foot-end bottom corner to narrow + lower
bpy.ops.object.mode_set(mode="EDIT")
# pivot at the foot-end bottom-front corner (x=-LEN/2)
pivot = Vector((-LEN / 2.0, 0.0, 0.0))
# move pivot selection to that corner
bpy.ops.view3d.snap_cursor_to_selected if False else None
# Use transform with median point pivot is hard; instead scale in OBJECT via
# vertex manipulation. Simplest robust: directly scale selected verts with bmesh.
bpy.ops.object.mode_set(mode="OBJECT")
_bm = _bmesh.new()
_bm.from_mesh(me)
sx = Vector((1, FOOT_W / HEAD_W, FOOT_H / HEAD_H))
foot_center = Vector((-LEN / 2.0, 0.0, PLINT_H))
for v in _bm.verts:
    if v.select:
        d = Vector((0, v.co.y, v.co.z - PLINT_H))
        v.co.y = foot_center.y + d.y * (FOOT_W / HEAD_W)
        v.co.z = foot_center.z + d.z * (FOOT_H / HEAD_H)
_bm.to_mesh(me)
_bm.free()
bpy.ops.object.mode_set(mode="OBJECT")

mat_assign(body, [BLACK])
bevel(body, 0.10, 5)

# ---------------------------------------------------------------------------
# 3. Vermilion inlay band (朱砂) near the body top -- two thin boxes wrapping
#    the top rim: front(+Y) and back(-Y) + end caps, inset.
# ---------------------------------------------------------------------------
band_y = 0.02
band_h = 0.05
band_gap_from_top = 0.10
def add_band_box(cx, cy, cz, sx, sy, sz):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz))
    b = bpy.context.active_object
    b.name = "Coffin_Band"
    b.scale = (sx, sy, sz)
    apply_t(b)
    mat_assign(b, [RED])
    return b

# front +Y band
band_y = HEAD_W * 0.5
add_band_box(0.15, band_y - 0.006, PLINT_H + (HEAD_H+FOOT_H)/2 + 0.02,
             LEN*0.92, 0.012, 0.045)
# back -Y band
add_band_box(0.15, -band_y + 0.006, PLINT_H + (HEAD_H+FOOT_H)/2 + 0.02,
             LEN*0.92, 0.012, 0.045)

# ---------------------------------------------------------------------------
# 4. Arched barrel lid  -- half-cylinder along X, flat bottom sits on the body
# ---------------------------------------------------------------------------
lid_w = HEAD_W + LID_OVER          # full width across Y
lid_r = (HEAD_H + 0.0) / 2.0 + LID_RISE  # synthetic arch height
# We want a barrel whose cross-section is a half ellipse: width 2a=lid_w,
# height rise = LID_RISE + small. A half-cylinder with radius lid_w/2 gives a
# semicircle too tall; use scale to flatten to a low barrel arch.
bpy.ops.mesh.primitive_cylinder_add(vertices=48, depth=1.0, location=(0, 0, 0))
lid = bpy.context.active_object
lid.name = "Coffin_Lid"
# cylinder long axis is Z by default; rotate to make long axis X
lid.rotation_euler = (0, math.pi / 2, 0)  # pivot so length goes along X
apply_t(lid)
# Now cylinder axis along X, circle in YZ. scale to ellipse the YZ circle.
# unit cylinder depth -0.5..0.5 along X, radius 1 in YZ
lid.scale = (LEN - 0.04, lid_w / 2.0, LID_RISE)
apply_t(lid)
# We now have a full (not half) ellipsoid cylinder. Keep upper half (z>0) => barrel
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.bisect(plane_co=(0, 0, 0), plane_no=(0, 0, 1),
                    clear_inner=True, clear_outer=False)
bpy.ops.object.mode_set(mode="OBJECT")
smooth_normals(lid)
mat_assign(lid, [BLACK])

# position lid on top of body: lowest z of lid = lid center - LID_RISE
# we placed lid at origin then bisected z>0; lowest point is 0. Move up so the
# barrel bottom sits on the body top rim (head/foot average).
body_top_av = PLINT_H + (HEAD_H + FOOT_H) / 2.0
lid.location.z = body_top_av - LID_RISE * 0.0
# After bisect, lid occupies z in [-? ]. The full cyl scaled to LID_RISE spans
# z in [-LID_RISE, LID_RISE]; keep upper half => [0, LID_RISE]. Set location so
# its bottom (z=0) sits at approximately body top (head end uses +extra).
# Head end is higher, so tilt lid slightly so the head side arcs higher:
# rotate ~ small positive about Y so +X (head) rises.
lid.location.z = body_top_av - 0.02
apply_t(lid)
# make head end higher than foot by tilting about Y
lid.rotation_euler = (0, -0.02, 0)  # low head? test sign in render

# ---------------------------------------------------------------------------
# Join all meshes into one object; origin at plinth base (z=0)
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
joint = bpy.context.active_object
joint.name = "Coffin_Han"
# snap origin to geometry (bottom, center)
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
print("JOINED_DIMS", joint.dimensions, "ORIGIN", joint.location)

# ---------------------------------------------------------------------------
# Camera + lights + preview
# ---------------------------------------------------------------------------
def add_light(loc, energy, color=(1, 1, 1, 1)):
    bpy.ops.object.light_add(type="POINT", location=loc)
    l = bpy.context.active_object
    l.data.energy = energy
    l.data.color = color[:3]
    return l

add_light((7, 4, 5), 1000)
add_light((-6, -4, 3), 600)
add_light((0, 6, 2), 600)

bpy.ops.object.camera_add(location=(9.5, -6.5, 3.4))
cam = bpy.context.active_object
dx, dy, dz = -9.5, 6.5, -3.4
cam.rotation_euler = (
    math.asin(dz / math.sqrt(dx * dx + dy * dy + dz * dz)),
    0,
    math.atan2(dy, dx) + math.pi,
)
bpy.context.scene.camera = cam

# ---------------------------------------------------------------------------
# Export GLB
# ---------------------------------------------------------------------------
for o in bpy.data.objects:
    if o.type == "MESH":
        apply_t(o)
out_dir = os.path.dirname(os.path.abspath(__file__))
models_dir = os.path.join(os.path.dirname(out_dir), "models")
os.makedirs(models_dir, exist_ok=True)
glb_path = os.path.join(models_dir, "coffin_heavy.glb")
bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB",
                          export_apply=True, export_yup=True)
print("GLB_EXPORTED:", glb_path)

if "--norender" not in sys.argv:
    bpy.context.scene.render.resolution_x = 960
    bpy.context.scene.render.resolution_y = 600
    bpy.context.scene.render.filepath = os.path.join(models_dir, "coffin_heavy_preview.png")
    bpy.ops.render.render(write_still=True)
    print("PNG_RENDERED:", bpy.context.scene.render.filepath)

print("OBJECTS:", [o.name for o in bpy.data.objects if o.type == "MESH"])