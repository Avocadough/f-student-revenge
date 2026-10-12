# หลักฐานเดโม 0.6 — การล้างแค้นของนักศึกษาติด F

ชุดคัดเลือกวันที่ 12 ตุลาคม 2026 สำหรับการปรับการเคลื่อนไหว อาจารย์ร่วมต่อสู้ และ UI ใช้ Godot **4.7.2-stable (official)** เก็บรายงานปัจจุบันและภาพ native หลักหกภาพ โดยรักษารายงานต้นฉบับ ภาพทั้งชุด และประวัติการแก้ไขไว้ใน `evidence/2026-10-12-polish/` และตำแหน่งที่ระบุใน manifest

ผลในชุดนี้เป็นการทดสอบ source แบบอัตโนมัติและภาพ/ประสิทธิภาพจาก native executable **ยังไม่รับรองพฤติกรรมหรือ FPS บนเบราว์เซอร์ และยังไม่ใช่การตรวจ release pack** ผลสองส่วนหลังต้องมีหลักฐานแยกต่างหาก

## ผลตรวจพฤติกรรม

| ชุดตรวจ | ผ่าน | รายงาน | ขอบเขตสำคัญ |
|---|---:|---|---|
| เล่นครบแคมเปญ | 31/31 | [gameplay_checks.json](gameplay_checks.json) | บอตใช้การเคลื่อนที่และปุ่มจริงจนจบเก้าจุดภารกิจ |
| อาจารย์ร่วมต่อสู้ | 50/50 | [teacher_companion_checks.json](teacher_companion_checks.json) | เดินตาม ชนฉาก มุมโจมตี ระยะ/กำแพง การหยุด และวงจร checkpoint |
| จังหวะการเคลื่อนไหวใหม่ | 5/5 | [motion_checks.json](motion_checks.json) | หยุดเท้าเมื่อชนกำแพง รักษาเฟสเดิน/วิ่ง และจังหวะหมัดโดน |
| การเคลื่อนไหวเดิม | 14/14 | [motion_regressions.json](motion_regressions.json) | locomotion กล้อง animation และเอฟเฟกต์ |
| แคมเปญ/สกิลอาจารย์ | 52/52 | [demon_campaign_checks.json](demon_campaign_checks.json) | marker ภารกิจ สกิล T และ lifecycle |
| เหตุการณ์ทะเบียน/ตราประทับ | 51/51 | [registry_story_checks.json](registry_story_checks.json) | เหตุการณ์ที่เขียนไว้ การเตือน และข้อจำกัด hazard |
| สัญญาเนื้อเรื่องและเซฟเดิม | 40/40 | [story_contract_checks.json](story_contract_checks.json) | 3×3 checkpoints, เซฟ v2 และ E → บทสนทนา → เล่นต่อ |
| เมนูและการบันทึก | 25/25 | [menu_persistence_checks.json](menu_persistence_checks.json) | callback เมนูและไฟล์เซฟทดสอบที่แยกจากผู้เล่น |
| God Mode การต่อสู้ | 36/36 | [god_mode_combat_checks.json](god_mode_combat_checks.json) | เปรียบเทียบโหมดปกติและโหมดช่วยทดสอบด้วย API จริง |
| God Mode UI/เซฟ | 18/18 | [god_mode_ui_checks.json](god_mode_ui_checks.json) | ค่าเริ่มต้น เมนู และ persistence |
| ย้ายรูปแบบเซฟ | 8/8 | [save_migration_checks.json](save_migration_checks.json) | ไฟล์ทดสอบบนดิสก์และการสร้าง checkpoint กลับมา |
| UI และแถบสถานะอาจารย์ | 28/28 | [ui_polish_checks.json](ui_polish_checks.json) | focus, modal, แถบ HP และแยกสถานะช่วยสู้จากคูลดาวน์ T |
| รูปแบบหน้าจอ native | 1,338/1,338 | [native_ui_layout_checks.json](native_ui_layout_checks.json) | 1280×720, 960×540, 800×720; ย่อเฉพาะ inventory รายภาพออก |
| Web shell แบบจำลอง | 32/32 | [web_shell_checks.json](web_shell_checks.json) | จำลอง Engine startup/loading/error; ไม่ได้เปิดเบราว์เซอร์หรือทดสอบเครือข่าย |

