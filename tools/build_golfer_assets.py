"""Editable, softly tailored golfer components. Run in Blender background mode."""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'game/assets/models'
SOURCE = ROOT / 'game/assets/source_blender'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def tailored(name, rings, segments=32):
    vertices, faces = [], []
    for y, rx, rz, z in rings:
        for i in range(segments):
            a = math.tau * i / segments
            # Rounded rectangular clothing profile rather than a box or sphere.
            x = math.copysign(abs(math.cos(a)) ** 0.72, math.cos(a)) * rx
            depth = math.copysign(abs(math.sin(a)) ** 0.72, math.sin(a)) * rz + z
            vertices.append((x, -depth, y))
    for j in range(len(rings) - 1):
        for i in range(segments):
            a = j * segments + i
            b = j * segments + (i + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(rings) - 1) * segments + i for i in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons: poly.use_smooth = True
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Resolve topology normals consistently before exporting to Godot Y-up.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(MODELS / (name + '.glb')), export_format='GLB', use_selection=True, export_yup=True)
    obj.select_set(False)
    return obj

tailored('golfer_polo', [(-.38,.225,.155,0),(-.34,.24,.165,0),(-.17,.245,.175,0),(.06,.29,.185,0),(.21,.33,.18,0),(.30,.315,.155,0),(.36,.20,.115,0),(.38,.115,.09,0)])
tailored('golfer_pelvis', [(-.17,.21,.145,0),(-.12,.25,.16,0),(.08,.27,.17,0),(.17,.235,.155,0)])
tailored('golfer_shoe', [(-.075,.095,.205,0),(-.045,.102,.22,-.015),(.00,.10,.22,-.015),(.065,.09,.155,.015),(.12,.067,.085,.065)])
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'golfer_tailoring.blend'))
print('GOLFER_ASSETS_COMPLETE')
