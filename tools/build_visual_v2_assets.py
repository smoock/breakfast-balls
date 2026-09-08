import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path("/Users/stephenmoock/Documents/ChatGPT/Breakfast Balls")
MODEL_DIR = ROOT / "game/assets/models"
SOURCE_DIR = ROOT / "game/assets/source_blender"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        pass


def material(name, color, roughness=0.9):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.roughness = roughness
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = (*color, 1.0)
        principled.inputs["Roughness"].default_value = roughness
    return mat


def add_cone(name, location, radius1, radius2, depth, mat, vertices=10):
    # Asset construction uses Godot-style Y-up coordinates; Blender is Z-up.
    location = (location[0], -location[2], location[1])
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2,
        depth=depth, location=location
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_ico(name, location, scale, mat, subdivision=1):
    location = (location[0], -location[2], location[1])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivision, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def add_branch(name, start, end, radius, mat, vertices=8):
    start = Vector((start[0], -start[2], start[1]))
    end = Vector((end[0], -end[2], end[1]))
    axis = end - start
    midpoint = (start + end) * 0.5
    # add_cone accepts Godot Y-up, while start/end above are already Blender Z-up.
    obj = add_cone(name, (midpoint.x, midpoint.z, -midpoint.y), radius * 1.18, radius * 0.62, axis.length, mat, vertices)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis.normalized())
    return obj


def apply_and_join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if obj.scale != Vector((1, 1, 1)):
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    # Center exported mesh vertices at the trunk foot, not the active primitive.
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    decimate = objects[0].modifiers.new(name="Game silhouette decimation", type="DECIMATE")
    decimate.ratio = 0.45
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    objects[0].data.validate(clean_customdata=False)
    objects[0].data.update()
    return objects[0]


def export_selected(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / filename),
        export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True,
        export_materials="EXPORT"
    )


def build_pine():
    clear_scene()
    bark = material("Pine bark", (0.22, 0.12, 0.065), 0.96)
    bark_light = material("Young branches", (0.31, 0.19, 0.09), 0.94)
    needle_dark = material("Pine needles dark", (0.035, 0.15, 0.085), 0.88)
    needle_mid = material("Pine needles mid", (0.07, 0.25, 0.12), 0.86)
    needle_light = material("Pine needles light", (0.14, 0.34, 0.16), 0.84)
    parts = [add_cone("tapered_trunk", (0, 7.3, 0), 0.72, 0.25, 14.6, bark, 12)]
    # Visible whorled branches create the pine silhouette instead of stacked blobs.
    for tier in range(7):
        y = 5.4 + tier * 1.55
        reach = 4.7 - tier * 0.46
        for arm in range(5):
            a = arm * math.tau / 5 + tier * 0.67
            start = (0, y, 0)
            end = (math.cos(a) * reach, y + 0.2 + tier * 0.07, math.sin(a) * reach)
            parts.append(add_branch(f"branch_{tier}_{arm}", start, end, 0.16 - tier * 0.009, bark_light))
            for spray in range(1, 4):
                t = 0.28 + spray * 0.19
                p = Vector(start).lerp(Vector(end), t)
                mat = (needle_dark, needle_mid, needle_light)[(tier + arm + spray) % 3]
                clump = add_ico(f"needle_{tier}_{arm}_{spray}", p, (0.72 + 0.14 * spray, 0.34, 1.25), mat)
                clump.rotation_euler[2] = -a
                clump.rotation_euler[0] = 0.10 * math.sin(arm + spray)
                parts.append(clump)
    parts.append(add_ico("pine_top", (0, 15.0, 0), (1.05, 1.75, 1.05), needle_light, 2))
    tree = apply_and_join(parts, "Tree_Pine_A")
    export_selected(tree, "tree_pine_a.glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "pine_tree.blend"))


def build_broadleaf():
    clear_scene()
    bark = material("Broadleaf bark", (0.25, 0.14, 0.075), 0.98)
    bark_light = material("Broadleaf branches", (0.34, 0.21, 0.11), 0.96)
    leaves = [
        material("Leaves shadow", (0.045, 0.18, 0.08), 0.90),
        material("Leaves middle", (0.11, 0.31, 0.13), 0.88),
        material("Leaves sun", (0.24, 0.43, 0.18), 0.86),
    ]
    parts = [add_cone("tapered_trunk", (0, 5.4, 0), 0.88, 0.38, 10.8, bark, 12)]
    leaders = [(-2.7, 11.6, 0.8), (2.5, 12.0, -0.6), (-0.3, 13.7, 1.8), (1.1, 12.8, 2.4)]
    for i, end in enumerate(leaders):
        start = (0, 6.4 + 0.35 * i, 0)
        parts.append(add_branch(f"leader_{i}", start, end, 0.34 - 0.035 * i, bark_light, 9))
        e = Vector(end)
        for j in range(4):
            a = i * 1.73 + j * 1.57
            p = e + Vector((math.cos(a) * (1.0 + 0.35 * j), 0.15 * j, math.sin(a) * (1.1 + 0.28 * j)))
            scale = (1.75 + 0.18 * j, 1.25 + 0.15 * (j % 2), 1.55 + 0.12 * i)
            crown = add_ico(f"crown_{i}_{j}", p, scale, leaves[(i + j) % 3], 2)
            crown.rotation_euler = (0.12 * j, 0.18 * math.sin(a), a * 0.27)
            parts.append(crown)
    tree = apply_and_join(parts, "Tree_Broadleaf_A")
    export_selected(tree, "tree_broadleaf_a.glb")


MODEL_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_DIR.mkdir(parents=True, exist_ok=True)
build_pine()
build_broadleaf()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "visual_v2_trees.blend"))
print("VISUAL_V2_ASSETS_READY")
