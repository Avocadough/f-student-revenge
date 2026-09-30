"""Rebuild campus humans and six original demons on the existing licensed rig.

The archived 2026-09-23 Blender files provide the unchanged 18 actions/skeleton.
New cloth, trousers, shoes, horns, armour and silhouettes are project-authored.
"""
import bpy, math, json, shutil, runpy, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
MODEL=ROOT/'Assets/Models'; ART=ROOT/'Art'; WORK=ROOT/'.work/assets/campus_before'
WORK.mkdir(parents=True,exist_ok=True)
HUMANS=['student','teacher_programming','teacher_ai','teacher_web']
ONLY=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
if not (WORK/'student.blend').exists():
    # Reconstruct the archived foundation on a fresh workstation using the
    # original pipeline and exact licensed source cache before customising it.
    runpy.run_path(str(ROOT/'tools/build_assets_character.py'),run_name='__main__')
for name in HUMANS:
    for folder,ext in [(ART,'.blend'),(MODEL,'.glb')]:
        dest=WORK/(name+ext)
        if not dest.exists():shutil.copy2(folder/(name+ext),dest)

def mat(name,col,rough=.75,metal=0,emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if emission:p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=emission
    return m

def bind(o,bone):
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.parent=rig;g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Preserved CampusRig','ARMATURE');mod.object=rig
    for p in o.data.polygons:p.use_smooth=True
    return o

def sphere(name,pos,scale,m,bone='Head',segments=16,rings=10):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m);return bind(o,bone)

