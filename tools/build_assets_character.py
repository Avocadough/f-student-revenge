"""Blender authoring pipeline: downloaded CC0 meshes/animations -> campus fighters."""
import bpy, math, bmesh, json
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'.work/assets'
MODEL=ROOT/'Assets/Models'
ART=ROOT/'Art'
bpy.context.preferences.filepaths.save_version=0

def find(folder,name):return str(next((WORK/folder).rglob(name)))
def import_file(path):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=path)
 return list(set(bpy.data.objects)-before)
def material(name,color,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
def bind(obj,rig,bone):
 obj.parent=rig
 g=obj.vertex_groups.new(name=bone);g.add(list(range(len(obj.data.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('Campus skeleton','ARMATURE');mod.object=rig
def cube(name,loc,scale,mat,rig=None,bone='spine_03',bevel=.0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  m=o.modifiers.new('Soft tailored edges','BEVEL');m.width=bevel;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
 o.data.materials.append(mat)
 if rig:bind(o,rig,bone)
 return o
def line(name,points,thickness,mat,rig=None,bone='spine_03'):
 bpy.ops.object.select_all(action='DESELECT')
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=thickness;curve.bevel_resolution=2
 p=curve.splines.new('POLY');p.points.add(len(points)-1)
 for q,co in zip(p.points,points):q.co=(*co,1)
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object
 if rig:bind(o,rig,bone)
 return o
def mesh_bbox(o):
 return [[round(min(v.co[i] for v in o.data.vertices),4),round(max(v.co[i] for v in o.data.vertices),4)] for i in range(3)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.render.fps=30
objs=import_file(find('outfits','Male_Peasant.gltf'))
rig=next(o for o in objs if o.type=='ARMATURE');rig.name='CampusRig'
for o in objs:
 if o.type=='MESH' and (not o.vertex_groups or o.name.startswith('Icosphere')):bpy.data.objects.remove(o,do_unlink=True)
bodyparts=[o for o in bpy.data.objects if o.type=='MESH']
objs=import_file(find('base','Superhero_Male_FullBody.gltf'))
base_rig=next(o for o in objs if o.type=='ARMATURE')
for o in objs:
 if o.type=='MESH':
  if o.name.startswith('Icosphere'):bpy.data.objects.remove(o,do_unlink=True);continue
  if o.name.startswith('SuperHero'):
   bm=bmesh.new();bm.from_mesh(o.data)
   bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<1.485 or abs(v.co.x)>.16],context='VERTS')
   bm.to_mesh(o.data);bm.free();o.name='StudentHead'
  o.parent=rig
  for mod in o.modifiers:
   if mod.type=='ARMATURE':mod.object=rig
bpy.data.objects.remove(base_rig,do_unlink=True)
hair_objs=import_file(find('base','Hair_SimpleParted.gltf'))
for o in hair_objs:
 if o.type=='MESH':
  if o.name.startswith('Icosphere'):bpy.data.objects.remove(o,do_unlink=True);continue
  o.name='CampusHair';o.parent=rig
  # Hair's origin-at-zero export already positions geometry on the original head.
  for mod in list(o.modifiers):o.modifiers.remove(mod)
  o.vertex_groups.clear();bind(o,rig,'Head')
 else:bpy.data.objects.remove(o,do_unlink=True)

skin=material('Warm skin',(0.57,.31,.19),rough=.66)
shirt=material('Student white cotton',(.79,.82,.80),rough=.88)
pants=material('Charcoal uniform trousers',(.026,.034,.045),rough=.85)
shoe=material('Sneaker navy',(.019,.03,.04),rough=.72)
sole=material('Sneaker pale sole',(.72,.74,.70),rough=.8)
hair=material('Black hair',(.018,.013,.012),rough=.64)
eye=material('Eyes',(.075,.052,.027),rough=.3)
white=material('ID card paper',(.91,.93,.9),rough=.76)
red=material('School burgundy',(.54,.023,.041),rough=.65)
metal=material('Buckle',(.21,.23,.25),metal=.7,rough=.3)
for o in list(bpy.data.objects):
 if o.type!='MESH':continue
 if o.name.startswith('Male_Peasant_Arms'):
  for i,m in enumerate(o.data.materials):o.data.materials[i]=skin if 'Regular' in m.name else shirt
 elif o.name.startswith('Male_Peasant_Body'):
  # Flatten the fantasy tunic's ragged lower edge into a straight uniform hem.
  for v in o.data.vertices:
   if v.co.z<1.04:v.co.z=1.04
  o.data.materials.clear();o.data.materials.append(shirt);o.data.materials.append(pants)
  for p in o.data.polygons:
   z=sum(o.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)
   if .94<z<.98:p.material_index=1
 elif o.name.startswith('Male_Peasant_Legs'):
  o.data.materials.clear();o.data.materials.append(pants)
 elif o.name.startswith('Male_Peasant_Feet'):
  o.data.materials.clear();o.data.materials.append(pants);o.data.materials.append(shoe);o.data.materials.append(sole)
  for p in o.data.polygons:
   z=sum(o.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)
   p.material_index=2 if z<.04 else 1 if z<.16 else 0
 elif 'Hair' in o.name or 'Eyebrow' in o.name:
  o.data.materials.clear();o.data.materials.append(hair)
 elif 'Eyes' in o.name:
  # Preserve publisher eye color texture; remove unresolved normal nodes only.
  for mat in o.data.materials:
   for node in list(mat.node_tree.nodes):
    if node.type=='TEX_IMAGE' and node.image and not node.image.has_data:mat.node_tree.nodes.remove(node)
 else:
  o.data.materials.clear();o.data.materials.append(skin)
 for p in o.data.polygons:p.use_smooth=True

# Source faces Blender -Y. Pose root will turn 180 degrees on export for Godot -Z.
line('Lanyard',[(-.065,-.104,1.515),(-.071,-.164,1.375),(.0,-.173,1.285),(.071,-.164,1.375),(.065,-.104,1.515)],.009,red,rig)
cube('Student identity card',(0,-.192,1.267),(.085,.011,.112),white,rig,bevel=.004)
cube('ID photo',(-.022,-.199,1.273),(.026,.003,.031),red,rig)
cube('ID text rule',(.018,-.199,1.29),(.033,.003,.006),pants,rig)
cube('ID text rule2',(.013,-.199,1.274),(.043,.003,.004),pants,rig)
cube('Chest pocket',(.101,-.149,1.363),(.082,.008,.086),shirt,rig,bevel=.006)
for z in [1.42,1.365,1.31,1.255,1.2,1.145]:cube('Shirt button',(0,-.164,z),(.008,.006,.008),pants,rig)
for x,ang in [(-.047,-.38),(.047,.38)]:
 c=cube('Shirt collar',(x,-.113,1.493),(.073,.016,.091),shirt,rig,bevel=.004);c.rotation_euler.y=ang

animations={}
mapping={'Idle_Loop':'Idle','Walk_Loop':'Walk','Jog_Fwd_Loop':'Run','Sprint_Loop':'Sprint','Punch_Jab':'Jab','Punch_Cross':'Cross','Death01':'Death','Hit_Chest':'Hit','Melee_Hook':'Hook','OverhandThrow':'Throw','Idle_FoldArms_Loop':'FoldArms','Hit_Knockback':'Knockback','Roll':'Roll'}
for folder,pattern in [('animations','UAL1_Standard.glb'),('animations2','UAL2_Standard.glb')]:
 prior=set(bpy.data.actions)
 imported=import_file(find(folder,pattern))
 src=next(o for o in imported if o.type=='ARMATURE')
 for a in set(bpy.data.actions)-prior:
  original=a.name.split('.')[0]
  if original in mapping:
   a.use_fake_user=True;a.name=mapping[original];animations[a.name]=a
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)

rig.animation_data_create()

def smooth_source_action(name, loop=False, upper_body_only=False):
 """One symmetric three-sample pass; keep original duration and attack phase.

 The free jog has 60-degree calf changes in one 30-fps frame. Smoothing
 cyclic neighbours softens that step without adding latency or root motion.
 Hook keeps pelvis/leg samples untouched so its foot plants do not deteriorate.
 """
 source=animations[name]
 rig.animation_data.action=source;rig.animation_data.action_slot=source.slots[0]
 start,end=(int(round(v)) for v in source.frame_range)
 frames=list(range(start,end if loop else end+1))
 poses=[]
 for frame in frames:
  bpy.context.scene.frame_set(frame)
  poses.append({b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones})
 filtered=[]
 upper_prefixes=('spine','neck','Head','clavicle','upperarm','lowerarm','hand','index','middle','pinky','ring','thumb')
 for i,pose in enumerate(poses):
  result={}
  for bone,now in pose.items():
   preserve=(not loop and i in [0,len(poses)-1]) or (upper_body_only and not bone.startswith(upper_prefixes))
   if preserve:
    result[bone]=now;continue
   prev=poses[(i-1)%len(poses) if loop else max(0,i-1)][bone]
   nxt=poses[(i+1)%len(poses) if loop else min(len(poses)-1,i+1)][bone]
   q0,q1,q2=prev[1].copy(),now[1].copy(),nxt[1].copy()
   if q0.dot(q1)<0:q0.negate()
   if q2.dot(q1)<0:q2.negate()
   quat=Quaternion(tuple((q0[k]+2*q1[k]+q2[k])*.25 for k in range(4)));quat.normalize()
   result[bone]=((prev[0]+2*now[0]+nxt[0])*.25,quat,now[2])
  filtered.append(result)
 source.name=name+'_unfiltered_source'
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 for frame in range(start,end+1):
  pose=filtered[(frame-start)%len(filtered)]
  for bone in rig.pose.bones:
   loc,quat,scale=pose[bone.name];bone.rotation_mode='QUATERNION';bone.location=loc;bone.rotation_quaternion=quat;bone.scale=scale
   for key in ['location','rotation_quaternion','scale']:bone.keyframe_insert(key,frame=frame)
 animations[name]=action
 bpy.data.actions.remove(source)

smooth_source_action('Run',loop=True)
smooth_source_action('Hook',upper_body_only=True)
rig.animation_data.action=animations['Idle']
rig.animation_data.action_slot=animations['Idle'].slots[0]
bpy.context.scene.frame_set(1)
# Generate additional attack poses using the imported humanoid rig.
neutral={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
def make_action(name,duration,frames):
 rig.animation_data.action=None
 action=bpy.data.actions.new(name);rig.animation_data.action=action;action.use_fake_user=True
 for frame,changes in frames:
  for b in rig.pose.bones:b.matrix_basis=neutral[b.name]
  bpy.context.view_layer.update()
  for bone,change in changes.items():
   pb=rig.pose.bones.get(bone)
   if pb:
    pb.rotation_mode='QUATERNION'
    if isinstance(change,dict) and 'target' in change:
     direction=Vector(change['target'])-pb.head
     delta=(pb.tail-pb.head).normalized().rotation_difference(direction.normalized())
     head=pb.head.copy();pb.matrix=Matrix.Translation(head)@delta.to_matrix().to_4x4()@Matrix.Translation(-head)@pb.matrix
    elif isinstance(change,dict) and 'offset' in change:
     m=pb.matrix.copy();m.translation+=Vector(change['offset']);pb.matrix=m
    else:
     angles=change
     q=Quaternion((1,0,0),math.radians(angles[0]))@Quaternion((0,1,0),math.radians(angles[1]))@Quaternion((0,0,1),math.radians(angles[2]))
     head=pb.head.copy();pb.matrix=Matrix.Translation(head)@q.to_matrix().to_4x4()@Matrix.Translation(-head)@pb.matrix
    bpy.context.view_layer.update()
  for b in rig.pose.bones:
   b.rotation_mode='QUATERNION';b.keyframe_insert('location',frame=frame);b.keyframe_insert('rotation_quaternion',frame=frame);b.keyframe_insert('scale',frame=frame)
 action.use_frame_range=True;action.frame_start=1;action.frame_end=duration
 animations[name]=action
guard={'upperarm_l':{'target':(.24,-.13,1.27)},'lowerarm_l':{'target':(.13,-.20,1.55)},'upperarm_r':{'target':(-.23,-.11,1.28)},'lowerarm_r':{'target':(-.1,-.21,1.53)}}
make_action('Guard',30,[(1,guard),(30,guard)])
make_action('Parry',16,[(1,guard),(5,{**guard,'lowerarm_l':{'target':(.37,-.22,1.53)}}),(10,guard),(16,{})])
make_action('Kick',27,[(1,guard),(6,{**guard,'thigh_r':{'target':(-.13,-.26,1.13)},'calf_r':{'target':(-.13,-.13,.69)}}),(11,{**guard,'thigh_r':{'target':(-.12,-.32,1.07)},'calf_r':{'target':(-.12,-.82,1.02)},'foot_r':{'target':(-.12,-.92,.98)}}),(17,{**guard,'thigh_r':{'target':(-.13,-.26,1.13)},'calf_r':{'target':(-.13,-.13,.69)}}),(27,{})])
make_action('Sweep',29,[(1,guard),(6,{**guard,'thigh_r':{'target':(-.29,-.10,.66)},'calf_r':{'target':(-.4,-.21,.27)}}),(13,{**guard,'thigh_r':{'target':(.23,-.20,.68)},'calf_r':{'target':(.61,-.4,.39)}}),(20,{**guard,'thigh_r':{'target':(.34,-.04,.69)},'calf_r':{'target':(.7,-.01,.31)}}),(29,{})])
make_action('Dodge',18,[(1,guard),(5,{**guard,'pelvis':{'offset':(0,0,-.12)},'spine_03':(13,0,0)}),(12,{**guard,'pelvis':{'offset':(0,0,-.06)},'spine_03':(8,0,0)}),(18,{})])

for a in list(bpy.data.actions):
 if a not in animations.values():bpy.data.actions.remove(a)
rig.animation_data.action=None
for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
for name,a in animations.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 st=track.strips.new(name,1,a);st.action_slot=a.slots[0];track.mute=True
rig.animation_data.action=animations['Idle'];rig.animation_data.action_slot=animations['Idle'].slots[0]
bpy.context.scene.frame_set(1)

# Parent transformation establishes engine-facing orientation without changing skinning.
root=bpy.data.objects.new('CampusFighter',None);bpy.context.collection.objects.link(root)
rig.parent=root;root.rotation_euler.z=math.pi
model_objs=[o for o in bpy.data.objects if o.type in ['MESH','ARMATURE','EMPTY']]
for img in bpy.data.images:
 if img.has_data:
  if img.size[0]>1024 or img.size[1]>1024:img.scale(1024,1024)
  img.pack()
bpy.data.orphans_purge(do_recursive=True)

def export_variant(name,shirt_color,hair_color,accent_color,teacher=False):
 shirt.diffuse_color=(*shirt_color,1);shirt.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*shirt_color,1)
 hair.diffuse_color=(*hair_color,1);hair.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*hair_color,1)
 red.diffuse_color=(*accent_color,1);red.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*accent_color,1)
 extra=[]
 if teacher:
  for s in [-1,1]:
   x=s*.038
   extra.append(line('Lecturer glasses',[(x-.034,-.091,1.714),(x+.034,-.091,1.714),(x+.031,-.096,1.681),(x-.032,-.096,1.681),(x-.034,-.091,1.714)],.0045,pants,rig,'Head'))
  extra.append(line('Glasses bridge',[(-.007,-.094,1.703),(.007,-.094,1.703)],.0045,pants,rig,'Head'))
 bpy.ops.object.select_all(action='DESELECT')
 for o in model_objs+extra:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(MODEL/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_nla_strips=True,export_anim_single_armature=True,export_skins=True,export_yup=True,export_force_sampling=True,export_frame_range=False,export_optimize_animation_size=True,export_extras=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(ART/(name+'.blend')),compress=True)
 for o in extra:bpy.data.objects.remove(o,do_unlink=True)

export_variant('student',(.79,.82,.80),(.018,.013,.012),(.54,.023,.041))
export_variant('teacher_programming',(.40,.55,.58),(.08,.073,.066),(.69,.12,.067),True)
export_variant('teacher_ai',(.69,.68,.56),(.08,.073,.066),(.045,.24,.34),True)
export_variant('teacher_web',(.045,.085,.12),(.018,.018,.022),(.1,.66,.7),True)
(WORK/'character_receipt.json').write_text(json.dumps({'models':[p.name for p in MODEL.glob('*.glb')],'clips':list(animations),'forward':'-Z','height_m':1.82,'downloaded_base':'Quaternius CC0 Male Peasant + Universal Base Superhero Male head','blender_version':bpy.app.version_string,'objects':{o.name:mesh_bbox(o) for o in model_objs if o.type=='MESH'}},indent=2),encoding='utf8')
