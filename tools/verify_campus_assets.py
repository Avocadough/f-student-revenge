"""Compare all rebuilt clip timing/data to archived GLBs and refresh provenance."""
from pathlib import Path
import json, struct, hashlib
ROOT=Path(__file__).resolve().parents[1]
MODEL=ROOT/'Assets/Models';WORK=ROOT/'.work/assets/campus_before'

def glb(path):
    raw=path.read_bytes();magic,ver,length=struct.unpack_from('<III',raw)
    assert magic==0x46546C67 and ver==2 and length==len(raw)
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n])
    start=20+n;binary=raw[start+8:] if start<len(raw) else b''
    return raw,doc,binary

def values(doc,binary,i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
    components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    stride=v.get('byteStride',components*4)
    return [struct.unpack_from('<'+'f'*components,binary,offset+j*stride) for j in range(a['count'])]

def animation_signature(doc,binary):
    out={}
    for a in doc.get('animations',[]):
        channels={}
        for c in a['channels']:
            s=a['samplers'][c['sampler']];node=doc['nodes'][c['target']['node']].get('name','')
            key=node+'/'+c['target']['path']
            channels[key]={'times':values(doc,binary,s['input']),'values':values(doc,binary,s['output'])}
        out[a['name']]=channels
    return out

receipt=json.loads((ROOT/'.work/assets/campus_character_receipt.json').read_text())
results=[]
for entry in receipt['assets']:
    name=entry['name'];raw,doc,binary=glb(MODEL/(name+'.glb'))
    baseline=name if (WORK/(name+'.glb')).exists() else 'student'
    _,old,oldbinary=glb(WORK/(baseline+'.glb'))
    assert len(doc['skins'])==len(old['skins'])==1
    joints=[doc['nodes'][j]['name'] for j in doc['skins'][0]['joints']]
    old_joints=[old['nodes'][j]['name'] for j in old['skins'][0]['joints']]
    assert joints==old_joints,(name,'joint identity')
    binds=values(doc,binary,doc['skins'][0]['inverseBindMatrices'])
    old_binds=values(old,oldbinary,old['skins'][0]['inverseBindMatrices'])
    bind_delta=max(abs(a-b) for row,oldrow in zip(binds,old_binds) for a,b in zip(row,oldrow))
    assert bind_delta<.00001,(name,'skeleton bind changed',bind_delta)
    actual=animation_signature(doc,binary);expected=animation_signature(old,oldbinary)
    assert set(actual)==set(expected) and len(actual)==18,(name,list(actual))
    worst=0
    for clip in actual:
        assert set(actual[clip])==set(expected[clip]),(name,clip,'channels')
        for target in actual[clip]:
            a=actual[clip][target];e=expected[clip][target]
            assert a['times']==e['times'],(name,clip,target,'timing')
            assert len(a['values'])==len(e['values'])
            error=max(abs(x-y) for av,ev in zip(a['values'],e['values']) for x,y in zip(av,ev))
            worst=max(worst,error)
    assert worst<.00001,(name,'animation delta',worst)
    surfaces=sum(len(m['primitives']) for m in doc['meshes'])
    assert surfaces<=6 and len(doc['meshes'])==1,(name,surfaces)
    if name.startswith('demon_'):
        assert all('COLOR_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),(name,'mottling missing')
    assert all('uri' not in b for b in doc.get('buffers',[]))
    assert all('uri' not in b for b in doc.get('images',[]))
    assert (ROOT/'Art'/(name+'.blend')).exists()
    triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    results.append({'name':name,'mesh_count':len(doc['meshes']),'surfaces':surfaces,'triangles':triangles,'clips':list(actual),'all_clip_times_exact':True,'max_animation_value_delta':worst,'max_skeleton_bind_delta':bind_delta,'joint_count':len(joints),'self_contained':True,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'modifications':entry['modifications']})
qa={'date':'2026-10-01','status':'PASS','checks':['10 GLB headers/buffer embedding/editable Blender sources valid','All 18 clip names and every sampled timestamp match archived original','All sampled animation values preserved within 0.00001','Each rebuilt character is one mesh with at most six surfaces'],'limitations':['Static/export animation verification. Actual gameplay readability, Web frame rate and interaction tests belong to the game QA.'],'results':results}
(ROOT/'Art/campus_asset_qa.json').write_text(json.dumps(qa,indent=2),encoding='utf8')
manifest_path=ROOT/'Assets/asset_manifest.json';manifest=json.loads(manifest_path.read_text())
manifest['updated_date']='2026-10-01'
for source in manifest['sources']:
    if source['id']=='quaternius_base':source['used_in_campus_remake']='Full continuous Superhero Male mesh adapted at mesh bind pose to the existing outfit rig; eyes, eyebrows and hairstyle retained where used.'
    if source['id']=='quaternius_outfits':source['used_in_campus_remake']='Existing campus skeleton and bind pose only. Old fantasy clothing mesh is replaced in the current ten characters.'
manifest['limitations']=[x for x in manifest.get('limitations',[]) if 'combat trousers/boots retained' not in x]
limitation='Campus remake uses deliberately modest real-time humanoid meshes, not photoreal scans. Demon accessories and garments are newly authored on the existing licensed rig.'
if limitation not in manifest['limitations']:manifest['limitations'].append(limitation)
for r in results:
    path='Assets/Models/'+r['name']+'.glb'
    entry=next((a for a in manifest['assets'] if a['path']==path),None)
    if entry is None:entry={'path':path};manifest['assets'].append(entry)
    entry.update({'source_blend':'Art/'+r['name']+'.blend','bytes':r['bytes'],'sha256':r['sha256'],'mesh_count':r['mesh_count'],'surfaces':r['surfaces'],'triangles':r['triangles'],'clips':r['clips'],'sources':['quaternius_base','quaternius_outfits','quaternius_ual1','quaternius_ual2'],'modifications':r['modifications'],'updated_date':'2026-10-01'})
texture_receipt=json.loads((ROOT/'Assets/Textures/texture_receipt.json').read_text())
manifest['textures']=texture_receipt['assets']
manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
print('PASS',len(results),'characters; 18 preserved clips each; <=6 surfaces; provenance updated')
