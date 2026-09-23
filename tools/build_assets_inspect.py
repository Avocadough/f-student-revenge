import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out={}
for label,folder,pattern in [('base','base','Superhero_Male_FullBody.gltf'),('outfit','outfits','Male_Peasant.gltf'),('anim','animations','UAL1_Standard.glb'),('anim2','animations2','UAL2_Standard.glb')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 path=next((ROOT/'.work/assets'/folder).rglob(pattern))
 bpy.ops.import_scene.gltf(filepath=str(path))
 out[label]={'path':str(path),'objects':[{'name':o.name,'type':o.type,'scale':list(o.scale),'rotation':list(o.rotation_euler),'location':list(o.location),'dimensions':list(o.dimensions),'materials':[m.name for m in o.data.materials] if o.type=='MESH' else []} for o in bpy.data.objects], 'actions':[a.name for a in bpy.data.actions], 'bones':{o.name:[b.name for b in o.data.bones] for o in bpy.data.objects if o.type=='ARMATURE'}}
 if label=='outfit':bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.work/assets/outfit_inspect.blend'))
(ROOT/'.work/assets/inspection.json').write_text(json.dumps(out,indent=2),encoding='utf8')
