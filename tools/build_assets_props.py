"""Create campus props by importing CC0 Kenney meshes and editing in Blender."""
import bpy, math, json, shutil, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'.work/assets'
MODEL=ROOT/'Assets/Models'
ART=ROOT/'Art'
FURN=WORK/'furniture/Models/GLTF format'
records=[]
bpy.context.preferences.filepaths.save_version=0

def clear():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.preferences.filepaths.save_version=0
def mat(name,color,metal=0,rough=.65,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 return m
def box(name,loc,dim,m,bevel=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('Manufactured bevel','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def uvball(name,loc,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 for p in o.data.polygons:p.use_smooth=True
 return o
def text(name,body,loc,size,m,align='CENTER'):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.size=size;curve.align_x=align;curve.extrude=.0005;curve.resolution_u=2
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(math.pi/2,0,0);o.data.materials.append(m)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');return bpy.context.object
def rod(name,a,b,r,m):
 mid=(Vector(a)+Vector(b))*.5;delta=Vector(b)-Vector(a)
 bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=delta.length,location=mid);o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(m);return o
def import_mesh(name):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(FURN/(name+'.glb')))
 objects=[o for o in set(bpy.data.objects)-before if o.type=='MESH']
 for o in objects:
  world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
 for o in list(set(bpy.data.objects)-before):
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
 return objects
def bound(objects):
 points=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
 return Vector([min(v[i] for v in points) for i in range(3)]),Vector([max(v[i] for v in points) for i in range(3)])
def normalize(objects,height,offsetz=0):
 lo,hi=bound(objects);factor=height/max(.001,hi.z-lo.z);center=Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))
 for o in objects:o.location=(o.location-center)*factor+Vector((0,0,offsetz));o.scale*=factor