def spike(name,points,radii,m,bone='Head',count=10):
    # Each ring follows the local curve tangent, giving rounded swept horns.
    verts=[];faces=[]
    for j,(pt,r) in enumerate(zip(points,radii)):
        p=Vector(pt);t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized()
        u=t.cross(Vector((0,1,0))).normalized()
        if u.length<.1:u=t.cross(Vector((1,0,0))).normalized()
        v=t.cross(u).normalized()
        for i in range(count):a=2*math.pi*i/count;verts.append(p+r*(math.cos(a)*u+math.sin(a)*v))
    for j in range(len(points)-1):
        for i in range(count):a=j*count+i;b=j*count+(i+1)%count;faces.append((a,b,b+count,a+count))
    faces.extend([tuple(reversed(range(count))),tuple((len(points)-1)*count+i for i in range(count))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(m)
    return bind(o,bone)

def delete(names):
    for o in list(bpy.data.objects):
        if o.type=='MESH' and any(o.name.startswith(n) for n in names):bpy.data.objects.remove(o,do_unlink=True)

def load_baseline(name):
    global rig
    bpy.ops.wm.open_mainfile(filepath=str(WORK/(name+'.blend')))
    bpy.context.preferences.filepaths.save_version=0
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.data.pose_position='REST'
    return rig

def continuous_body(palette,bulk=1,monster=False):
    """Use the source's single continuous skinned body, preserving bone transforms."""
    delete(['Male_Peasant','StudentHead'])
    before=set(bpy.data.objects)
    source=next((ROOT/'.work/assets/base').rglob('Superhero_Male_FullBody.gltf'))
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported=set(bpy.data.objects)-before
    source_rig=next(o for o in imported if o.type=='ARMATURE')
    body=next(o for o in imported if o.type=='MESH' and o.name.lower().startswith('superhero'))
    # Source uses the same named bone family, but its shoulder bind positions
    # differ from the outfit rig. Adapt mesh rest vertices, never animation data.
    transforms={}
    for group in body.vertex_groups:
        source_bone=source_rig.data.bones.get(group.name);target_bone=rig.data.bones.get(group.name)
        assert source_bone is not None and target_bone is not None,(group.name,'missing bone')
        transforms[group.index]=target_bone.matrix_local@source_bone.matrix_local.inverted()
    for v in body.data.vertices:
        position=Vector();weight=0
        for g in v.groups:
            if g.weight>0:position+=(transforms[g.group]@v.co)*g.weight;weight+=g.weight
        if weight>0:v.co=position/weight
    body.name='Torso';body.parent=rig
    for mod in body.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    for o in imported:
        if o!=body:bpy.data.objects.remove(o,do_unlink=True)
    if not monster:
        # Cut actual garment boundaries so material edges cannot zig-zag across
        # the original character's triangles. Bisect interpolates skin weights.
        import bmesh
        bm=bmesh.new();bm.from_mesh(body.data)
        for co,no in [((0,0,1.005),(0,0,1)),((0,0,1.585),(0,0,1)),((0,0,.13),(0,0,1)),((.50,0,0),(1,0,0)),((-.50,0,0),(1,0,0))]:
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=co,plane_no=no,clear_inner=False,clear_outer=False)
        bm.to_mesh(body.data);bm.free();body.data.update()
    body.data.materials.clear()
    for m in palette:body.data.materials.append(m)
    original={v.index:v.co.copy() for v in body.data.vertices}
    for v in body.data.vertices:
        x,y,z=v.co;s=1 if x>=0 else -1
        if monster:
            # Continuous organic shape, with role-specific torso/arm mass.
            if .90<z<1.52 and abs(x)<.24:
                weight=max(0,1-abs(z-1.24)/.40)
                v.co.x*=1+(bulk-1)*weight
                v.co.y=.035+(y-.035)*(1+(bulk-1)*weight)
            if abs(x)>.23 and 1.34<z<1.57:
                muscle=max(.72,min(1.38,bulk))
                v.co.y=.065+(y-.065)*muscle;v.co.z=1.4555+(z-1.4555)*muscle
            if .14<z<.85:
                v.co.x=s*.0906+(x-s*.0906)*max(.68,min(1.35,bulk))
                v.co.y=.05+(y-.05)*max(.68,min(1.3,bulk))
            if z>1.60:
                v.co.x*=.91 if bulk<1 else 1.09
                v.co.y=.015+(y-.015)*1.15
            if z<.15:v.co.y=.06+(y-.06)*1.16
        else:
            # Smooth the superhero body into a modest clothed silhouette.
            if .99<z<1.48 and abs(x)<.18:
                amount=min(1,(z-.99)/.13)*min(1,(1.48-z)/.08)
                v.co.x*=1+(bulk-1)*amount
                # Shirt has room through abdomen without an exaggerated six-pack.
                if y<.035:v.co.y=y-.015*amount
            if .15<z<.82:
                center=Vector((s*.0906,.036+.045*max(0,(.54-z)/.44),z))
                d=v.co-center;radius=math.hypot(d.x,d.y)
                desired=.058+.038*max(0,min(1,(z-.15)/.65))
                if radius>.005:v.co=center+d*(.25+.75*desired/radius)
            if abs(x)>.22 and 1.33<z<1.58:
                v.co.y=.065+(y-.065)*.86;v.co.z=1.4555+(z-1.4555)*.86
            if z>1.61:v.co.x*=.94
            if z<.13:
                v.co.x=s*.0906+(x-s*.0906)*1.10
                v.co.y=.06+(y-.06)*1.06
        # The continuous skin is never moved away from its ankle/hip/shoulder.
    for p in body.data.polygons:
        c=sum((original[i] for i in p.vertices),Vector())/len(p.vertices)
        if monster:p.material_index=0
        elif c.z<.13:p.material_index=2
        elif c.z<1.005:p.material_index=2
        elif c.z<1.585 and abs(c.x)<.50:p.material_index=1
        else:p.material_index=0
        p.use_smooth=True
    if monster:
        # Mottling is baked as vertex colour, not a Blender-only procedural shader.
        colors=body.data.color_attributes.new(name='HidePatina',type='FLOAT_COLOR',domain='CORNER')
        for loop in body.data.loops:
            p=body.data.vertices[loop.vertex_index].co
            noise=(math.sin(p.x*51+p.z*29)*math.sin(p.y*67-p.z*21)+1)*.5
            value=.48+.48*noise
            colors.data[loop.index].color=(value,value*.94,value*.90,1)
    return body

def consolidate(palette):
    # Collapse source materials to a maximum of six deliberate surfaces.
    use_patina=any(o.type=='MESH' and 'HidePatina' in o.data.color_attributes for o in bpy.data.objects)
    for o in bpy.data.objects:
        if o.type!='MESH':continue
        if use_patina and 'HidePatina' not in o.data.color_attributes:
            colors=o.data.color_attributes.new(name='HidePatina',type='FLOAT_COLOR',domain='CORNER')
            for c in colors.data:c.color=(1,1,1,1)
        for i,m in enumerate(o.data.materials):
            if m in palette:continue
            low=m.name.lower() if m else ''
            if 'skin' in low:o.data.materials[i]=palette[0]
            elif any(v in low for v in ['cotton','card paper','sole']):o.data.materials[i]=palette[1]
            elif any(v in low for v in ['trouser','sneaker','buckle']):o.data.materials[i]=palette[2]
            elif 'burgundy' in low:o.data.materials[i]=palette[4]
            else:o.data.materials[i]=palette[3]
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in meshes if o.name=='Torso')
    bpy.ops.object.join();merged=bpy.context.object;merged.name='CampusBody'
    old=list(merged.data.materials);unique=[]
    for m in old:
        if m not in unique:unique.append(m)
    indices=[unique.index(old[p.material_index]) for p in merged.data.polygons]
    merged.data.materials.clear()
    for m in unique:merged.data.materials.append(m)
    for p,i in zip(merged.data.polygons,indices):p.material_index=i
    assert len(unique)<=6, [m.name for m in unique]
    return merged

