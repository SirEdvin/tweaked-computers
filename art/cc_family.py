# Editable source of the CC-style device artwork (all devices except the monitor).
# Each device copies the look of a CC:Tweaked or addon peripheral, in a worn, lightly rusted
# vanilla-combinator finish. Wire contacts are antenna rings modelled here.
#
# Blender 4.0.2, Cycles, headless:
#   blender -b -P art/cc_family.py -- art/renders [kind ...]
# Writes <kind>-<direction>-{body,shadow}.png at 128 px/tile (3-tile canvas for 1-wide devices,
# 5-tile canvas for wider ones) and art/model-points.json.
# assets/generate.py downscales the renders to 64 px/tile and exports the game sprites.
#
# Camera: orthographic, 45 degrees from the south; sun 45 degrees up from the north-west.
# Model depth is stretched by sqrt(2), so footprints stay square on the tile grid.
# The north sprite shows the front (-Y). Blender units are tiles; the entity centre is the origin.
import bpy, json, math, os, sys

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
os.makedirs(OUT, exist_ok=True)
S2 = math.sqrt(2)
_mats = {}


def _principled(m):
    return m.node_tree.nodes["Principled BSDF"]


def plain(name, color, metal=0.0, rough=0.6, emit=None):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; b = _principled(m)
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal; b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit[0], 1)
        b.inputs["Emission Strength"].default_value = emit[1]
    _mats[name] = m
    return m


