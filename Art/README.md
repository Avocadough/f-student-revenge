# Editable Blender work

Each `.blend` is an editable source for the matching `Assets/Models/*.glb`. Characters share the Quaternius humanoid skeleton and contain the full 18-clip animation set. Open the Action Editor to select a clip. Character materials are different between student, programming lecturer, AI lecturer and Web App lecturer.

Device files contain an NLA track named `ScreenLoop` for original screen motion. The Godot animation should be set to loop and started explicitly after instantiation.

Rebuild on this workstation, from the project root:

1. `python tools/build_assets_download.py` downloads only free publisher tiers to `.work/assets`.
2. Run Blender in background with `--python tools/build_assets_character.py`.
3. Run Blender with `--python tools/build_assets_props.py`.
4. `python tools/build_assets_manifest.py` refreshes receipts and copied licenses.
5. Render QA with `tools/build_assets_render.py` and `tools/build_assets_gallery.py`.

Export convention: metres, Godot -Z forward, bottom of the object at ground level (humanoid height approximately 1.82m). No paid assets are required. Character clothes intentionally keep stylized combat trousers/boots after the original fantasy outfit was adapted to the campus theme.
