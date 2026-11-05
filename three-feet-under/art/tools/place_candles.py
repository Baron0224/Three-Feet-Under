"""Offline tool: place unlit candle clusters against room walls from the box
dump produced by dump_scene_boxes.py, then write %TEMP%\tfu_candles.json.
Run: python place_candles.py   (no scene writes)
"""
import json, math, random

BOX = json.load(open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_scene_boxes.json", encoding="utf-8"))
walls = BOX["walls"]
others = BOX["others"]

def box_xz(b):
    x, y, z = b["pos"]; sx, sy, sz = b["size"]
    return (x - sx/2, x + sx/2, z - sz/2, z + sz/2)

def dist_xz(x, z, b):
    x0, x1, z0, z1 = box_xz(b)
    dx = max(x0 - x, 0.0, x - x1); dz = max(z0 - z, 0.0, z - z1)
    return math.hypot(dx, dz)

def wall_gap(x, z, nx, nz, max_d=0.9):
    best = None
    for b in walls:
        x0, x1, z0, z1 = box_xz(b)
        if not (x0 - max_d <= x <= x1 + max_d and z0 - max_d <= z <= z1 + max_d):
            continue
        step = 0.04
        while step <= max_d:
            px, pz = x + nx * step, z + nz * step
            if x0 <= px <= x1 and z0 <= pz <= z1:
                if best is None or step < best:
                    best = step
                break
            step += 0.04
    return best

def perimeter_samples(x0, x1, z0, z1, inset, n):
    w, h = (x1 - x0) - 2 * inset, (z1 - z0) - 2 * inset
    if w <= 0.4 or h <= 0.4:
        return []
    edges = [
        ((x0 + inset, z0 + inset), (0, -1), w),
        ((x1 - inset, z0 + inset), (1, 0), h),
        ((x1 - inset, z1 - inset), (0, 1), w),
        ((x0 + inset, z1 - inset), (-1, 0), h),
    ]
    per = 2 * (w + h)
    out = []
    for k in range(n):
        t = (k + 0.5) / n * per
        for (start, normal, length) in edges:
            if t <= length:
                if normal[1] == -1:
                    p = (start[0] + t, start[1])
                elif normal[0] == 1:
                    p = (start[0], start[1] + t)
                elif normal[1] == 1:
                    p = (start[0] - t, start[1])
                else:
                    p = (start[0], start[1] - t)
                out.append((p[0], p[1], normal[0], normal[1]))
                break
            t -= length
    return out

ROOMS = [
    ("01_entrance",   -2.25, 2.25,  -3.75,  8.25, 0.15, 10, 0.55),
    ("02_hub",       -12.0, 12.0,  -42.0, -18.0, 0.15, 26, 0.55),
    ("03_corridor",  -51.75, 14.0, -32.25, -27.75, 0.15, 22, 0.55),
    ("04_pressure",  -60.0, -48.0, -52.5, -37.5, 0.15, 16, 0.55),
    ("05_corridor_a", -54.0, -49.5, -59.25, -52.5, 0.15, 6, 0.5),
    ("05_corridor_b", -56.25, -26.25, -63.75, -59.25, 0.15, 14, 0.5),
    ("05_corridor_c", -26.25, -21.75, -74.25, -59.25, 0.15, 9, 0.5),
    ("05_corridor_d", -56.25, -21.75, -78.75, -74.25, 0.15, 11, 0.5),
    ("06_west_seal", -54.0, -33.0, -97.5, -82.5, 0.15, 22, 0.55),
    ("07_west_bank",  15.0, 21.0, -32.25, -27.75, 0.15, 6, 0.5),
    ("07_east_bank",  45.0, 51.0, -32.25, -27.75, 0.15, 6, 0.5),
    ("08_rotating",   54.0, 66.0, -40.5, -19.5, 0.15, 16, 0.55),
    ("09_east_seal",  49.5, 70.5, -67.5, -52.5, 0.15, 22, 0.55),
    ("10_hall",       -7.5, 37.5, -103.5, -79.5, 0.15, 38, 0.6),
    ("11_tomb",       43.5, 70.5, -105.0, -78.0, 0.15, 30, 0.65),
    ("12_exit_land",  78.0, 82.5, -109.5, -96.0, 0.15, 9, 0.5),
    ("12_exit_turn",  70.5, 78.0, -100.5, -96.0, 0.15, 6, 0.5),
    ("approach10",    -3.0,  3.0, -79.5, -45.0, 0.15, 16, 0.5),
]

rng = random.Random(20261106)
candles = []
report = []
for (name, x0, x1, z0, z1, top, target, inset) in ROOMS:
    per = 2 * ((x1 - x0 - 2 * inset) + (z1 - z0 - 2 * inset))
    n = max(10, int(per / 1.8) + 4)
    samples = perimeter_samples(x0, x1, z0, z1, inset, n)
    ci = max(inset, 0.6)
    corners = []
    for ((cx, cz), ns) in [((x0+ci, z0+ci), [(-1,0),(0,-1)]), ((x1-ci, z0+ci), [(1,0),(0,-1)]),
                         ((x1-ci, z1-ci), [(1,0),(0,1)]), ((x0+ci, z1-ci), [(-1,0),(0,1)])]:
        gs = [wall_gap(cx, cz, nx, nz, 0.7) for (nx, nz) in ns]
        if all(g is not None for g in gs):
            corners.append((cx, cz, ns[0][0], ns[0][1]))
    allc = samples + corners
    rng.shuffle(allc)
    placed = 0
    for (px, pz, nx, nz) in allc:
        if placed >= target:
            break
        gap = wall_gap(px, pz, nx, nz, 0.8)
        if gap is None or gap < 0.18:
            continue
        px2, pz2 = px + nx * max(0.0, gap - 0.36), pz + nz * max(0.0, gap - 0.36)
        if any(dist_xz(px2, pz2, b) < 0.24 for b in walls):
            continue
        if any(dist_xz(px2, pz2, b) < 0.55 for b in others):
            continue
        count = rng.choices([2, 3, 4], weights=[0.4, 0.4, 0.2])[0]
        ring0 = rng.uniform(0, math.tau)
        for i in range(count):
            if placed >= target:
                break
            ang = ring0 + i * math.tau / count + rng.uniform(-0.25, 0.25)
            rad = rng.uniform(0.11, 0.17)
            cx, cz = px2 + math.cos(ang) * rad, pz2 + math.sin(ang) * rad
            if any(dist_xz(cx, cz, b) < 0.26 for b in others):
                continue
            if any(dist_xz(cx, cz, b) < 0.20 for b in walls):
                continue
            if any((c["x"]-cx)**2 + (c["z"]-cz)**2 < 0.0144 for c in candles):
                continue
            u = rng.random()
            h = 0.20 + 0.35 * (u * u)
            r = rng.uniform(0.040, 0.058)
            yaw = rng.uniform(0, math.tau)
            tilt = math.radians(rng.uniform(0, 5.0))
            tdir = rng.uniform(0, math.tau)
            dish = rng.random() < 0.3
            base = top + (0.018 if dish else 0.0)
            candles.append(dict(x=cx, z=cz, y=base, h=h, r=r, yaw=yaw, tilt=tilt,
                                tdir=tdir, dish=dish, pool_r=r * 1.12))
            placed += 1
    report.append((name, target, placed))

print("total candles:", len(candles))
for row in report:
    print("%-14s target=%2d placed=%2d" % row)

def matmul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]