def worn(name, paint, bare=(0.32, 0.31, 0.29), chip=0.58, grime=0.9, scale=22.0):
    """Painted metal: noise chips expose bare steel, AO darkens crevices, large noise adds dirt."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = _principled(m); N = nt.nodes.new; L = nt.links.new
    tc = N("ShaderNodeTexCoord")
    chips = N("ShaderNodeTexNoise"); chips.inputs["Scale"].default_value = scale
    chips.inputs["Detail"].default_value = 10; L(tc.outputs["Object"], chips.inputs["Vector"])
    cr = N("ShaderNodeValToRGB"); cr.color_ramp.elements[0].position = chip
    cr.color_ramp.elements[1].position = chip + 0.04; L(chips.outputs["Fac"], cr.inputs["Fac"])
    paintmix = N("ShaderNodeMix"); paintmix.data_type = "RGBA"
    paintmix.inputs[6].default_value = (*paint, 1); paintmix.inputs[7].default_value = (*bare, 1)
    L(cr.outputs["Color"], paintmix.inputs["Factor"])
    dirt = N("ShaderNodeTexNoise"); dirt.inputs["Scale"].default_value = 4; L(tc.outputs["Object"], dirt.inputs["Vector"])
    dr = N("ShaderNodeValToRGB"); dr.color_ramp.elements[0].color = (0.55, 0.5, 0.42, 1); L(dirt.outputs["Fac"], dr.inputs["Fac"])
    ao = N("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.16
    ar = N("ShaderNodeValToRGB"); ar.color_ramp.elements[0].color = (0.18, 0.15, 0.12, 1)
    ar.color_ramp.elements[1].position = 0.9; L(ao.outputs["AO"], ar.inputs["Fac"])
    m1 = N("ShaderNodeMix"); m1.data_type = "RGBA"; m1.blend_type = "MULTIPLY"; m1.inputs["Factor"].default_value = grime
    L(paintmix.outputs[2], m1.inputs[6]); L(dr.outputs["Color"], m1.inputs[7])
    m2 = N("ShaderNodeMix"); m2.data_type = "RGBA"; m2.blend_type = "MULTIPLY"; m2.inputs["Factor"].default_value = 1
    L(m1.outputs[2], m2.inputs[6]); L(ar.outputs["Color"], m2.inputs[7])
    sp = N("ShaderNodeTexNoise"); sp.inputs["Scale"].default_value = 140; sp.inputs["Detail"].default_value = 4
    L(tc.outputs["Object"], sp.inputs["Vector"])
    sr = N("ShaderNodeValToRGB"); sr.color_ramp.elements[0].color = (0.55, 0.52, 0.48, 1)
    sr.color_ramp.elements[0].position = 0.35; sr.color_ramp.elements[1].position = 0.65; L(sp.outputs["Fac"], sr.inputs["Fac"])
    m3 = N("ShaderNodeMix"); m3.data_type = "RGBA"; m3.blend_type = "MULTIPLY"; m3.inputs["Factor"].default_value = 1
    L(m2.outputs[2], m3.inputs[6]); L(sr.outputs["Color"], m3.inputs[7])
    L(m3.outputs[2], b.inputs["Base Color"])
    met = N("ShaderNodeMapRange"); met.inputs[3].default_value = 0.15; met.inputs[4].default_value = 0.85
    L(cr.outputs["Color"], met.inputs[0]); L(met.outputs[0], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = 0.62
    bump = N("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.25
    L(chips.outputs["Fac"], bump.inputs["Height"]); L(bump.outputs["Normal"], b.inputs["Normal"])
    _mats[name] = m
    return m


def M(key):
    return {
        "steel": lambda: worn("steel", (0.36, 0.37, 0.37), bare=(0.55, 0.55, 0.52), chip=0.7, grime=0.6),
        "iron": lambda: worn("iron", (0.13, 0.13, 0.13), bare=(0.3, 0.29, 0.27), chip=0.72, grime=0.5),
        "teal": lambda: worn("teal", (0.06, 0.25, 0.27)),
        "violet": lambda: worn("violet", (0.22, 0.11, 0.30)),
        "orange": lambda: worn("orange", (0.55, 0.20, 0.04)),
        "hose": lambda: worn("hose", (0.50, 0.36, 0.06), bare=(0.2, 0.15, 0.05), chip=0.7, scale=60),
        "ceramic": lambda: plain("ceramic", (0.6, 0.58, 0.52), 0.0, 0.4),
        "red": lambda: plain("red", (0.62, 0.03, 0.02), 0.0, 0.25),
        "green": lambda: plain("green", (0.04, 0.45, 0.06), 0.0, 0.25),
        "cell": lambda: plain("cell", (0.015, 0.02, 0.018), 0.2, 0.3),
        "lit": lambda: plain("lit", (0.1, 0.4, 0.1), 0.0, 0.3, emit=((0.35, 1.0, 0.3), 1.6)),
        "amber": lambda: plain("amber", (0.4, 0.2, 0.0), 0.0, 0.3, emit=((1.0, 0.55, 0.05), 4)),
        "key": lambda: plain("key", (0.42, 0.40, 0.34), 0.0, 0.55),
        "keydark": lambda: plain("keydark", (0.08, 0.08, 0.08), 0.0, 0.55),
        "tape": lambda: plain("tape", (0.06, 0.04, 0.03), 0.1, 0.35),
    }[key]()


def _finish(o, m, bevel, seg=2):
    if bevel:
        bv = o.modifiers.new("b", "BEVEL"); bv.width = bevel; bv.segments = seg; bv.limit_method = "ANGLE"
    o.data.materials.append(M(m))
    return o


def box(loc, size, m, bevel=0.012, rot=(0, 0, 0), seg=2):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object; o.scale = [s / 2 for s in size]
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, m, bevel, seg)


def cyl(loc, r, h, m, rot=(0, 0, 0), v=24, bevel=0.004):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object; bpy.ops.object.shade_smooth()
    return _finish(o, m, bevel)


def ball(loc, r, m, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=16, ring_count=8)
    o = bpy.context.object; o.scale.z = sz; bpy.ops.object.shade_smooth()
    o.data.materials.append(M(m)); return o


def tube(points, m, r=0.018):
    c = bpy.data.curves.new("tube", "CURVE"); c.dimensions = "3D"; c.bevel_depth = r; c.bevel_resolution = 4
    c.use_fill_caps = True
    s = c.splines.new("BEZIER"); s.bezier_points.add(len(points) - 1)
    for bp, p in zip(s.bezier_points, points):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new("tube", c); bpy.context.collection.objects.link(o); o.data.materials.append(M(m))
    return o


# ---------- combinator kit ----------


def rivets(p0, p1, n, z, r=0.009):
    for i in range(n):
        t = i / (n - 1)
        ball((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, z), r, "steel", 0.6)


def keyboard(cx, cy, cz, cols, rows, tilt=12):
    rot = (math.radians(tilt), 0, 0); k = 0.052
    box((cx, cy, cz), (cols * k + 0.04, rows * k + 0.04, 0.03), "iron", 0.006, rot)
    ct, st = math.cos(rot[0]), math.sin(rot[0])
    for r in range(rows):
        for c in range(cols):
            v = (r - (rows - 1) / 2) * k; u = (c - (cols - 1) / 2) * k
            box((cx + u, cy + v * ct, cz + v * st + 0.022), (k * 0.78, k * 0.78, 0.016),
                "keydark" if (r + c) % 5 == 0 else "key", 0.004, rot)


def vents(cx, y, cz, n, w, h, axis="x"):
    for i in range(n):
        off = (i - (n - 1) / 2) * 0.03
        loc = (cx + off, y, cz) if axis == "x" else (cx, y + off, cz)
        box(loc, (0.014, 0.01, h) if axis == "x" else (0.01, 0.014, h), "iron", 0)


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True); _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.samples = 160; sc.cycles.use_denoising = False
    sc.render.film_transparent = True; sc.render.filter_size = 1.5
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.42, 0.44, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    bpy.ops.object.light_add(type="SUN", rotation=(math.pi / 4, 0, math.pi + math.pi / 4))
    bpy.context.object.data.energy = 5.0; bpy.context.object.data.angle = math.radians(8)
    bpy.ops.object.camera_add(location=(0, -60, 60.25), rotation=(math.pi / 4, 0, 0))
    cam = bpy.context.object; cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.6; cam.data.clip_end = 200
    sc.camera = cam


EXTRA = {
    "role_input": lambda: plain("role_input", (0.85, 0.42, 0.08), 0.0, 0.4),
    "role_network": lambda: plain("role_network", (0.15, 0.55, 0.85), 0.0, 0.4),
    "role_output": lambda: plain("role_output", (0.35, 0.8, 0.15), 0.0, 0.4),
    "role_targets": lambda: plain("role_targets", (0.6, 0.3, 0.85), 0.0, 0.4),
    "paper": lambda: plain("paper", (0.78, 0.75, 0.66), 0.0, 0.7),
    "trace": lambda: plain("trace", (0.05, 0.2, 0.6), 0.0, 0.4, emit=((0.25, 0.5, 1.0), 1.2)),
    "brass": lambda: plain("brass", (0.7, 0.5, 0.2), 1.0, 0.35),
    "copper": lambda: plain("copper", (0.75, 0.36, 0.2), 1.0, 0.35),
    "glass": lambda: plain("glass", (0.012, 0.02, 0.022), 0.0, 0.12),
    "red_lamp": lambda: plain("red_lamp", (0.4, 0.02, 0.0), 0.0, 0.3, emit=((1.0, 0.1, 0.05), 3)),
}


_M_kit = M


def M(key):  # kit helpers (tube/ball) resolve materials through this global too
    return EXTRA[key]() if key in EXTRA else _M_kit(key)


def mat_any(key):
    return EXTRA[key]() if key in EXTRA else M(key)


def bx(loc, size, key, bevel=0.01, rot=(0, 0, 0), seg=2):
    o = box(loc, size, "iron", bevel, rot, seg); o.data.materials[0] = mat_any(key); return o


def cy(loc, r, h, key, rot=(0, 0, 0), v=24, bevel=0.004):
    o = cyl(loc, r, h, "iron", rot, v, bevel); o.data.materials[0] = mat_any(key); return o


# ---------- shared family parts ----------
def dial(cx, cy_, cz, r, tilt=-35, needle=40):
    rot = (math.radians(90 + tilt), 0, 0)
    ct, st = math.cos(math.radians(90 + tilt)), math.sin(math.radians(90 + tilt))
    off = lambda d: (cx, cy_ - d * st, cz + d * ct)
    cy(off(0), r, 0.03, "steel", rot, 32)
    cy(off(0.012), r * 0.82, 0.012, "ceramic", rot, 32)
    a = math.radians(needle)
    nx, nz = math.sin(a) * r * 0.35, math.cos(a) * r * 0.35
    p = off(0.022)
    bx((p[0] + nx, p[1] - nz * ct, p[2] + nz * st), (0.008, 0.004, r * 0.7), "tape", 0, (rot[0], a, 0))
    ball(off(0.024), r * 0.12, "steel")
    for k in range(7):  # tick marks
        t = math.radians(-90 + k * 30)
        q = off(0.02)
        bx((q[0] + math.sin(t) * r * 0.66, q[1] - math.cos(t) * r * 0.66 * ct, q[2] + math.cos(t) * r * 0.66 * st),
           (0.006, 0.004, 0.018), "tape", 0, (rot[0], t, 0))


EXTRA.update({
    "casing": lambda: worn("casing", (0.56, 0.54, 0.49), bare=(0.38, 0.37, 0.35), chip=0.68, grime=0.8, scale=9.0),
    "bezel": lambda: worn("bezel", (0.24, 0.24, 0.23), bare=(0.4, 0.4, 0.38), chip=0.72, grime=0.6),
    "gold": lambda: worn("gold", (0.62, 0.48, 0.16), bare=(0.4, 0.33, 0.2), chip=0.72, grime=0.6),
    "ap_orange": lambda: worn("ap_orange", (0.62, 0.3, 0.08), bare=(0.35, 0.3, 0.25), chip=0.7, grime=0.7),
    "ap_dark": lambda: worn("ap_dark", (0.17, 0.18, 0.19), bare=(0.35, 0.35, 0.33), chip=0.7, grime=0.6),
    "plethora": lambda: worn("plethora", (0.16, 0.3, 0.42), bare=(0.35, 0.35, 0.33), chip=0.7, grime=0.65),
    "crate": lambda: worn("crate", (0.42, 0.29, 0.15), bare=(0.3, 0.22, 0.12), chip=0.75, grime=0.7, scale=14.0),
    "text": lambda: plain("text", (0.7, 0.7, 0.65), 0.0, 0.3, emit=((0.92, 0.95, 0.85), 1.3)),
    "prompt": lambda: plain("prompt", (0.7, 0.6, 0.1), 0.0, 0.3, emit=((1.0, 0.85, 0.2), 2.0)),
    "power": lambda: plain("power", (0.1, 0.5, 0.1), 0.0, 0.3, emit=((0.3, 1.0, 0.25), 6)),
    "floppy": lambda: plain("floppy", (0.12, 0.25, 0.6), 0.0, 0.45),
    "label": lambda: plain("label", (0.85, 0.82, 0.7), 0.0, 0.6),
    "cyan": lambda: plain("cyan", (0.0, 0.5, 0.65), 0.0, 0.4),
    "magenta": lambda: plain("magenta", (0.6, 0.05, 0.4), 0.0, 0.4),
    "redstone": lambda: plain("redstone", (0.5, 0.0, 0.0), 0.0, 0.4, emit=((1.0, 0.08, 0.02), 2.5)),
    "radar": lambda: plain("radar", (0.05, 0.3, 0.1), 0.0, 0.3, emit=((0.3, 1.0, 0.4), 1.6)),
})


# ---------- D-style shared parts ----------
def cc_block(w, d, h, x=0.0, y=0.0, colour="casing", trim="bezel"):
    """Worn CC block: casing, top inset panel, dark edge trims, feet. Returns top height."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx((x + sx * (w / 2 - 0.06), y + sy * (d / 2 - 0.06), 0.02), (0.12, 0.12, 0.04), "iron", 0.01)
    top = 0.04 + h
    bx((x, y, 0.04 + h / 2), (w, d, h), colour, 0.035, seg=3)
    bx((x, y, top + 0.002), (w - 0.1, d - 0.1, 0.012), trim, 0.004)
    bx((x, y, top + 0.01), (w - 0.16, d - 0.16, 0.008), colour, 0.003)
    for sx in (-1, 1):
        bx((x + sx * (w / 2 - 0.012), y, top - 0.012), (0.03, d - 0.02, 0.03), trim, 0.006)
    bx((x, y + d / 2 - 0.012, top - 0.012), (w - 0.02, 0.03, 0.03), trim, 0.006)
    rivets((x - w / 2 + 0.06, y - d / 2 + 0.06), (x + w / 2 - 0.06, y - d / 2 + 0.06), 2, top + 0.005)
    return top


