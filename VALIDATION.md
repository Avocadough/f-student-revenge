# ผลตรวจรุ่น 0.3 — มหาวิทยาลัยถูกปีศาจบุก

ตรวจวันที่ **1 ตุลาคม 2026** ด้วย **Godot 4.7.2 Stable**, Compatibility renderer, Web แบบ single-thread บน Windows / NVIDIA RTX 5060 Ti แยกผลตรวจระบบ การควบคุมอัตโนมัติ การเปิดเว็บ และประสบการณ์ผู้เล่นใหม่ออกจากกัน

## ระบบและการเล่น

| ขอบเขต | หลักฐาน | ผล |
|---|---|---|
| พันธมิตร ภารกิจ จุดเกิด ประตูมิติ | [demon_campaign_checks.json](Verification/v0_3/demon_campaign_checks.json) | 52 checks ผ่าน; อาจารย์ไม่เป็นศัตรู, T ใช้ไม่ได้ขณะพัก/บทพูด, คูลดาวน์คืนเมื่อเริ่ม checkpoint, E ต้องอยู่ในระยะและทำได้ครั้งเดียว |
| ระบบด่าน บอส การปรับตัวและโล่ | [stage_subsystem_checks_v03.json](Verification/v0_3/stage_subsystem_checks_v03.json) | 63 checks ผ่าน |
| การเล่นผ่าน controller | [gameplay_integration_v03.json](Verification/v0_3/gameplay_integration_v03.json) | 28 checks ผ่าน; เดินครบ 9 checkpoint และจบ F → D ในโหมดปกติ |
| God Mode | [god_mode_combat_checks_v03.json](Verification/v0_3/god_mode_combat_checks_v03.json) | 36 checks ผ่าน; ยังต้องทำภารกิจ E และปิดประตูมิติ |
| เมนูและการคงค่า | [menu_persistence_checks.json](Verification/v0_3/menu_persistence_checks.json) | 25 checks ผ่าน |
| ย้ายค่าตั้งค่าและเริ่มเรื่องใหม่ | [save_migration_v03.json](Verification/v0_3/save_migration_v03.json) | 8 checks ผ่าน; เซฟเดิมตรงทุกไบต์, progress_v2.json เก็บความคืบหน้าแยก |
| การเคลื่อนไหว กล้อง และ feedback | [motion_regressions.json](Verification/v0_3/motion_regressions.json) | 14 checks ผ่าน |
| การชนกระสุน/วัตถุ/กำแพง | [stage_collision_checks.json](Verification/v0_3/stage_collision_checks.json) | 12 checks ผ่าน |
| ตั้งค่า God Mode และ UI | [god_mode_ui_checks.json](Verification/v0_3/god_mode_ui_checks.json) | 18 checks ผ่าน |
| ทางสำรองเมื่อเว็บไม่ล็อกเมาส์ | [browser_fallback_checks.json](Verification/v0_3/browser_fallback_checks.json) | 15 checks ผ่าน; headless ไม่ยืนยันว่าเบราว์เซอร์ให้ pointer lock จริง |
| ขนาดหน้าจอ/ภาษาไทย | [ui_layout_checks.json](Verification/v0_3/ui_layout_checks.json) | 17 checks ผ่านที่ 1280×720, 960×540 และ 800×720; ตรวจภาพที่เรนเดอร์ด้วย |
| เสียงใหม่และการหยุดเสียง | [audio_v03.json](Verification/v0_3/audio_v03.json) | 11 checks ผ่าน; โหลดเสียง, ducking, pause/resume, หยุดบรรยากาศเมื่อกลับเมนู และให้เสียงผนึกเล่นจบได้ |

รวม **299 checks** การเดินเกมอัตโนมัติล่าสุดครบเรื่องใน **134.72 วินาทีจำลอง**, retry 0 ใช้ input ตัวละครจริง ไม่ทำความเสียหายโดยตรง ไม่ teleport ไม่แก้ HP และไม่เปิดอมตะในช่วงเดินเรื่อง บอตอ่านสถานะศัตรูได้และกดเมนูด้วยสัญญาณปุ่ม จึงไม่แทนการเล่นด้วยมือ ส่วนกรณีทดสอบรายระบบใช้ fixture จัดตำแหน่งและสถานะตามที่เปิดเผยใน JSON

## งานภาพและแหล่งที่มา

- [QA โมเดล](Art/campus_asset_qa.json): ตัวละคร 10 แบบ หนึ่ง mesh ต่อแบบ 4–6 surfaces และ 18 คลิปต่อแบบ ชื่อ เวลา keyframe ค่าแอนิเมชัน และ skeleton bind เทียบฐานเดิมผ่าน ใช้ร่างกายต่อเนื่องแทนชิ้นทรงกระบอกที่มีรอยแยก ตรวจภาพแอนิเมชัน Idle/Run/Hook ใน Godot ด้วย
- ตรวจฉากเล่นจริงทั้งเก้าโซน ใช้พื้นผิว 1K แสงทิศทาง/แสงเฉพาะจุด หมอกระยะ เงาสัมผัสจากภาพที่เตรียมไว้ และอุปกรณ์ภารกิจที่แยกรูปร่าง ไม่มีระบบ LightmapGI ที่ bake ทั้งฉาก; ฉากสร้างขณะรันและใช้วัสดุร่วมเพื่อลดภาระเว็บ
- ภาพหน้าปกเป็นภาพประกอบสร้างด้วย imagegen ไม่ใช่ภาพกราฟิกขณะเล่น โมเดลมีวัสดุและสัดส่วนจริงขึ้นแต่ยังเป็นงาน stylized สำหรับ realtime ไม่ใช่ photorealistic scan
- ใบอนุญาต แหล่งดาวน์โหลด และ SHA-256 อยู่ใน [เครดิต](CREDITS.md), [asset_manifest.json](Assets/asset_manifest.json), [texture_receipt.json](Assets/Textures/texture_receipt.json) และ [ambience_receipt.json](Assets/Audio/ambience_receipt.json)