def apply(M, v):
    return [M[i][0]*v[0] + M[i][1]*v[1] + M[i][2]*v[2] for i in range(3)]

def inst(R, sx, sy, sz, cx, cy, cz):
    c0 = apply(R, [sx, 0, 0]); c1 = apply(R, [0, sy, 0]); c2 = apply(R, [0, 0, sz])
    return [c0[0], c0[1], c0[2], cx, c1[0], c1[1], c1[2], cy, c2[0], c2[1], c2[2], cz]

bodies, pools, wicks, dishes = [], [], [], []
for c in candles:
    R = matmul(matmul(rot_y(c["yaw"]), rot_y(c["tdir"])), rot_x(c["tilt"]))
    bx, by, bz = c["x"], c["y"], c["z"]
    off = apply(R, [0, c["h"]/2, 0])
    bodies.append(inst(R, c["r"], c["h"], c["r"], bx+off[0], by+off[1], bz+off[2]))
    off = apply(R, [0, c["h"]+0.002, 0])
    pools.append(inst(R, c["pool_r"], 0.014, c["pool_r"], bx+off[0], by+off[1], bz+off[2]))
    off = apply(R, [0, c["h"]+0.012, 0])
    wicks.append(inst(R, 0.0022, 0.026, 0.0022, bx+off[0], by+off[1], bz+off[2]))
    if c["dish"]:
        dishes.append(inst(R, 0.078, 0.02, 0.078, bx, by-0.009, bz))

print("instances: bodies %d pools %d wicks %d dishes %d" % (len(bodies), len(pools), len(wicks), len(dishes)))
json.dump(dict(candles=candles, bodies=bodies, pools=pools, wicks=wicks, dishes=dishes),
          open(r"C:\Users\穆柏润\AppData\Local\Temp\tfu_candles.json", "w"), indent=0)