def antenna(role, face_x, side, y=0.18, z0=0.36, length=0.34):
    """D-style mast on a side bracket (side=-1 left face, +1 right face). Red/green rings under a ball tip."""
    ax = face_x + side * 0.045
    bx((face_x + side * 0.02, y, z0 - 0.1), (0.05, 0.1, 0.16), "iron", 0.008)
    rivets((face_x + side * 0.046, y - 0.03), (face_x + side * 0.046, y + 0.03), 2, z0 - 0.05)
    cy((ax, y, z0), 0.03, 0.06, "iron")
    for k, r in enumerate((0.034, 0.03, 0.026)):
        cy((ax, y, z0 + 0.045 + k * 0.03), r, 0.016, "ceramic")
    tip = z0 + 0.11 + length
    cy((ax, y, (z0 + 0.11 + tip) / 2), 0.011, tip - z0 - 0.11, "steel")
    cy((ax, y, tip - 0.11), 0.03, 0.018, "role_" + role, bevel=0.006)  # role band
    rings = {"red": tip - 0.075, "green": tip - 0.035}
    for col, z in rings.items():
        cy((ax, y, z), 0.026, 0.024, col, bevel=0.008)
    ball((ax, y, tip + 0.012), 0.024, "steel")
    return {c: (ax, y, z) for c, z in rings.items()}


