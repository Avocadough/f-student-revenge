import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(ROOT/'Assets/Models/student.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data_create()
actions={a.name:a for a in bpy.data.actions}
print('ACTIONS',list(actions))
for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
rig.animation_data.action=actions.get('Idle') or next(iter(actions.values()))
rig.animation_data.action_slot=rig.animation_data.action.slots[0]
bpy.context.scene.frame_set(1)
for o in bpy.data.objects:
 if o.name=='Icosphere':o.hide_render=True
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));ground=bpy.context.object
mat=bpy.data.materials.new('ground');mat.diffuse_color=(.08,.10,.13,1);ground.data.materials.append(mat)
bpy.ops.object.camera_add(location=(3.1,4.1,2.1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.92))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.5
bpy.context.scene.camera=cam
for loc,power,size in [((2,4,5),550,4),((-3,1,3),300,3),((0,-3,4),450,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=700;s.render.resolution_y=700;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Studio');s.world.color=(.18,.18,.18)
s.render.filepath=str(ROOT/'.work/assets/student_preview.png');bpy.ops.render.render(write_still=True)
rig.animation_data.action=actions['Jab'];rig.animation_data.action_slot=actions['Jab'].slots[0];s.frame_set(10);s.render.filepath=str(ROOT/'.work/assets/jab_preview.png');bpy.ops.render.render(write_still=True)
for name,frame in [('Kick',11),('Guard',5),('Sweep',13)]:
 rig.animation_data.action=actions[name];rig.animation_data.action_slot=actions[name].slots[0];s.frame_set(frame);s.render.filepath=str(ROOT/'.work/assets'/(name.lower()+'_preview.png'));bpy.ops.render.render(write_still=True)
