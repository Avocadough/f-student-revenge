"""Render human/demon turn-front galleries directly from the exported GLBs."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Art/Previews';OUT.mkdir(exist_ok=True)
groups={'campus_humans':['student','teacher_programming','teacher_ai','teacher_web'],'campus_demons':['demon_imp','demon_brute','demon_caster','demon_warden','demon_mirror','demon_archon']}
only=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
for label,names in groups.items():
    if only and label not in only:continue
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
    for i,name in enumerate(names):
        old=set(bpy.data.objects);old_actions=set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'Assets/Models'/f'{name}.glb'))
        imported=set(bpy.data.objects)-old
        rig=next(o for o in imported if o.type=='ARMATURE')
        for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
        actions=set(bpy.data.actions)-old_actions
        action=next(a for a in actions if a.name.split('.')[0]=='Idle')
        rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        for o in imported:
            if o.parent is None:o.location.x+=(i-(len(names)-1)/2)*1.40
    bpy.context.scene.frame_set(1)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025))
    mat=bpy.data.materials.new('Slate backdrop');mat.diffuse_color=(.07,.08,.09,1);bpy.context.object.data.materials.append(mat)
    bpy.ops.object.camera_add(location=(3.1,14,4.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=len(names)*1.5;bpy.context.scene.camera=cam
    for loc,power,size in [((3,5,7),1400,7),((-4,2,6),1000,6),((0,-3,6),1300,6)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=1600;s.render.resolution_y=750;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Studio');s.world.color=(.08,.08,.08)
    s.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
    print('GALLERY_READY',label,flush=True)