def top_mast(role, x, y, top, length=0.3):
    """Antenna standing on a block top (for middle sections)."""
    cy((x, y, top + 0.03), 0.04, 0.05, "iron")
    for k, r in enumerate((0.034, 0.03)):
        cy((x, y, top + 0.07 + k * 0.03), r, 0.016, "ceramic")
    tip = top + 0.1 + length
    cy((x, y, (top + 0.1 + tip) / 2), 0.011, tip - top - 0.1, "steel")
    cy((x, y, tip - 0.11), 0.03, 0.018, "role_" + role, bevel=0.006)
    rings = {"red": tip - 0.075, "green": tip - 0.035}
    for col, z in rings.items():
        cy((x, y, z), 0.026, 0.024, col, bevel=0.008)
    ball((x, y, tip + 0.012), 0.024, "steel")
    return {c: (x, y, z) for c, z in rings.items()}


def front_panel(x, y, z, w, h, key="bezel", depth=0.02):
    return bx((x, y - depth / 2, z), (w, depth, h), key, 0.006)


def text_lines(x0, y, z0, lines, cell=0.04, row=0.07, h=0.045):
    for r, line in enumerate(lines):
        for c, ch in enumerate(line):
            if ch != " ":
                bx((x0 + c * cell, y, z0 - r * row), (cell * 0.7, 0.006, h), "prompt" if ch in ">_" else "text", 0)


def cc_screen(x, y, z, w, h, lines=(), cell=0.04, row=0.07):
    front_panel(x, y, z, w + 0.08, h + 0.08)
    bx((x, y - 0.012, z), (w, 0.012, h), "glass", 0.002)
    if lines:
        text_lines(x - w / 2 + 0.04, y - 0.02, z + h / 2 - 0.05, lines, cell, row)


def side_vents(x, z, n=6, h=0.26):
    vents(x, 0.0, z, n, 0, h, axis="y")


# ---------- devices (north = front toward -Y / camera) ----------
def computer():                       # CC:Tweaked Computer
    W, D = 0.80, 0.74
    top = cc_block(W, D, 0.66)
    for i in range(7):
        box((0.1, -0.16 + i * 0.05, top + 0.016), (0.32, 0.022, 0.006), "iron", 0)
    bx((-0.22, -0.02, top + 0.018), (0.14, 0.3, 0.01), "bezel", 0.003)
    cc_screen(0, -D / 2, 0.44, 0.58, 0.34, ["CraftOS 1.9", "", "> run main", "> _"])
    front_panel(-0.12, -D / 2, 0.13, 0.3, 0.045); bx((-0.12, -D / 2 - 0.019, 0.13), (0.24, 0.004, 0.012), "glass", 0)
    bx((0.27, -D / 2 - 0.01, 0.12), (0.06, 0.02, 0.04), "power", 0.004)
    side_vents(W / 2 + 0.002, 0.38)
    return {"network": antenna("network", -W / 2, -1, z0=0.66)}


