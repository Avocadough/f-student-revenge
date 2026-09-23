# Credits and licenses

This project adapts existing open-source foundations and downloaded assets. New gameplay, campus scenes, combat rules, UI styling and Blender edits were made for **CP410844 Group 3**. Third-party notices below remain in force; the project's MIT license does not replace their terms.

## Game foundations

| Source | What was adapted | License / notice |
| --- | --- | --- |
| Local `3D-lab1` project, descended from [Silver Demon Studios 3D Platformer Kit](https://github.com/SilverDemons-PK/3D-Platformer-Kit) | Menu/modal flow, pause/restart behavior and scene lifecycle; adapted in `Scripts/game.gd` for this combat demo | MIT — [original notice](ThirdParty/SilverDemonStudios-LICENSE.txt) |
| [Jeh3no Godot Third Person Controller](https://github.com/Jeh3no/Godot-Third-Person-Controller/tree/502805705c3a57580a3cc3919ad0dce25328ab22) | Camera-relative acceleration and model rotation from WalkState/PlayerCharacter, and the CameraHolder/SpringArm approach; adapted in `Scripts/student_player.gd` and `Scripts/camera_rig.gd` | MIT — [original notice](ThirdParty/Jeh3no-LICENSE.txt) |

Jeh3no source revision: **`502805705c3a57580a3cc3919ad0dce25328ab22`**. A copy of the local menu reference is retained at [ThirdParty/3D-lab1-menu-reference.gd.txt](ThirdParty/3D-lab1-menu-reference.gd.txt). The current game does not reuse the previous project's zombie model or medieval village environment.

## Models and animation

| Creator | Source | Use | License |
| --- | --- | --- | --- |
| Quaternius | [Universal Base Characters Standard](https://quaternius.itch.io/universal-base-characters) | Head, eyes, eyebrows and hair | CC0 1.0 |
| Quaternius | [Modular Character Outfits Fantasy Standard](https://quaternius.itch.io/modular-character-outfits-fantasy) | Clothing and shared humanoid skeleton | CC0 1.0 |
| Quaternius / Gonzalo Furnier | [Universal Animation Library Standard](https://quaternius.itch.io/universal-animation-library) | Locomotion, punches, hit reactions and death | CC0 1.0 |
| Quaternius | [Universal Animation Library 2 Standard](https://quaternius.itch.io/universal-animation-library-2) | Hook, throw, folded arms and knockback | CC0 1.0 |
| Kenney | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Desks, chairs, cabinet, plant, bin, books, computer and keyboard | CC0 1.0 |

Only free Standard packs were downloaded. Blender source files in `Art/` are the project's own edited files made from those downloads; they are not the publishers' paid Source packs. Edits include campus shirt details, identity lanyards, lecturer glasses, materials, shirt shape, rigged hair, custom Guard/Parry/Kick/Sweep/Dodge poses and device-screen animation.

Paper, pen, pencil, phone and tablet meshes were authored in Blender for this project. Screen graphics and the fictional coding instructor were created for the game. They contain no copied social-media video, real instructor likeness or third-party audio clip. Poly Pizza pages were researched but their models were not downloaded successfully and are not included.

See [Assets/ASSET_CREDITS.md](Assets/ASSET_CREDITS.md), [per-file provenance and hashes](Assets/asset_manifest.json), and [preserved licenses](Assets/Licenses/).

## Audio and font

- **Kenney [Impact Sounds](https://kenney.nl/assets/impact-sounds)** and **[UI Audio](https://kenney.nl/assets/ui-audio)**, CC0 1.0: selected impacts, footsteps and menu click. Original notices and per-file receipts are in [Assets/Audio/](Assets/Audio/).
- The short `swing.wav` sound is original seeded noise synthesis from `tools/build_audio.py`; it contains no sampled speech or music.
- **Noto Sans Thai**, The Noto Project Authors, SIL Open Font License 1.1: [source project](https://github.com/notofonts/thai), [preserved OFL notice](Assets/Fonts/OFL.txt).

## Tools and inspiration

- **Godot Engine 4.7.2** — game engine, [MIT license](https://godotengine.org/license/).
- **Blender 5.2.2 LTS** — model editing, rig adjustments, animation, GLB export and rendered checks. Blender is a development tool; its application license does not change the licenses of these created assets.
- **SIFU** is a gameplay reference for readable melee combat, defense and environmental interaction. No SIFU code, models, animation, music or branding is included. This is an independent educational demo.