records=[]
def export(name,palette,notes):
    merged=consolidate(palette);rig.data.pose_position='POSE'
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=rig
    staging=ROOT/'.work/assets/campus_exports';staging.mkdir(parents=True,exist_ok=True)
    staged=(staging/(name+'.glb')).resolve();target=(MODEL/(name+'.glb')).resolve()
    assert staged.parent==staging.resolve() and target.parent==MODEL.resolve()
    bpy.ops.export_scene.gltf(filepath=str(staged),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_nla_strips=True,export_anim_single_armature=True,export_skins=True,export_yup=True,export_force_sampling=True,export_frame_range=False,export_optimize_animation_size=True,export_extras=True,export_vertex_color='NAME' if name.startswith('demon_') else 'NONE',export_vertex_color_name='HidePatina',export_all_vertex_colors=False)
    staged.replace(target)
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/(name+'.blend')),compress=True)
    records.append({'name':name,'surfaces':len(merged.data.materials),'mesh_vertices':len(merged.data.vertices),'modifications':notes})
    print('CAMPUS_READY',name,flush=True)

human_specs=[('student',(.79,.79,.71),(.019,.018,.014),(.49,.021,.03),.96),('teacher_programming',(.22,.36,.38),(.19,.18,.16),(.52,.26,.06),1.02),('teacher_ai',(.53,.49,.37),(.045,.037,.03),(.025,.16,.23),1.13),('teacher_web',(.13,.15,.21),(.025,.023,.035),(.16,.46,.48),.91)]
for name,shirtcol,haircol,accentcol,body in human_specs:
    if ONLY and name not in ONLY:continue
    load_baseline(name)
    skin=mat('Campus skin',(.48,.285,.18));shirt=mat('Woven campus cloth',shirtcol,.9)
    pants=mat('Charcoal twill',(.022,.028,.032),.87);hair=mat('Hair and frames',haircol,.78)
    accent=mat('Faculty identity',accentcol,.68);eyes=mat('Eyes',(.025,.019,.012),.28)
    continuous_body([skin,shirt,pants],body)
    for side in ['l','r']:
        s=1 if side=='l' else -1
        sphere('Campus loafer '+side,(s*.0906,-.022,.059),(.073,.152,.060),pants,'foot_'+side)
        sphere('Loafer sole '+side,(s*.0906,-.022,.015),(.074,.153,.012),pants,'foot_'+side)
    # De-emphasise the superhero jaw and brows without touching rig/action data.
    for o in bpy.data.objects:
        if o.type!='MESH':continue
        if o.name.startswith('StudentHead'):
            for v in o.data.vertices:
                v.co.x*=.93
                if v.co.z<1.61:v.co.x*=.85
        if o.name=='Eyebrows':
            for v in o.data.vertices:v.co.z=1.710+(v.co.z-1.710)*.6
        if o.name=='CampusHair':
            for v in o.data.vertices:
                if name=='teacher_programming':v.co.z=1.76+(v.co.z-1.76)*.70
                elif name=='teacher_web':v.co.x*=1.05;v.co.y*=1.04;v.co.z+=.007
                elif name=='student':v.co.x*=1.025;v.co.y*=1.025;v.co.z+=.004
                else:v.co.x*=1.1
        if o.name.startswith('Shirt collar'):o.location.z+=.050;o.location.y+=.015
    if name=='teacher_programming':
        # Receding hairline: remove forward fringes, retain side/back hair.
        import bmesh
        o=bpy.data.objects.get('CampusHair');bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.y<.005 and v.co.z>1.735],context='VERTS');bm.to_mesh(o.data);bm.free()
        sphere('Grey moustache',(0,-.103,1.657),(.040,.008,.008),hair)
    if name=='teacher_ai':
        spike('Faculty tie',[(0,-.105,1.475),(0,-.110,1.30),(0,-.110,1.18)],[.022,.026,.004],accent,'spine_03',6)
    if name=='teacher_web':
        sphere('Short beard',(0,-.083,1.634),(.053,.028,.020),hair)
    for o in bpy.data.objects:
        if o.type=='MESH' and o.name=='Eyes':o.data.materials.clear();o.data.materials.append(eyes)
    export(name,[skin,shirt,pants,hair,accent,eyes],'Continuous CC0 full body adapted to the existing rig bind pose using skin weights. Smoothed campus cloth, ordinary trousers/shoes and distinct faculty build/hair/accessories replace fantasy silhouette; consolidated <=6 materials. Existing skeleton and all 18 actions retained.')