def kv():                             # CC:Tweaked Disk Drive
    W, D = 0.78, 0.72
    top = cc_block(W, D, 0.58)
    front_panel(0, -D / 2, 0.36, 0.62, 0.18)
    bx((0, -D / 2 - 0.022, 0.36), (0.5, 0.006, 0.05), "glass", 0)                 # drive slot
    bx((0.0, -D / 2 - 0.05, 0.37), (0.34, 0.06, 0.012), "floppy", 0.004)          # floppy half inserted
    bx((0.0, -D / 2 - 0.075, 0.378), (0.18, 0.014, 0.006), "label", 0)
    bx((0.06, -D / 2 - 0.06, 0.378), (0.08, 0.02, 0.006), "steel", 0)             # shutter
    bx((0.26, -D / 2 - 0.022, 0.2), (0.05, 0.01, 0.03), "power", 0)
    bx((0.18, -D / 2 - 0.022, 0.2), (0.05, 0.01, 0.03), "amber", 0)
    for i in range(4):                                                            # drive bay seams
        bx((-0.2 + i * 0.13, -D / 2 - 0.003, 0.14), (0.1, 0.008, 0.07), "bezel", 0.004)
    for i in range(3):                                                            # stacked floppies on top
        bx((0.12 - i * 0.015, 0.08 + i * 0.012, top + 0.03 + i * 0.016), (0.24, 0.24, 0.014),
           ("floppy", "magenta", "cyan")[i], 0.004)
        bx((0.12 - i * 0.015, -0.02 + i * 0.012, top + 0.039 + i * 0.016), (0.14, 0.05, 0.002), "label", 0)
    side_vents(W / 2 + 0.002, 0.34)
    return {"network": antenna("network", -W / 2, -1, z0=0.6)}


def logic():                          # CC:Tweaked Redstone Relay x3 (input / relay / output)
    D = 0.7; contacts = {}
    for i, x in enumerate((-1.0, 0.0, 1.0)):
        top = cc_block(0.8, D, 0.42, x=x)
        for k in range(3):                                                        # redstone traces
            bx((x - 0.2 + k * 0.2, -0.05, top + 0.017), (0.025, 0.36, 0.004), "redstone", 0)
        bx((x, 0.13, top + 0.017), (0.44, 0.025, 0.004), "redstone", 0)
        cy((x + 0.2, -0.2, top + 0.04), 0.03, 0.05, "ceramic")                     # torch-like lamp
        ball((x + 0.2, -0.2, top + 0.075), 0.026, "red_lamp")
        front_panel(x, -D / 2, 0.24, 0.6, 0.2)
        if i == 1:
            cc_screen(x, -D / 2 - 0.02, 0.24, 0.44, 0.14, ["A > B"], cell=0.07, row=0.07)
        else:
            for k in range(6):                                                    # side faces: R/G/B ports
                bx((x - 0.22 + k * 0.088, -D / 2 - 0.022, 0.24), (0.05, 0.008, 0.05),
                   "redstone" if (k + i) % 3 == 0 else "glass", 0.003)
    for x in (-0.5, 0.5):                                                         # couplers between blocks
        cy((x, 0.0, 0.26), 0.05, 0.12, "steel", rot=(0, math.radians(90), 0))
    contacts["input"] = antenna("input", -1.4, -1, z0=0.42, length=0.3)
    contacts["output"] = antenna("output", 1.4, 1, z0=0.42, length=0.3)
    contacts["network"] = top_mast("network", 0.0, 0.2, 0.46)
    return contacts


def configurator():                   # Advanced Peripherals Inventory Manager + chest interface
    D = 0.72
    top = cc_block(0.82, D, 0.6, x=-0.5, colour="ap_dark", trim="ap_orange")
    cc_screen(-0.5, -D / 2, 0.44, 0.48, 0.18, ["INV: 27", "> push"], cell=0.04, row=0.07)
    front_panel(-0.5, -D / 2, 0.16, 0.5, 0.12, key="ap_orange")
    bx((-0.5, -D / 2 - 0.022, 0.16), (0.3, 0.006, 0.03), "glass", 0)              # memory-card slot
    bx((-0.5, -D / 2 - 0.04, 0.17), (0.16, 0.03, 0.008), "gold", 0.003)
    # chest interface on the right: worn crate with steel bands, item grid display on its lid
    t2 = 0.52
    bx((0.5, 0, 0.04 + t2 / 2), (0.8, D, t2), "crate", 0.03, seg=3)
    for z in (0.14, 0.42):
        bx((0.5, -D / 2 - 0.004, z), (0.82, 0.02, 0.05), "steel", 0.006)
    bx((0.5, -D / 2 - 0.02, 0.33), (0.1, 0.03, 0.08), "steel", 0.008)             # latch
    for r in range(3):
        for c in range(4):
            bx((0.32 + c * 0.12, -0.12 + r * 0.12, 0.04 + t2 + 0.012), (0.09, 0.09, 0.012),
               ("cyan", "amber", "floppy", "copper", "lit", "magenta")[(r * 4 + c) % 6], 0.003)
    cy((0.0, 0.1, 0.3), 0.04, 0.2, "ap_orange", rot=(0, math.radians(90), 0))     # transfer pipe
    return {"network": antenna("network", -0.91, -1, z0=0.6), "targets": antenna("targets", 0.9, 1, z0=0.52)}


