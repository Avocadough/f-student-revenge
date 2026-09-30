# Render quality verification

The existing quality setting now controls rendering work while physics remains 60 Hz and encounters retain their original enemy counts, attacks, markers and objectives.

- Standard: active-room lighting plus one main fill light in each visible neighboring room; up to 12 impact emitters with 7 particles each.
- Low: one main fill per visible room; up to 6 active impact emitters with 4 particles each. The preallocated 12-node pool is reused across menus/stages; idle extra emitters are disabled.
- Root game integration caps rendering at 60 FPS and budgets the physical 3D render target to 1280×720 standard / 960×540 low. Standard uses 2× MSAA and shadows; low disables both. UI remains separately scaled.
- Existing neighboring geometry remains visible. Hidden regions already hid their child lights; the change reduces unnecessary accent lighting in visible neighboring rooms, rather than fixing a detached-light leak.

The physical target matters: in the native 1920×1080 window check on this desktop, DPI scaling produced a 2880×1620 viewport texture while the logical UI rectangle stayed 1280×720. The corrected integration used scales 0.4444 / 0.3333, producing the intended 720p / 540p 3D budgets.

## Evidence

- `render_quality_checks_headless.json`, `render_quality_checks_native.json`: 14/14 integrated checks each. Covers both window sizes, both quality settings, actual stage/FX wiring, antialiasing, 60 FPS cap, unchanged 60 Hz physics, FX expiry in menus, and bounded pool reuse on a new stage.
- `quality_resource_audit.json`: 27 successful standard→low→standard snapshots across all nine checkpoints; mission/spawn/exit markers unchanged. In stage 2 room 2, seven room lights exist, with four visible in standard and three in low. Particle budget changes 84→24→84.
- `quality_motion_regressions.log`: existing motion/FX regressions 14/14.
- `quality_baseline.png`, `quality_current_1.png`, `quality_current_0.png`: rendered samples. Low visibly trades antialiasing and shadow detail for lower rendering work; actors, mission device and HUD remain readable.

## Bounded native performance fixture

Godot 4.7.2 GL Compatibility, NVIDIA GeForce RTX 5060 Ti, 1280×720 window. Stage 2 room 2, four normal enemy AIs, player moved left/right with normal input, no attacks. Player invulnerability is used only to keep the performance fixture alive. Two-second warmup and approximately 12 seconds of real `frame_post_draw` intervals per sample. This is not a gameplay completion or browser benchmark.

| Run | FPS cap | Effective 3D | Mean FPS | p95 frame ms | Median draw calls | Nodes |
|---|---:|---|---:|---:|---:|---:|
| Original final PCK | 120 diagnostic | 1280×720 | 120.22 | 9.199 | 301 | 554 |
| New standard | 120 diagnostic | 1280×720 | 120.22 | 9.002 | 301 | 494 |
| New low | 120 diagnostic | 960×540 | 120.09 | 9.137 | 148 | 494 |
| New standard, shipping settings | 60 actual | 1280×720 | 60.23 | 17.731 | 301 | 494 |

See `quality_baseline_performance.json`, `quality_current_1_performance.json`, `quality_current_0_performance.json`, and `quality_shipping_1_performance.json` with corresponding logs. Baseline resource pack SHA-256: `29aca469b3f7c52209be3c2c3b4b920a5e8024018bcf480b2754960e8e347a97`.

Low reduced measured draw calls by 50.8% and its 3D pixel budget by 43.75%. FPS was cap-limited in all three diagnostic samples, so these results do not establish an uncapped FPS increase. This machine has a strong GPU; ordinary-PC minimum specifications and browser performance are not established by these native samples. Final compact UI text polishing was separate from the diagnostic samples; the physical-target fix and shipping-cap sample were checked afterward.
