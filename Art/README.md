# Editable Blender work

Each `.blend` is an editable source for the matching `Assets/Models/*.glb`. Characters share the Quaternius humanoid skeleton and contain the full 18-clip animation set. Open the Action Editor to select a clip. Character materials are different between student, programming lecturer, AI lecturer and Web App lecturer. Run and Hook have a bounded three-sample motion cleanup; `motion_qa.json` records the baseline comparison, and `Previews/` includes contact sheets.

Device files contain an NLA track named `ScreenLoop` for original screen motion. The Godot animation should be set to loop and started explicitly after instantiation.

Rebuild on this workstation, from the project root:

1. `python tools/build_assets_download.py` downloads only free publisher tiers to `.work/assets`.
2. Run Blender in background with `--python tools/build_assets_character.py`.
3. Run Blender with `--python tools/build_assets_props.py`.
4. `python tools/build_assets_manifest.py` refreshes receipts and copied licenses.
5. Render QA with `tools/build_assets_render.py` and `tools/build_assets_gallery.py`.

Export convention: metres, Godot -Z forward, bottom of the object at ground level (humanoid height approximately 1.82m). No paid assets are required.

## Campus demon remake — 2026-10-01

The current four humans replace the fantasy outfit silhouette with newly authored shirts, straight trousers and low shoes. Faculty members have different body builds, hair and accessories. The six `demon_*` files add original horns, claws, face plates, armour, crystals and crowns on the same licensed humanoid foundation. All ten characters use one mesh and no more than six materials.

Use `tools/build_campus_characters.py` with Blender to rebuild the current characters. The first run preserves/reconstructs the original foundation from `tools/build_assets_character.py` and the exact source caches described above; subsequent runs use `.work/assets/campus_before/`. Do not replace this cache with already customised models. Run `python tools/verify_campus_assets.py` to compare every clip name, timestamp and sampled transform with the original exported GLBs and refresh the manifest without replacing existing source-license records. `tools/render_campus_characters.py` renders the exported models to `Art/Previews/campus_humans.png` and `campus_demons.png`.

The two 1K Poly Haven texture sets are fetched by `tools/build_campus_textures.py`. Their map-level URLs, authors, SHA-256 values and license notice are under `Assets/Textures/texture_receipt.json` and `Assets/Licenses/polyhaven_cc0.txt`. The original project assets retain the licenses that accompanied their downloads.

Godot render verification: run the editor's headless `--import` after replacing GLBs, then run the native Compatibility renderer with `--script tools/capture_final_characters.gd`. A runtime-only launch can reuse stale imported meshes. The fixture plays Idle, Run and Hook on all ten actors, captures actual rendered frames, and samples hand-bone motion twice per clip. Results are in `Art/godot_character_render_qa.json` and `Art/Previews/godot_final_*.png`. This checks imported animation rendering; browser performance and full-game behavior require separate QA.
