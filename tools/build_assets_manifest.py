from pathlib import Path
import json,struct,hashlib,shutil
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'.work/assets';ASSET=ROOT/'Assets'
licenses=ASSET/'Licenses';licenses.mkdir(exist_ok=True,parents=True)
sources=[
 {'id':'quaternius_base','title':'Universal Base Characters Standard','author':'Quaternius','url':'https://quaternius.itch.io/universal-base-characters','license':'CC0-1.0','archive':'base.zip','folder':'base','license_file':'License_Standard.txt','used':'Superhero Male head, eyes, eyebrows, SimpleParted hairstyle'},
 {'id':'quaternius_outfits','title':'Modular Character Outfits Fantasy Standard','author':'Quaternius','url':'https://quaternius.itch.io/modular-character-outfits-fantasy','license':'CC0-1.0','archive':'outfits.zip','folder':'outfits','license_file':'License_Standard.txt','used':'Male Peasant body, arms, legs and boots; shared humanoid rig'},
 {'id':'quaternius_ual1','title':'Universal Animation Library Standard','author':'Quaternius and Gonzalo Furnier','url':'https://quaternius.itch.io/universal-animation-library','license':'CC0-1.0','archive':'animations.zip','folder':'animations','license_file':'License.txt','used':'Idle, Walk, Jog, Sprint, Jab, Cross, Hit, Death and Roll'},
 {'id':'quaternius_ual2','title':'Universal Animation Library 2 Standard','author':'Quaternius','url':'https://quaternius.itch.io/universal-animation-library-2','license':'CC0-1.0','archive':'animations2.zip','folder':'animations2','license_file':'License.txt','used':'Hook, Throw, FoldArms and Knockback'},
 {'id':'kenney_furniture','title':'Furniture Kit','author':'Kenney','url':'https://kenney.nl/assets/furniture-kit','license':'CC0-1.0','archive':'furniture.zip','folder':'furniture','license_file':'License.txt','used':'desk, chairDesk, bookcaseClosedWide, pottedPlant, laptop, computerKeyboard, trashcan, books, computerScreen'},
]
for source in sources:
 source['sha256_archive']=hashlib.sha256((WORK/source['archive']).read_bytes()).hexdigest()
 source['license_local']='Assets/Licenses/'+source['id']+'.txt'
 shutil.copyfile(next((WORK/source['folder']).rglob(source['license_file'])),ROOT/source['license_local'])
manifest={'build_date':'2026-09-23','blender_version':'5.2.2 LTS','units':'metres; feet at y=0 in Godot; -Z forward','sources':sources,'assets':[],'limitations':['Stylized humanoids adapted from free Peasant clothing: combat trousers/boots retained rather than photorealistic uniforms.','ScreenLoop is original animated graphic content, not copied social-media or tutorial videos.','Poly Pizza pages were inspected but CDN download timed out; no Poly Pizza assets are included or credited as used.','Free Standard tiers only. No paid or Source tiers downloaded.']}
for model in sorted((ASSET/'Models').glob('*.glb')):
 b=model.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n])
 entry={'path':str(model.relative_to(ROOT)).replace('\\','/'),'source_blend':'Art/'+model.stem+'.blend','bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'mesh_count':len(j.get('meshes',[])),'clips':[a['name'] for a in j.get('animations',[])]}
 if model.stem in ['student','teacher_programming','teacher_ai','teacher_web']:
  entry['sources']=['quaternius_base','quaternius_outfits','quaternius_ual1','quaternius_ual2']
  entry['modifications']='Cut/combined downloaded head and clothing, straightened shirt hem, assigned campus fabric/skin materials, added shirt collar/buttons/pocket/ID lanyard, rigged hairstyle, lecturer glasses, reduced unused data, authored Guard/Parry/Kick/Sweep/Dodge clips, unified engine orientation.'
 else:
  receipt=json.loads((WORK/'props_receipt.json').read_text())
  r=next(x for x in receipt if x['file'].endswith('/'+model.name));entry['source']=r['source'];entry['modifications']=r['modifications']
 manifest['assets'].append(entry)
(ASSET/'asset_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
(ASSET/'ASSET_CREDITS.md').write_text('''# Asset provenance

All downloaded assets below were obtained from their publisher\'s free Standard / CC0 download on 2026-09-23. Source files were imported, edited and exported using **Blender 5.2.2 LTS**. The `.blend` files in `Art` are our edited working files, not the publishers\' paid Source tier.

| Publisher | Pack and source | Use | License |
| --- | --- | --- | --- |
| Quaternius | [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) | Head, eyes, eyebrows, hair | CC0 1.0 |
| Quaternius | [Modular Character Outfits Fantasy](https://quaternius.itch.io/modular-character-outfits-fantasy) | Clothing and humanoid rig | CC0 1.0 |
| Quaternius / Gonzalo Furnier | [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) | Locomotion, punches, hit and death | CC0 1.0 |
| Quaternius | [Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2) | Hook, throw, folded arms, knockback | CC0 1.0 |
| Kenney | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Furniture, books, computer | CC0 1.0 |

Paper, pen, pencil, phone and tablet are original Blender-authored meshes for this project. Device screens contain original fictional short-feed and coding-tutor graphics. The instructor portrait is fictional; no real video, face, logo, audio or social-media material was copied.

Custom animation clips: **Guard, Parry, Kick, Sweep, Dodge**. Device animation: **ScreenLoop**. Lecturer uniforms share the same downloaded rig and clothing geometry with distinct materials and glasses.

The planned Poly Pizza files were **not included** because their CDN download timed out. They must not appear in credits as implemented assets. Raw download archives are kept locally under `.work/assets` and excluded from the source repository; selected edited models, working `.blend` files and licenses are included.

Full per-file hashes, animation names, exact source URLs and modifications are in `asset_manifest.json`. Original license notices are preserved in `Licenses/`.
''',encoding='utf8')
(ROOT/'Art/README.md').write_text('''# Editable Blender work

Each `.blend` is an editable source for the matching `Assets/Models/*.glb`. Characters share the Quaternius humanoid skeleton and contain the full 18-clip animation set. Open the Action Editor to select a clip. Character materials are different between student, programming lecturer, AI lecturer and Web App lecturer.

Device files contain an NLA track named `ScreenLoop` for original screen motion. The Godot animation should be set to loop and started explicitly after instantiation.

Rebuild on this workstation, from the project root:

1. `python tools/build_assets_download.py` downloads only free publisher tiers to `.work/assets`.
2. Run Blender in background with `--python tools/build_assets_character.py`.
3. Run Blender with `--python tools/build_assets_props.py`.
4. `python tools/build_assets_manifest.py` refreshes receipts and copied licenses.
5. Render QA with `tools/build_assets_render.py` and `tools/build_assets_gallery.py`.

Export convention: metres, Godot -Z forward, bottom of the object at ground level (humanoid height approximately 1.82m). No paid assets are required. Character clothes intentionally keep stylized combat trousers/boots after the original fantasy outfit was adapted to the campus theme.
''',encoding='utf8')
print('Wrote manifest for',len(manifest['assets']),'models')