## เว็บและประสิทธิภาพ

ไฟล์เผยแพร่จริง `docs/index.pck` ผ่าน [การเล่นจากแพ็ก](Verification/v0_3/release_pack_gameplay.json) ด้วย Godot 4.7.2 native headless: 28/28 checks, ครบ 9 checkpoint จนถึงตอนจบ, retry 0, 141.52 วินาทีจำลอง และไม่มี error/warning ตัวทดสอบทำงานจากโฟลเดอร์ว่างนอกโครงการ มีเพียง runner แล้วโหลด Scenes/Scripts/Assets จาก PCK โดยตรง ผลนี้ยืนยันความครบของไฟล์ส่งออก แต่ไม่แทนการเรนเดอร์บนเว็บ

เปิดหน้าเมนูและด่านแรกบน Chrome/Edge ระหว่างพัฒนาได้ แต่การตรวจชุดสุดท้ายด้วยเครื่องมือควบคุมหน้าจอหยุดเพราะเครื่องมือยืนยัน URL ไม่ได้ จึง **ยังไม่อ้างว่าผ่านการเล่นครบเกมบนเบราว์เซอร์หรือผ่านเกณฑ์ FPS เว็บ** ผู้ใช้ยืนยันขอบเขตเดโมรายวิชาและให้ส่งรุ่นที่เล่นได้บน GitHub Pages โดยไม่เพิ่มระบบอื่น

พบและแก้ปัญหาเสียงบรรยากาศบนเว็บ: การสั่ง unpause ซ้ำทุกเฟรมทำให้ backend ของ Godot สร้างสำเนาเสียงซ้ำ เปลี่ยนเป็นสั่งเมื่อสถานะเปลี่ยนเท่านั้น ตรวจกลไกจาก source รุ่น 4.7.2 และ JS ที่ส่งออกจริง พร้อมทดสอบเสียงซ้ำผ่าน ดู [บันทึกการวิเคราะห์](Verification/v0_3/web_audio_pause_diagnosis.md) ยังไม่ใช้การแก้ source นี้อ้างผล FPS ที่ไม่ได้วัดสำเร็จ

ชุดตรวจแยกใน `tools/build_web_qa.py` ยังเก็บไว้ให้รันซ้ำได้: คัดลอก source/assets ที่มี hash และแสดงปุ่ม Start QA จากนั้นเดินครบเรื่องในโหมดปกติ แล้ววัดอีก 30 วินาทีในห้องเซิร์ฟเวอร์ที่มีศัตรูจริง 4 ตัว โดยเปิดอมตะเฉพาะช่วงวัดเพื่อรักษาภาระงานคงที่

วัดจากเวลาของ `RenderingServer.frame_post_draw` ที่ 1280×720 ข้ามช่วงพัก/เมนู/แท็บซ่อนและ warm-up 2 วินาทีต่อห้อง FPS เฉลี่ย = จำนวนเฟรมหารเวลารวม; p95 คำนวณจากเวลาเฟรมจริง เป้าหมายเฉลี่ย ≥55 FPS และ p95 ≤25 ms บนเครื่องนี้

## ข้อจำกัด

- 20–30 นาทีเป็นเป้าหมายเวลาเล่นครั้งแรก ยังไม่มีผลทดลองกับผู้เล่นใหม่ เวลา bot รายงานแยก
- ผลเครื่อง RTX 5060 Ti ไม่รับรองเครื่องสเปกต่ำหรือมือถือ มีโหมดภาพเบาที่ลดความละเอียด 3D เหลือ 75% และปิดเงา
- ผลโหลด/ducking เสียงไม่แทนการประเมินความดังและความน่ากลัวด้วยการฟังของมนุษย์ ไม่มีเสียงพากย์
- ไม่มี multiplayer และอาจารย์ประจำเหตุการณ์ ไม่เดินตามทั้งด่าน ไม่มีเงื่อนไขแพ้จาก HP อาจารย์

## การเผยแพร่และย้อนกลับ

สถานะ: รอตรวจเว็บชุดสุดท้ายก่อนอัปเดต GitHub Pages เดิม เก็บฐานก่อนเปลี่ยนไว้ที่ branch `codex/pre-demon-v0.2`, commit `d75d0f6283f2fd60f66cb5114a455c588f5f7219` การเผยแพร่ใช้ไฟล์ `docs` บน main และต้องตรวจ hash ไฟล์สาธารณะตรงกับไฟล์ส่งออก

ผลรุ่น 0.2 เป็นประวัติคนละ campaign: [VALIDATION เดิม](https://github.com/Avocadough/f-student-revenge/blob/d75d0f6283f2fd60f66cb5114a455c588f5f7219/VALIDATION.md) และ JSON เดิมใน `Verification/` ไม่ใช้ผลเก่าทดแทนการตรวจรุ่นนี้