ทุกชุดด้านบนมี failure เป็นศูนย์ ชุดตรวจแต่ละชุดมีกรณีทับซ้อนกัน จึงไม่รวมเป็นจำนวนพฤติกรรมอิสระ รายละเอียด fixture และข้อจำกัดอยู่ใน JSON ของแต่ละชุด การตรวจรูปทรง UI และขนาดตัวอักษรไม่แทนการอ่านภาพจริง

รายงาน layout 1,338 ข้อรันก่อนการแก้ glyph รอบสุดท้าย ซึ่งเปลี่ยนเครื่องหมายคั่นเมนูเป็น `/`, ข้อความผลเกรดเป็น `F เป็น D`, ลูกศรเล่นต่อเป็น `›` และป้ายสัญลักษณ์ไฟเป็นคำว่า `ไฟฟ้า` ไม่ได้รันชุด 1,338 ข้อซ้ำหลังเปลี่ยนข้อความ ส่วนชุด UI polish 28 ข้อ, story contract 40 ข้อ, เหตุการณ์ 51 ข้อ และภาพ native หลักหกภาพเป็นผลหลังแก้ข้อความแล้ว

### การเล่นครบเก้าจุดภารกิจ

บอตจบด้วย **0 retries**, เวลาเกมจำลอง **129.766666666667 วินาที (129.77 วินาที)** พบ payoff ครบหกครั้ง และตราประทับหนึ่ง warning/หนึ่ง impact อาจารย์โจมตีโดนจริงรวม **18 ครั้ง** นับตามห้องเป็น `0, 3, 1, 1, 2, 2, 2, 4, 3`

ช่วง traversal เริ่มเกมจากเมนู ใช้ input จริง ไม่มี direct damage, teleport, แก้ HP, ปิดศัตรู หรือเปิด invulnerability; บอตอ่าน state ศัตรูได้ และ checkpoint บอสฟื้น HP ตามกติกาเกม ส่วน isolated combat fixtures ก่อน traversal จัดตำแหน่งและหยุด AI บางตัวตามที่เปิดเผยในรายงาน ทั้งชุดใช้ `qa_no_save` ไม่เขียนความคืบหน้าของผู้เล่น

**129.77 วินาทีเป็นเวลาบอต ไม่ใช่เวลาที่ผู้เล่นจริงจะใช้** ผลนี้ไม่วัดความสนุก ความยากสำหรับมนุษย์ หรือความลื่นของภาพบนเว็บ

### ขอบเขตอาจารย์ร่วมต่อสู้

ชุด 50 ข้อตรวจการเดินตามด้วย physics จริง และความเสียหายผ่าน enemy API จริง ครูไม่กีดขวางผู้เล่น ไม่มี HP ให้ต้องคุ้มกัน ไม่สร้าง friendly fire และไม่ถูกนับในศัตรูที่ต้องกำจัด ครูต้องหันเข้าหาเป้าหมายก่อนเริ่มหมัดและตรวจมุมอีกครั้งตอนโดน จึงไม่ตีคนที่อยู่ด้านหลังระหว่างหมุนหรือเปลี่ยนตำแหน่งได้ สกิล T เดิมยังคูลดาวน์ 15 วินาที และ God Mode ของผู้เล่นไม่ทำให้หมัดอัตโนมัติของครูแรงขึ้น

## ประสิทธิภาพ native ภายใต้เพดาน 60 FPS

วัดด้วย **NVIDIA GeForce RTX 5060 Ti**, หน้าต่าง **1920×1080**, physics 60 Hz และเพดานเกม **60 FPS** จริง ไม่ปลดเพดาน ผลอ่านจาก [performance_1.json](performance_1.json) และ [performance_0.json](performance_0.json)

| โหมด | ขนาดเรนเดอร์ 3D | MSAA | ระยะวัด | เฟรม | FPS เฉลี่ย | p95 frame time | p99 frame time | median draw calls |
|---|---|---|---:|---:|---:|---:|---:|---:|
| quality 1 | 1920×1080 (scale 1.0) | 4× | 12.010060 s | 721 | **60.03** | **17.826 ms** | 18.910 ms | 334 |
| quality 0 | ประมาณ 1280×720 (scale 0.66666669) | 2× | 12.003717 s | 723 | **60.23** | **17.822 ms** | 18.397 ms | 157 |