def recipe_searcher():                # Advanced Peripherals Geo Scanner / Plethora scanner
    W, D = 0.78, 0.72
    top = cc_block(W, D, 0.44, colour="plethora")
    cc_screen(0, -D / 2, 0.27, 0.42, 0.24)
    for r in range(5):                                                            # radar sweep on screen
        for c in range(7):
            dx, dz = c - 3, r - 2
            if abs(math.hypot(dx, dz * 1.2) - 2.2) < 0.5 or (dx == dz and dx >= 0) or (dx == 0 and dz == 0):
                bx((-0.18 + c * 0.06, -D / 2 - 0.03, 0.15 + r * 0.06), (0.04, 0.006, 0.04), "radar", 0)
    cy((0.05, 0.05, top + 0.05), 0.12, 0.08, "steel")                             # turntable
    cy((0.05, 0.05, top + 0.12), 0.03, 0.08, "steel")
    dish = cy((0.05, 0.02, top + 0.24), 0.22, 0.03, "casing", rot=(math.radians(-55), 0, 0), v=40)
    cy((0.05, -0.0, top + 0.25), 0.16, 0.034, "bezel", rot=(math.radians(-55), 0, 0), v=40)
    tube([(0.05, -0.02, top + 0.26), (0.05, -0.12, top + 0.33)], "steel", 0.008)  # feed horn
    ball((0.05, -0.12, top + 0.34), 0.022, "amber")
    return {"network": antenna("network", -W / 2, -1, y=0.2, z0=0.46)}


def factoriopedia_interface():        # CC:Tweaked Printer
    W, D = 0.78, 0.72
    top = cc_block(W, D, 0.5)
    front_panel(0, -D / 2, 0.3, 0.6, 0.1)
    bx((0, -D / 2 - 0.022, 0.3), (0.5, 0.006, 0.03), "glass", 0)                  # output slot
    for i in range(3):                                                            # printed pages coming out
        bx((0.0 + i * 0.01, -D / 2 - 0.08 - i * 0.012, 0.29 - i * 0.012), (0.4, 0.14, 0.004), "paper", 0,
           (math.radians(-18 - i * 4), 0, math.radians(i * 3)))
    for k in range(4):
        bx((-0.1 + k * 0.05, -D / 2 - 0.13, 0.27), (0.03, 0.04, 0.002), "tape", 0, (math.radians(-18), 0, 0))
    bx((0, 0.16, top + 0.12), (0.5, 0.06, 0.22), "bezel", 0.008, (math.radians(-15), 0, 0))   # paper feed tray
    for i in range(4):
        bx((0, 0.12 - i * 0.012, top + 0.14), (0.44, 0.004, 0.2), "paper", 0, (math.radians(-15), 0, 0))
    for i, col in enumerate(("cyan", "magenta", "amber", "tape")):               # ink cartridges
        bx((0.36, -0.2 + i * 0.1, 0.36), (0.03, 0.07, 0.1), col, 0.006)
    bx((0.26, -D / 2 - 0.01, 0.13), (0.06, 0.02, 0.04), "power", 0.004)
    return {"network": antenna("network", -W / 2, -1, z0=0.52)}


def production_statistics():          # Advanced Peripherals Energy Detector
    W, D = 0.78, 0.72
    top = cc_block(W, D, 0.56, colour="ap_dark", trim="ap_orange")
    front_panel(0, -D / 2, 0.34, 0.6, 0.44, key="ap_orange")
    dial(0.0, -D / 2 - 0.03, 0.4, 0.17, tilt=-90 + 90, needle=50)
    for sx in (-1, 1):                                                            # in / out power ports
        cy((sx * (W / 2 + 0.03), 0.0, 0.3), 0.08, 0.06, "copper", rot=(0, math.radians(90), 0))
        cy((sx * (W / 2 + 0.05), 0.0, 0.3), 0.05, 0.03, "iron", rot=(0, math.radians(90), 0))
    bx((-0.17, -D / 2 - 0.022, 0.17), (0.2, 0.006, 0.05), "lit", 0)
    bx((0.17, -D / 2 - 0.022, 0.17), (0.2, 0.006, 0.05), "amber", 0)
    bx((0, 0.02, top + 0.016), (0.5, 0.36, 0.012), "glass", 0.003)                # top flow-history screen
    for c in range(10):
        h = (1, 2, 2, 3, 4, 3, 4, 5, 6, 5)[c]
        for r in range(h):
            bx((-0.2 + c * 0.045, -0.13 + r * 0.05, top + 0.024), (0.032, 0.036, 0.004), "lit" if c > 7 else "radar", 0)
    return {"network": antenna("network", -W / 2, -1, y=0.22, z0=0.56)}


