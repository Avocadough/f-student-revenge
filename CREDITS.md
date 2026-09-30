# Credits and licenses

**การล้างแค้นของนักศึกษาติด F — demo 0.3, 1 October 2026.** This project adapts open-source foundations and downloaded assets for **CP410844 Group 3**. Its cooperative demon campaign, campus environments, support/objective systems and asset modifications were produced for this coursework project. The project MIT license does not replace third-party notices.

## Game foundations

| Source | Adaptation | License / notice |
| --- | --- | --- |
| Local 3D-lab1 project, descended from [Silver Demon Studios 3D Platformer Kit](https://github.com/SilverDemons-PK/3D-Platformer-Kit) | Menu/modal flow, pause/restart behaviour and scene lifecycle | MIT — [preserved notice](ThirdParty/SilverDemonStudios-LICENSE.txt) |
| [Jeh3no Godot Third Person Controller](https://github.com/Jeh3no/Godot-Third-Person-Controller/tree/502805705c3a57580a3cc3919ad0dce25328ab22) | Camera-relative acceleration, model rotation and camera/SpringArm approach | MIT — [preserved notice](ThirdParty/Jeh3no-LICENSE.txt) |

The Jeh3no source revision is `502805705c3a57580a3cc3919ad0dce25328ab22`. The local menu reference remains in [ThirdParty/3D-lab1-menu-reference.gd.txt](ThirdParty/3D-lab1-menu-reference.gd.txt). The current game does not include the older project's zombie model or medieval village environment.

## Models and animation

| Creator | Source | Use | Received license |
| --- | --- | --- | --- |
| Quaternius | [Universal Base Characters Standard](https://quaternius.itch.io/universal-base-characters) | Humanoid foundation, heads, eyes, eyebrows and hair | CC0 1.0 |
| Quaternius | [Modular Character Outfits Fantasy Standard](https://quaternius.itch.io/modular-character-outfits-fantasy) | Shared humanoid rig and earlier clothing foundation | CC0 1.0 |
| Quaternius / Gonzalo Furnier | [Universal Animation Library Standard](https://quaternius.itch.io/universal-animation-library) | Locomotion, punches, hit reactions and death | CC0 1.0 |
| Quaternius | [Universal Animation Library 2 Standard](https://quaternius.itch.io/universal-animation-library-2) | Hook, throw, folded arms and knockback | CC0 1.0 |
| Kenney | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Classroom furniture, books and computer equipment | CC0 1.0 |

These existing free Standard downloads were obtained on 23 September 2026. Their received license notices are preserved in [Assets/Licenses/](Assets/Licenses/); this statement concerns those source files, not a claim about the terms of every current or future publisher release. The editable `.blend` files are this project's adapted working files, not the publishers' paid Source tier.

The 0.3 rebuild gives the student and three teachers ordinary campus clothing, low shoes, distinct builds, hair and accessories. Six demon models — imp, brute, caster, warden, mirror and archon — adapt the licensed humanoid foundation and retain the existing 18-clip set. Horns, claws, armour, crowns, facial details, surfaces and role silhouettes were authored for this game. No new third-party monster pack was downloaded.

Original custom clips include Guard, Parry, Kick, Sweep and Dodge. Earlier Run/Hook cleanup and its limits are recorded in [Art/motion_qa.json](Art/motion_qa.json); model and animation checks for the rebuild are in [Art/campus_asset_qa.json](Art/campus_asset_qa.json). Paper, pen, pencil, phone and tablet meshes and their fictional screen graphics were created in Blender for this project. No real instructor likeness, social-media video or tutorial recording is included. Researched Poly Pizza models were not successfully downloaded and are not included.

See [Assets/ASSET_CREDITS.md](Assets/ASSET_CREDITS.md) and [asset_manifest.json](Assets/asset_manifest.json) for source associations, modifications, hashes and editable-file paths.

## Environment textures and original visuals

| Publisher / artist | Asset | Included files | License |
| --- | --- | --- | --- |
| Poly Haven / eye-candy.xyz | [Concrete Floor](https://polyhaven.com/a/concrete_floor) | 1K diffuse, OpenGL normal and roughness maps | CC0 1.0 |
| Poly Haven / Amal Kumar | [Painted Plaster Wall](https://polyhaven.com/a/painted_plaster_wall) | 1K diffuse, OpenGL normal and roughness maps | CC0 1.0 |

Exact download URLs, file sizes and SHA-256 values are in [texture_receipt.json](Assets/Textures/texture_receipt.json); the [preserved Poly Haven notice](Assets/Licenses/polyhaven_cc0.txt) records the asset license. Website preview images are not bundled.

Campus architecture, signs, procedural contact shading, corruption forms and the animated portal shader were authored for this game. `Assets/Images/campus_invasion_cover.png` was generated with **OpenAI imagegen** for the menu. It is an illustrative cover, not a gameplay screenshot or third-party CC0 download.

## Audio and font

- **Kenney [Impact Sounds](https://kenney.nl/assets/impact-sounds)** and **[UI Audio](https://kenney.nl/assets/ui-audio)**, CC0 1.0: selected combat impacts, footsteps and menu click. The [audio manifest](Assets/Audio/manifest.json) and original notices preserve their source associations.
- **congusbongus, [Lost in a bad place — horror ambience loop](https://opengameart.org/content/lost-in-a-bad-place-horror-ambience-loop)**, CC0 1.0: included as `campus_ambience.ogg`. The OGG is retained as downloaded; runtime volume and ducking are applied. See [ambience_receipt.json](Assets/Audio/ambience_receipt.json).
- **Project-authored synthesis:** `swing.wav` was generated by the existing seeded-noise audio tool; `warning.wav`, `support.wav` and `seal.wav` are original synthetic effects created for the demon campaign. They are separate from the downloaded ambience and contain no sampled speech or commercial music.
- **Noto Sans Thai**, The Noto Project Authors, SIL Open Font License 1.1: [source project](https://github.com/notofonts/thai), [preserved OFL notice](Assets/Fonts/OFL.txt).

## Tools and inspiration

- **Godot Engine 4.7.2** — game engine, [MIT license](https://godotengine.org/license/).
- **Blender 5.2.2 LTS** — mesh editing, rig/animation work, GLB export and render inspection. Its application license does not replace the licenses of source assets.
- **SIFU** is a reference for readable melee combat, defence and environmental interaction. No SIFU code, models, animation, music or branding is included. This remains an independent educational demo.
