import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
for i,name in enumerate(['paper','book','pencil','pen','phone','tablet','computer','desk','chair','cabinet']):
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'Assets/Models'/f'{name}.glb'))
 for o in set(bpy.data.objects)-old:
  if o.parent is None:o.location.x+=(i%5-2)*1.4;o.location.y+=(i//5)*2.0
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));ground=bpy.context.object
mat=bpy.data.materials.new('ground');mat.diffuse_color=(.055,.075,.10,1);ground.data.materials.append(mat)
bpy.ops.object.camera_add(location=(7.5,11,8.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.8,.55))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=9
bpy.context.scene.camera=cam
for loc,power,size in [((2,4,7),1100,7),((-4,1,6),700,6),((0,-3,6),900,6)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1280;s.render.resolution_y=850;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Studio');s.world.color=(.16,.16,.16)
s.render.filepath=str(ROOT/'.work/assets/props_gallery.png');bpy.ops.render.render(write_still=True)