Fixture เดียวกันอยู่ด่าน 2 ห้อง 2 มี AI ศัตรูสี่ตัวและอาจารย์ที่ช่วยต่อสู้ ผู้เล่นเดินซ้าย/ขวาด้วย input จริง แต่ **เปิด invulnerability และเติม HP ศัตรูเพื่อคงภาระงาน** อุ่นเครื่องสองวินาทีก่อนเก็บข้อมูลประมาณ 12 วินาที ปิด VSync สำหรับ fixture แต่คงเพดาน 60 FPS ของเกม ไม่มี pause frames

ตัวเลขสูงกว่า 60 เล็กน้อยมาจากการนับเฟรมในช่วงวัดจำกัด ไม่แสดงว่าเกมปลดเพดาน ผลนี้แสดงพฤติกรรม native บนเครื่องและฉากที่วัดเท่านั้น **ไม่ใช่ Web FPS ไม่ใช่การวัดเครื่องสเปกขั้นต่ำ และไม่รับประกันคอมพิวเตอร์ทั่วไป** ตัวชี้วัด stationary render steps เป็นการตรวจตำแหน่งรากตัวละคร ไม่ใช่การประเมินความลื่นของกระดูกทั้งร่าง

## ภาพ native ที่คัดเลือก

| ภาพ | ไฟล์ |
|---|---|
| เมนูหลัก | [menu.png](screenshots/menu.png) |
| เลือกด่าน | [stages.png](screenshots/stages.png) |
| ตั้งค่า | [settings.png](screenshots/settings.png) |
| บทนำ | [intro.png](screenshots/intro.png) |
| ฉากต่อสู้และสถานะอาจารย์ | [combat.png](screenshots/combat.png) |
| พักเกม | [pause.png](screenshots/pause.png) |

ภาพหกภาพมาจาก `tools/capture_polish_review.gd` ซึ่งจัดฉากและเรียกหน้าจอเพื่อทบทวนการแสดงผล ฉากต่อสู้เปิด God Mode สำหรับการจับภาพ จึงไม่ใช้ภาพชุดนี้รับรองการผ่านแคมเปญ รายงาน UI ฉบับเต็มมี 70 synthetic captures; เก็บต้นฉบับไว้นอกชุดคัดเลือกนี้และไม่ได้ทำสำเนาภาพทั้งชุด

## ความเชื่อมโยงของหลักฐาน

[manifest.json](manifest.json) บันทึก SHA-256, ขนาดไฟล์, เวลาแก้ไขต้นทาง และเส้นทางเดิมของหลักฐาน รวมถึง snapshot แฮชของ source/config/fixture ที่เกี่ยวข้องตอนรวบรวม ไฟล์ผลทดสอบคัดลอกแบบคงเนื้อหา; รายงาน UI ย่อรักษา assertions ทั้งหมดและระบุ hash ของต้นฉบับ โดยตัด inventory รายภาพออกเพื่อลดขนาด

แฮช snapshot ณ เวลารวบรวมไม่ใช่หลักฐานย้อนหลังว่าไฟล์ทุก byte ตรงกับเวลารันทุกชุด รายงานที่ฝัง `source_hashes` จะตรวจความตรงไว้ใน manifest แยกต่างหาก ผลพฤติกรรมก่อนการเก็บข้อความ UI รอบสุดท้ายยังระบุเวลาต้นฉบับไว้ ไม่อ้างว่าได้รันทุกรายการซ้ำหลังการแก้ข้อความ

Fixture ปัจจุบันอยู่ใน `tools/` ได้แก่ `test_gameplay_v06.gd`, `test_teacher_companion.gd`, `test_motion_polish.gd`, `test_motion_regressions.gd`, `test_demon_campaign.gd`, `test_registry_story.gd`, `test_story_contract.gd`, `test_menu_persistence.gd`, `test_god_mode_v03.gd`, `test_god_mode_ui.gd`, `test_save_migration_v03.gd`, `test_polish_ui.gd`, `test_ui_layout.gd`, `test_web_shell_cache.cjs`, `measure_polish_performance.gd` และ `capture_polish_review.gd`