def export(name,source,notes):
 # Blender authoring faces -Y; rotate to +Y, which exports to Godot -Z.
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for o in list(bpy.data.objects):
  if o!=root and o.parent is None:o.parent=root
 root.rotation_euler.z=math.pi
 bpy.ops.object.select_all(action='SELECT')
 bpy.context.scene.render.fps=30
 bpy.ops.export_scene.gltf(filepath=str(MODEL/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_yup=True,export_extras=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(ART/(name+'.blend')),compress=True)
 records.append({'file':'Assets/Models/'+name+'.glb','source':source,'modifications':notes})

def limbs(width=.3):
 rubber=mat('Rubber grip charcoal',(.035,.055,.069),rough=.8);metal=mat('Brushed steel joints',(.19,.23,.25),.55,.35)
 for s in [-1,1]:
  uvball('Rubber foot',(s*width*.54,-.015,.075),(.11,.17,.072),rubber)
  rod('Flexible leg',(s*width*.52,0,.09),(s*width*.52,0,.30),.022,metal)
def eyes(xspan,z,fronty=-.16):
 ivory=mat('Eye white',(.92,.96,.93));ink=mat('Ink black',(.015,.022,.031),rough=.45)
 for s in [-1,1]:
  uvball('Object eye',(s*xspan,fronty,z),(.045,.021,.055),ivory)
  uvball('Object pupil',(s*xspan,fronty-.018,z),(.019,.01,.026),ink)

# Downloaded furniture reused at real classroom dimensions.
for name,src,height in [('desk','desk',.76),('chair','chairDesk',.95),('cabinet','bookcaseClosedWide',1.85),('plant','pottedPlant',1.15),('laptop','laptop',.36),('keyboard','computerKeyboard',.04),('bin','trashcan',.65)]:
 if not (FURN/(src+'.glb')).exists():continue
 clear();objs=import_mesh(src);normalize(objs,height)
 export(name,'Kenney Furniture Kit / '+src,'Imported GLB, resized to campus scale, unified origin and game orientation.')

# Book uses the publisher's sculpted book cluster with our ominous cover and limbs.
clear();objs=import_mesh('books');normalize(objs,.68,.23)
bpy.context.view_layer.update();lo,hi=bound(objs)
for obj in objs:
 obj.scale.x*=.55/(hi.x-lo.x)
navy=mat('Midnight exam cover',(.032,.083,.13));gold=mat('Warm print',(.98,.73,.25));paper=mat('Paper edge',(.85,.84,.73))
box('Exam cover',(0,-.22,.68),(.53,.065,.70),navy,.012)
text('Read before exam','READ BEFORE\nTHE EXAM',(0,-.257,.78),.071,gold)
text('One night edition','ONE NIGHT EDITION',(0,-.258,.49),.031,gold)
text('Edition','1024 pages',(0,-.258,.38),.033,gold)
limbs(.31);export('book','Kenney Furniture Kit / books','Imported book geometry with custom exam cover, typography, walking feet.')

# Paper: curved mesh, printed lines, giant red grade F, bent corner.
clear();paper=mat('Warm white paper',(.88,.87,.79));red=mat('Red grading ink',(.66,.022,.025));grey=mat('Printed ink',(.17,.2,.23))
verts=[];faces=[];w=.60;h=.80
for row in range(7):
 for col in range(5):
  x=(col/4-.5)*w;z=.30+row/6*h;y=.025*math.sin(col/4*math.pi)*math.sin(row/6*math.pi)
  if row==6 and col==4:y+=.08;z-=.06
  verts.append((x,y,z))
for row in range(6):
 for col in range(4):
  i=row*5+col;faces.append((i,i+1,i+6,i+5))
mesh=bpy.data.meshes.new('Bent grade sheet');mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new('Grade sheet',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(paper)
solid=o.modifiers.new('Paper thickness','SOLIDIFY');solid.thickness=.006
text('Giant F','F',(.03,-.045,.58),.32,red)
text('Transcript label','GRADE REPORT',(0,-.033,.995),.035,grey)
for i in range(3):box('Printed rule',(0,-.018,.48-i*.049),(.4,.003,.008),grey,0)
limbs(.3);export('paper','Original Blender-authored campus prop','Curved paper mesh, folded corner, red F grade typography, limbs.')

# Pencil and red pen share a manufacturable six-sided barrel, with distinct tips/caps.
for name in ['pencil','pen']:
 clear();metal=mat('Pen metal',(.55,.59,.62),.75,.25);ink=mat('Graphite',(.018,.024,.03));wood=mat('Pencil cedar',(.72,.48,.26));body=mat('Yellow lacquer' if name=='pencil' else 'Red correction pen',(.95,.55,.035) if name=='pencil' else (.61,.022,.036),.08,.38)
 bpy.ops.mesh.primitive_cylinder_add(vertices=6 if name=='pencil' else 18,radius=.087,depth=.73,location=(0,0,.69));o=bpy.context.object;o.name='Writing barrel';o.data.materials.append(body)
 bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.0,radius2=.087,depth=.20,location=(0,0,.225));bpy.context.object.data.materials.append(wood if name=='pencil' else metal)
 bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=.0,radius2=.032,depth=.08,location=(0,0,.15));bpy.context.object.data.materials.append(ink)
 box('Brand stripe',(0,-.077,.7),(.04,.01,.36),ink,.004)
 if name=='pencil':
  bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.091,depth=.1,location=(0,0,1.1));bpy.context.object.data.materials.append(metal)
  uvball('Pink eraser',(0,0,1.16),(.085,.085,.085),mat('Eraser pink',(.75,.25,.29)))
 else:
  box('Pocket clip',(.09,0,.94),(.045,.035,.35),metal,.015)
  uvball('Red cap',(0,0,1.07),(.09,.09,.07),body)
 eyes(.04,.83,-.094);limbs(.24)
 export(name,'Original Blender-authored campus prop','Faceted manufactured barrel, metal trim, sharpened tip or correction cap, feet.')

def tutorial_screen(w,h,centerz,y):
 screen=mat('Tutorial dark UI',(.016,.025,.05),rough=.4,emit=.25);blue=mat('Code cyan',(.03,.7,.88),emit=.4);white=mat('UI text',(.85,.93,.94),emit=.3);gold=mat('Code yellow',(.96,.68,.22),emit=.25);skin=mat('Tutor warm skin',(.44,.22,.11));hair=mat('Tutor dark hair',(.021,.013,.015));shirt=mat('Tutor blue shirt',(.05,.22,.42))
 box('Screen glass',(0,y,centerz),(w,.014,h),screen,.015)
 # Fictional skilled Indian coding tutor in a picture-in-picture panel.
 cx=-w*.31;cz=centerz+h*.14
 box('Tutor window',(cx,y-.014,cz),(w*.31,.012,h*.43),shirt,.005)
 uvball('Tutor portrait head',(cx,y-.035,cz+.017),(w*.105,.018,h*.13),skin)
 uvball('Tutor portrait hair',(cx,y-.039,cz+h*.11),(w*.11,.02,h*.055),hair)
 uvball('Tutor beard',(cx,y-.054,cz-h*.04),(w*.072,.012,h*.044),hair)
 for x in [cx-w*.035,cx+w*.035]:box('Tutor eye',(x,y-.058,cz+.023),(.012,.004,.008),white,.001)
 text('Tutorial label','CODE TUTORIAL',(0,y-.03,centerz+h*.40),w*.053,white)
 for i,(length,color) in enumerate([(.41,blue),(.33,gold),(.37,white),(.26,blue),(.39,gold)]):
  box('Code line',(w*.19,y-.026,centerz+h*.2-i*h*.087),(w*length,.006,.008),color,.002)
 text('Tutor caption','step by step',(0,y-.03,centerz-h*.29),w*.053,white)
 box('Video progress',(0,y-.027,centerz-h*.42),(w*.89,.008,.011),gold,.003)