demon_specs={
    'demon_imp':((.17,.07,.045),(.07,.025,.022),(.78,.12,.015),(.30,.21,.11),.83),
    'demon_brute':((.18,.19,.13),(.045,.055,.05),(.79,.25,.025),(.33,.32,.23),1.40),
    'demon_caster':((.105,.065,.16),(.045,.025,.07),(.55,.13,.90),(.35,.29,.45),.83),
    'demon_warden':((.16,.13,.12),(.075,.085,.088),(.96,.15,.025),(.33,.29,.21),1.35),
    'demon_mirror':((.055,.12,.17),(.16,.25,.31),(.05,.81,.95),(.48,.58,.66),.96),
    'demon_archon':((.15,.055,.10),(.09,.075,.09),(.72,.11,.90),(.50,.36,.14),1.32),
}
for name,(skincol,darkcol,glowcol,bonecol,bulk) in demon_specs.items():
    if ONLY and name not in ONLY:continue
    load_baseline('student')
    delete(['CampusHair','Eyebrows','Eyes','Chest pocket','Shirt button','Shirt collar','Student identity','ID ','Lanyard'])
    skin=mat('Demon hide',tuple(c*.32 for c in skincol),.68);armour=mat('Obsidian shell',tuple(c*.35 for c in darkcol),.44,.45 if name=='demon_mirror' else .1)
    horn=mat('Ancient horn',bonecol,.44,.5 if name=='demon_mirror' else 0)
    ink=mat('Mouth abyss',(.008,.009,.012),.9);glow=mat('Rift core',glowcol,.34,0,2.3)
    body=continuous_body([skin],bulk,True)
    # A stretched face with deep eye sockets and an asymmetrical mouth plate.
    # Angular skull plate rather than a rounded comic-book mask.
    vertices=[(-.057,-.099,1.758),(.057,-.099,1.758),(-.074,-.118,1.692),(.074,-.118,1.692),(-.038,-.124,1.628),(.038,-.124,1.628),(0,-.155,1.690),(0,-.126,1.758),(0,-.141,1.635)]
    faces=[(0,7,6,2),(7,1,3,6),(2,6,8,4),(6,3,5,8),(4,8,5)]
    mesh=bpy.data.meshes.new('Carved skull');mesh.from_pydata(vertices,[],faces);mesh.update()
    mask=bpy.data.objects.new('Carved skull',mesh);bpy.context.collection.objects.link(mask);mask.data.materials.append(horn);bind(mask,'Head')
    for p in mask.data.polygons:p.use_smooth=False
    for s in [-1,1]:
        sphere('Eye socket',(s*.036,-.13,1.713),(.027,.012,.014),ink)
        sphere('Burning eye',(s*.036,-.141,1.713),(.019,.006,.0045),glow)
        rise=.30 if name in ['demon_caster','demon_archon'] else .17
        spread=.17 if name in ['demon_brute','demon_warden'] else .12
        spike('Swept temple horn',[(s*.069,.025,1.765),(s*spread,.035,1.85),(s*(spread+.02),.075,1.84+rise),(s*(spread-.015),.06,1.90+rise)],[.042,.029,.015,0],horn)
        # Cheek tusks and three pronounced hand talons.
        spike('Cheek tusk',[(s*.052,-.11,1.63),(s*.065,-.15,1.65),(s*.063,-.166,1.69)],[.019,.010,0],horn)
        side='l' if s>0 else 'r'
        for j in range(3):
            y=.035+j*.034
            spike('Hand talon',[(s*.78,y,1.455),(s*.86,y-.008,1.443),(s*.93,y-.02,1.416)],[.013,.010,0],horn,'hand_'+side)
        for toe in range(3):
            x=s*.0906+(toe-1)*.026
            spike('Foot claw',[(x,-.095,.028),(x,-.175,.026),(x,-.213,.012)],[.014,.010,0],horn,'foot_'+side)
    for j in range(3):
        spike('Rift scar',[(-.07+j*.03,-.122,1.36),(-.04+j*.03,-.127,1.30),(-.01+j*.03,-.121,1.24)],[.0035,.0045,.0005],glow,'spine_03',5)
    if name in ['demon_brute','demon_warden','demon_archon']:
        for s in [-1,1]:
            sphere('Shoulder carapace',(s*.247,.065,1.483),(.12,.115,.105),armour,'upperarm_'+('l' if s>0 else 'r'))
            for j in range(3):spike('Shoulder thorn',[(s*(.19+j*.047),.067,1.54),(s*(.21+j*.060),.075,1.64+j*.025)],[.023,0],horn,'upperarm_'+('l' if s>0 else 'r'))
        for s in [-1,1]:
            for j in range(3):spike('Rib armour',[(s*.025,-.126,1.39-j*.055),(s*.12,-.114,1.37-j*.055),(s*.21,.01,1.34-j*.055)],[.015,.020,.004],armour,'spine_03')
    if name=='demon_caster':
        for s in [-1,1]:
            spike('Arcane shoulder crest',[(s*.17,.09,1.45),(s*.23,.12,1.65),(s*.14,.14,1.79)],[.04,.025,0],armour,'spine_03')
        # A floating ring is rigidly linked to the spine, not a new animation rig.
        for j in range(12):
            a=j*2*math.pi/12;sphere('Rune bead',(.31*math.cos(a),.15,1.45+.31*math.sin(a)),(.012,.012,.028),glow,'spine_03',8,6)
    if name=='demon_warden':
        for x in [-.056,-.028,0,.028,.056]:spike('Helmet grille',[(x,-.135,1.645),(x,-.14,1.75)],[.007,.007],armour,'Head',6)
    if name=='demon_mirror':
        for s in [-1,1]:
            for j in range(3):spike('Mirror crystal',[(s*.19,.10,1.38+j*.07),(s*(.34+j*.025),.12,1.47+j*.10)],[.04,0],horn,'spine_03',4)
        sphere('Faceted mirror mask',(0,-.125,1.685),(.04,.022,.06),horn,'Head',8,6)
    if name=='demon_archon':
        for j in range(5):
            x=(j-2)*.041;spike('Five point crown',[(x,.02,1.785),(x*1.45,.024,2.00-abs(j-2)*.025)],[.021,0],horn)
        for s in [-1,1]:
            for j in range(4):
                spike('Ribbed wing',[(s*.14,.15,1.27+j*.07),(s*.40,.19,1.43+j*.12),(s*(.53+j*.03),.20,1.39+j*.18)],[.035,.02,0],horn,'spine_03')
    export(name,[skin,armour,horn,ink,glow],f'Continuous CC0 full-body foundation fitted to existing rig rest pose; project-authored {name} deformation, mottled hide, angular skull, swept horns, claws, scars and role-specific armour/crystals/crown. Existing 18 actions unchanged; no new external monster source.')

receipt_path=ROOT/'.work/assets/campus_character_receipt.json'
if ONLY and receipt_path.exists():
    previous={r['name']:r for r in json.loads(receipt_path.read_text())['assets']}
    previous.update({r['name']:r for r in records});records=list(previous.values())
receipt_path.write_text(json.dumps({'build_date':'2026-10-01','blender':bpy.app.version_string,'assets':records},indent=2),encoding='utf8')
