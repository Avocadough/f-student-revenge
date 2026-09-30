# Asset provenance

All downloaded assets below were obtained from their publisher's free Standard / CC0 download on 2026-09-23. Source files were imported, edited and exported using **Blender 5.2.2 LTS**. The `.blend` files in `Art` are our edited working files, not the publishers' paid Source tier.

| Publisher | Pack and source | Use | License |
| --- | --- | --- | --- |
| Quaternius | [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) | Head, eyes, eyebrows, hair | CC0 1.0 |
| Quaternius | [Modular Character Outfits Fantasy](https://quaternius.itch.io/modular-character-outfits-fantasy) | Clothing and humanoid rig | CC0 1.0 |
| Quaternius / Gonzalo Furnier | [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) | Locomotion, punches, hit and death | CC0 1.0 |
| Quaternius | [Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2) | Hook, throw, folded arms, knockback | CC0 1.0 |
| Kenney | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Furniture, books, computer | CC0 1.0 |

Paper, pen, pencil, phone and tablet are original Blender-authored meshes for this project. Device screens contain original fictional short-feed and coding-tutor graphics. The instructor portrait is fictional; no real video, face, logo, audio or social-media material was copied.

Custom animation clips: **Guard, Parry, Kick, Sweep, Dodge**. Device animation: **ScreenLoop**. Lecturer uniforms share the same downloaded rig and clothing geometry with distinct materials and glasses. The downloaded **Run** clip received one cyclic three-sample smoothing pass; **Hook** received the same pass on upper-body tracks only. Original lengths and Hook impact timing were retained, and Hook pelvis/leg tracks were preserved. See `Art/motion_qa.json` for measured before/after motion and foot-contact checks.

The planned Poly Pizza files were **not included** because their CDN download timed out. They must not appear in credits as implemented assets. Raw download archives are kept locally under `.work/assets` and excluded from the source repository; selected edited models, working `.blend` files and licenses are included.

Full per-file hashes, animation names, exact source URLs and modifications are in `asset_manifest.json`. Original license notices are preserved in `Licenses/`.

## Campus demon remake — 2026-10-01

The four human models now have project-authored campus shirts, straight trousers and low shoes, with different faculty hair, builds and accessories. The six demons (`demon_imp`, `demon_brute`, `demon_caster`, `demon_warden`, `demon_mirror`, `demon_archon`) reuse the existing licensed humanoid foundation and unchanged 18-clip set; their horns, claws, armour, facial details, crowns and silhouettes are original additions for this game. No new third-party monster pack was downloaded. The existing Quaternius CC0 notices are preserved as received, independently of the publisher's current license for new releases.

| Publisher / artist | Source | Use | License |
| --- | --- | --- | --- |
| Poly Haven / eye-candy.xyz | [Concrete Floor](https://polyhaven.com/a/concrete_floor) | 1K diffuse, OpenGL normal and roughness maps | CC0 1.0 |
| Poly Haven / Amal Kumar | [Painted Plaster Wall](https://polyhaven.com/a/painted_plaster_wall) | 1K diffuse, OpenGL normal and roughness maps | CC0 1.0 |

Poly Haven's [license](https://polyhaven.com/license) permits use, modification and redistribution of the assets. The website's preview images are not included. Download URLs and hashes are preserved in `Textures/texture_receipt.json`; verification of mesh surfaces and unchanged motion is in `Art/campus_asset_qa.json`.