def screen_loop():
 for obj in list(bpy.data.objects):
  if obj.name.startswith('Clip dancer'):
   origin=obj.location.copy()
   for frame,dx,dz in [(1,0,0),(10,.025,.02),(20,-.025,.01),(30,0,0)]:
    obj.location=origin+Vector((dx,0,dz));obj.keyframe_insert('location',frame=frame)
  elif obj.name.startswith('Code line') or obj.name.startswith('Video progress'):
   for frame,factor in [(1,.60),(15,1.0),(30,.60)]:
    obj.scale.x=factor;obj.keyframe_insert('scale',frame=frame)
  elif obj.name.startswith('Tutor portrait head') or obj.name.startswith('Tutor beard') or obj.name.startswith('Tutor eye'):
   origin=obj.location.copy()
   for frame,dz in [(1,0),(15,.006),(30,0)]:
    obj.location=origin+Vector((0,0,dz));obj.keyframe_insert('location',frame=frame)
  else:continue
  action=obj.animation_data.action
  action.name='Screen_'+obj.name
  track=obj.animation_data.nla_tracks.new();track.name='ScreenLoop'
  strip=track.strips.new('ScreenLoop',1,action);strip.action_slot=action.slots[0]
  obj.animation_data.action=None
 bpy.context.scene.frame_set(1)

for name,w,h in [('phone',.41,.78),('tablet',.76,.89)]:
 clear();frame=mat('Anodized device frame',(.043,.064,.083),.7,.28);black=mat('Black glass',(.012,.019,.028),.1,.25);white=mat('Screen white',(.88,.95,.98),emit=.45);pink=mat('Short feed pink',(.95,.03,.32),emit=.35);cyan=mat('Short feed cyan',(.025,.77,.82),emit=.4)
 box('Device body',(0,0,.30+h/2),(w,.085,h),frame,.043)
 if name=='phone':
  box('Short video screen',(0,-.049,.30+h/2),(w*.90,.014,h*.90),black,.025)
  text('SHORTS','SHORTS',(0,-.061,.30+h*.86),.056,white)
  box('Vertical clip panel',(0,-.064,.30+h*.51),(w*.71,.012,h*.43),pink,.014)
  # Original abstract dancing mascot, no third-party clip or logo.
  uvball('Clip dancer head',(0,-.081,.30+h*.60),(.065,.018,.065),cyan)
  rod('Clip dancer torso',(0,-.087,.30+h*.52),(0,-.087,.30+h*.40),.025,cyan)
  rod('Clip dancer arm',(-.075,-.087,.30+h*.50),(.075,-.087,.30+h*.54),.014,cyan)
  text('One more clip','ONE MORE?',(0,-.063,.30+h*.18),.044,white)
  text('Like feed','+  99K',(0,-.063,.30+h*.09),.035,cyan)
 else:tutorial_screen(w*.88,h*.86,.30+h/2,-.055)
 box('Camera',(0,-.057,.30+h-.025),(.052,.011,.013),black,.006)
 limbs(w*.6);screen_loop();export(name,'Original Blender-authored campus prop','Beveled device mesh, original animated fictional short feed or coding-tutor screen, feet.')

# Computer uses a real downloaded display and keyboard, adapted with tutorial UI.
clear();objs=import_mesh('computerScreen');normalize(objs,.83,.22)
lo,hi=bound(objs)
tutorial_screen(.70,.44,.78,-.17)
key=import_mesh('computerKeyboard');normalize(key,.04,.27)
for o in key:o.location.y-=.2
limbs(.46);screen_loop();export('computer','Kenney Furniture Kit / computerScreen + computerKeyboard','Scaled and positioned imported meshes; original animated coding-tutor UI; limbs.')

(WORK/'props_receipt.json').write_text(json.dumps(records,indent=2),encoding='utf8')