def dashboard():                      # Tom's Peripherals keyboard + GPU console
    W, D = 0.8, 0.72
    top = cc_block(W, D, 0.3)
    bx((0, 0.14, top + 0.17), (0.72, 0.1, 0.34), "casing", 0.02, (math.radians(-12), 0, 0))  # screen hood
    bx((0, 0.085, top + 0.17), (0.6, 0.01, 0.26), "glass", 0.002, (math.radians(-12), 0, 0))
    for r, line in enumerate(["PWR  98%", "ORE  1.2k", "[######  ]"]):
        for c, ch in enumerate(line):
            if ch != " ":
                bx((-0.25 + c * 0.05, 0.075, top + 0.25 - r * 0.07), (0.035, 0.006, 0.04),
                   "prompt" if ch in "[]" else "radar" if ch == "#" else "text", 0, (math.radians(-12), 0, 0))
    keyboard(0, -0.17, top + 0.02, 8, 3, tilt=10)
    bx((0.31, -0.3, top + 0.03), (0.07, 0.07, 0.03), "red_lamp", 0.01)
    return {"network": antenna("network", -W / 2, -1, y=0.15, z0=0.36, length=0.36)}


def rusty(name, paint, chip=0.66, patch=0.0, streak=0.0, fade=0.0, scale=9.0):
    """Painted steel that rusts: chips expose rust (not bare steel), large patches bloom through
    the paint, and vertical drip streaks run down side faces only."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = _principled(m); N = nt.nodes.new; L = nt.links.new

    def ramp(src, a, b_, c0=(0, 0, 0, 1), c1=(1, 1, 1, 1)):
        r = N("ShaderNodeValToRGB"); e = r.color_ramp.elements
        e[0].position, e[0].color, e[1].position, e[1].color = a, c0, b_, c1
        L(src, r.inputs["Fac"]); return r

    def mix(a, b_, fac, mode="MIX"):
        x = N("ShaderNodeMix"); x.data_type = "RGBA"; x.blend_type = mode
        if isinstance(fac, float):
            x.inputs["Factor"].default_value = fac
        else:
            L(fac, x.inputs["Factor"])
        for slot, v in ((6, a), (7, b_)):
            if isinstance(v, tuple):
                x.inputs[slot].default_value = v
            else:
                L(v, x.inputs[slot])
        return x.outputs[2]

    def noise(vec, sc, detail=8, rough=0.55):
        n = N("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = sc
        n.inputs["Detail"].default_value = detail; n.inputs["Roughness"].default_value = rough
        L(vec, n.inputs["Vector"]); return n

    tc = N("ShaderNodeTexCoord"); obj = tc.outputs["Object"]
    # rust colour: dark brown -> orange, varied by fine noise
    rc = ramp(noise(obj, 40, 6).outputs["Fac"], 0.35, 0.7, (0.16, 0.06, 0.025, 1), (0.52, 0.2, 0.05, 1))
    # paint (optionally faded toward a chalky grey)
    p = paint if not fade else tuple(c * (1 - fade) + 0.5 * fade for c in paint)
    paint_c = (*p, 1)
    # masks
    chips = ramp(noise(obj, scale * 2.4, 10).outputs["Fac"], chip, chip + 0.03)
    masks = [chips.outputs["Color"]]
    if patch:
        pm = ramp(noise(obj, 3.2, 6).outputs["Fac"], 0.62 - patch * 0.3, 0.68 - patch * 0.3)
        masks.append(pm.outputs["Color"])
    if streak:
        stretch = N("ShaderNodeMapping"); stretch.inputs["Scale"].default_value = (55, 55, 2.2)
        L(obj, stretch.inputs["Vector"])
        st = ramp(noise(stretch.outputs["Vector"], 1.0, 3, 0.4).outputs["Fac"], 0.62 - streak * 0.25, 0.7 - streak * 0.2)
        geo = N("ShaderNodeNewGeometry"); sep = N("ShaderNodeSeparateXYZ"); L(geo.outputs["Normal"], sep.inputs["Vector"])
        side = N("ShaderNodeMath"); side.operation = "ABSOLUTE"; L(sep.outputs["Z"], side.inputs[0])
        vert = ramp(side.outputs["Value"], 0.2, 0.5, (1, 1, 1, 1), (0, 0, 0, 1))      # 1 on vertical faces
        sm = N("ShaderNodeMix"); sm.data_type = "RGBA"; sm.blend_type = "MULTIPLY"; sm.inputs["Factor"].default_value = 1
        L(st.outputs["Color"], sm.inputs[6]); L(vert.outputs["Color"], sm.inputs[7])
        masks.append(sm.outputs[2])
    rust_mask = masks[0]
    for extra in masks[1:]:
        rust_mask = mix(rust_mask, extra, 1.0, "LIGHTEN")
    base = mix(paint_c, rc.outputs["Color"], rust_mask)
    # grime + AO as in the worn material
    dirt = ramp(noise(obj, 4, 8).outputs["Fac"], 0.0, 1.0, (0.55, 0.5, 0.42, 1), (1, 1, 1, 1))
    ao = N("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.16
    aor = ramp(ao.outputs["AO"], 0.0, 0.9, (0.18, 0.15, 0.12, 1), (1, 1, 1, 1))
    speck = ramp(noise(obj, 140, 4).outputs["Fac"], 0.35, 0.65, (0.55, 0.52, 0.48, 1), (1, 1, 1, 1))
    col = mix(mix(mix(base, dirt.outputs["Color"], 0.8, "MULTIPLY"), aor.outputs["Color"], 1.0, "MULTIPLY"),
              speck.outputs["Color"], 1.0, "MULTIPLY")
    L(col, b.inputs["Base Color"])
    # rust is matte and non-metallic; paint slightly glossy
    bw = N("ShaderNodeRGBToBW"); L(rust_mask, bw.inputs["Color"])
    rr = N("ShaderNodeMapRange"); rr.inputs[3].default_value = 0.55; rr.inputs[4].default_value = 0.9
    L(bw.outputs["Val"], rr.inputs[0]); L(rr.outputs[0], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.15
    bump = N("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    L(bw.outputs["Val"], bump.inputs["Height"]); L(bump.outputs["Normal"], b.inputs["Normal"])
    _mats[name] = m
    return m

# Light rust: rust in paint chips and worn edges, faint drips on side faces.
LIGHT = dict(chip=0.62, streak=0.35)
EXTRA["casing"] = lambda: rusty("casing", (0.56, 0.54, 0.49), **LIGHT)
EXTRA["bezel"] = lambda: rusty("bezel", (0.24, 0.24, 0.23), chip=0.64)
EXTRA["iron"] = lambda: rusty("iron", (0.2, 0.19, 0.18), chip=0.55, patch=0.3)
EXTRA["ap_dark"] = lambda: rusty("ap_dark", (0.17, 0.18, 0.19), **LIGHT)
EXTRA["ap_orange"] = lambda: rusty("ap_orange", (0.62, 0.3, 0.08), **LIGHT)
EXTRA["plethora"] = lambda: rusty("plethora", (0.16, 0.3, 0.42), **LIGHT)

DEVICES = dict(computer=(computer, 1), kv=(kv, 1), logic=(logic, 3), configurator=(configurator, 2),
               recipe_searcher=(recipe_searcher, 1), factoriopedia_interface=(factoriopedia_interface, 1),
               production_statistics=(production_statistics, 1), dashboard=(dashboard, 1))
# Status-mark anchor: a front-face light on each model (Blender coordinates).
STATUS = dict(computer=(0.27, -0.39, 0.12), kv=(0.26, -0.382, 0.2), logic=(0.2, -0.2, 0.535),
              configurator=(-0.28, -0.38, 0.16), recipe_searcher=(0.05, -0.12, 0.82),
              factoriopedia_interface=(0.26, -0.37, 0.13), production_statistics=(0.17, -0.382, 0.17),
              dashboard=(0.31, -0.3, 0.37))
ROT = {"north": 0, "east": -90, "south": 180, "west": 90}  # clockwise on screen, as Factorio directions


def factorio(p):
    """Blender point -> north-frame Factorio point (x right, y south, z up), in tiles."""
    return [round(p[0], 4), round(-p[1], 4), round(p[2], 4)]


def render(kind, direction, shadow, contacts_out):
    build, width = DEVICES[kind]
    setup_scene()
    sc = bpy.context.scene
    tiles = 3.0 if width == 1 else 5.0  # 192 px or 320 px game canvas; antennas need the margin
    sc.render.resolution_x = sc.render.resolution_y = int(64 * tiles * 2)
    sc.camera.data.ortho_scale = tiles
    sc.camera.location = (0, -60, 60)  # entity centre at canvas centre (sprite shift {0, 0})
    sc.cycles.samples = 32 if shadow else 128
    contacts = build()
    rot = bpy.data.objects.new("rot", None); stretch = bpy.data.objects.new("stretch", None)
    for e in (rot, stretch):
        bpy.context.collection.objects.link(e)
    rot.parent = stretch; stretch.scale.y = S2; rot.rotation_euler.z = math.radians(ROT[direction])
    for o in list(bpy.data.objects):
        if o.type in ("MESH", "CURVE"):
            o.parent = rot
            if shadow:
                o.visible_camera = False
    if shadow:
        bpy.ops.mesh.primitive_plane_add(size=12); bpy.context.object.is_shadow_catcher = True
    sc.render.filepath = os.path.join(OUT, f"{kind}-{direction}-{'shadow' if shadow else 'body'}.png")
    if not os.environ.get("POINTS_ONLY"):
        bpy.ops.render.render(write_still=True)
    if not shadow and direction == "north":
        contacts_out[kind] = {"contacts": {role: {c: factorio(p) for c, p in pts.items()} for role, pts in contacts.items()},
                              "status": factorio(STATUS[kind])}
    print("RENDERED", kind, direction, "shadow" if shadow else "body", flush=True)

kinds = ARGS[1:] or list(DEVICES)
points = {}
for k in kinds:
    for d in ROT:
        render(k, d, False, points)
        render(k, d, True, points)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model-points.json")
old = json.load(open(path)) if os.path.exists(path) else {}
old.update(points)
with open(path, "w") as f:
    json.dump(old, f, indent=1, sort_keys=True)
    f.write("\n")
print("POINTS", sorted(old))
