import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
for i,name in enumerate(['student','teacher_programming','teacher_ai','teacher_web']):
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'Assets/Models'/f'{name}.glb'))
 imported=set(bpy.data.objects)-old
 rig=next(o for o in imported if o.type=='ARMATURE')
 for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
 # Actions are deduplicated on some imports and suffixed on others.
 action=next(a for a in bpy.data.actions if a.name=='Idle')
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for o in imported:
  if o.parent is None:o.location.x+=(i-1.5)*1.30
bpy.context.scene.frame_set(1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));ground=bpy.context.object
mat=bpy.data.materials.new('ground');mat.diffuse_color=(.04,.06,.085,1);ground.data.materials.append(mat)
bpy.ops.object.camera_add(location=(4.6,9.5,3.8));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.90))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.2;bpy.context.scene.camera=cam
for loc,power,size in [((2,4,7),1100,7),((-4,1,6),700,6),((0,-3,6),900,6)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1400;s.render.resolution_y=680;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Studio');s.world.color=(.10,.10,.10)
s.render.filepath=str(ROOT/'.work/assets/character_gallery.png');bpy.ops.render.render(write_still=True)
