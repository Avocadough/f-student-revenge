# ผลตรวจเดโม 0.4.1 — ลดลายเม็ดบนพื้นผิว

ตรวจวันที่ **1 ตุลาคม 2026** ด้วย Godot 4.7.2 Stable / Compatibility renderer งานรอบนี้แก้การสุ่มตัวอย่างพื้นผิวตามระยะ ไม่เปลี่ยนเนื้อเรื่อง การต่อสู้ โมเดล ความละเอียด หรือระบบเซฟ

## สาเหตุและสิ่งที่แก้

ไฟล์ albedo, normal และ roughness ของพื้นคอนกรีต/ผนังปูนทั้งหกไฟล์เป็นภาพ 1024×1024 แต่เดิมนำเข้าโดยไม่มี mipmap เมื่อมองพื้นเอียงหรือไกลจึงเกิดรายละเอียดระดับพิกเซลเป็นเม็ดทั่วภาพ เปิด mipmap ครบทั้งหกไฟล์ บังคับ renormalize normal map สองไฟล์ และตั้งวัสดุพื้น/ผนัง/คอนกรีตเป็น linear filtering พร้อม mipmap และ anisotropy 4× ไฟล์ JPG ต้นฉบับยังมี SHA-256 ตรง download receipt เดิม

อ้างอิงพฤติกรรม [Godot image importing](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#mipmaps-generate), [material texture filtering](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) และ [ตัวนำเข้า normal map ของรุ่น 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/import/resource_importer_texture.cpp) เพิ่ม `Verification/.gdignore` เพื่อไม่ให้ Godot นำเข้าภาพหลักฐานการทดสอบเป็นทรัพยากรของเกม; โฟลเดอร์นี้ถูกตัดออกจาก Web export อยู่แล้ว

## หลักฐานรอบแก้พื้นผิว

| ขอบเขต | ผล |
|---|---|
| ทรัพยากรจริงและวัสดุสองระดับภาพ | [15/15 ผ่าน](Verification/v0_4_1/surface_filtering_checks.json): ภาพทั้งหกมี mipmap จริง 10 ระดับ และ material ใช้ filter 5 |
| ภาพเปรียบเทียบจากเกม | [ก่อนแก้](Verification/v0_4_1/before/capture.json) / [หลังแก้](Verification/v0_4_1/after/capture.json): 8 คู่ ครบสามด่านทั้งมาตรฐาน/ประหยัด และเพิ่มสองภาพมุมต่ำของพื้น ใช้กล้อง ตำแหน่ง และความละเอียดตรงกัน |
| ฐานก่อนแก้ | โหลด PCK รุ่น 0.4 ในโฟลเดอร์ runner ว่างด้วย `--main-pack`; SHA-256 `e3765e618483cddaf1377475036e228cd132550fdec0bf94ebc43947b8ae093d`, ยืนยันภาพไม่มี mipmap และ filter 3 |
| ภาพหลังแก้ | รายละเอียดเม็ดบนพื้นระยะกลาง/ไกลและเพดานลดลงชัด รอยคราบขนาดใหญ่และรายละเอียดระยะใกล้ยังอยู่ ไม่มีการแต่งภาพที่จับจากเกม |
| Import / Web export | สำเร็จ exit 0; ไม่มี ERROR/SCRIPT ERROR ในรอบสุดท้าย |
| แพ็กส่งออกจริง | [13/13 ผ่าน](Verification/v0_4_1/surface_release_pack_checks.json), ข้ามสองค่าตั้งค่านำเข้าซึ่งไม่ถูกส่งออก แต่ตรวจ mipmap จริงครบ; [receipt](Verification/v0_4_1/surface_release_pack_receipt.json) และ [ภาพจาก PCK](Verification/v0_4_1/surface_release_pack_stage2.png) ยืนยันรันจากแพ็กในโฟลเดอร์ภายนอกที่ไม่มี source |
| Web export ผ่าน localhost บน Edge | เข้าเมนู เลือกด่าน AI เห็นศัตรู/HUD และพื้นผิวใหม่จริง; [ภาพเว็บ](Verification/v0_4_1/edge_local_gameplay.jpg) |

ภาพจับด้วย fixture ที่หยุด AI/ฟิสิกส์/แอนิเมชันและตั้งเวลา portal shader คงที่เฉพาะ fixture เพื่อให้เทียบภาพได้ ไม่ใช่หลักฐานเล่นชนะเกม รายละเอียด runner อยู่ใน `tools/capture_surface_quality.gd` ผลทดสอบเดินครบเกมของ 0.4 ด้านล่างเป็นประวัติ ไม่อ้างว่ารันครบใหม่ในรอบพื้นผิวนี้

## ประสิทธิภาพและข้อแลกเปลี่ยน

วัด native บน RTX 5060 Ti ที่ 1280×720, มาตรฐาน, 2× MSAA และเพดานส่งมอบ 60 FPS: ฉากเซิร์ฟเวอร์มีศัตรูสี่ตัว ตัวละครเดินซ้าย/ขวาและอมตะเฉพาะช่วงวัด หลัง warm-up สองวินาทีเก็บตัวอย่างประมาณ 12 วินาที ดู [ข้อมูลดิบ](Verification/v0_4_1/performance.json)

| ค่า | 0.4 ก่อนแก้ | 0.4.1 หลังแก้ |
|---|---:|---:|
| เฉลี่ย FPS | 60.23 | 60.23 |
| p95 frame time | 17.731 ms | 17.852 ms |
| คำสั่งวาดมัธยฐาน | 301 | 301 |
| ข้อมูลภาพหกไฟล์ที่ถอดรหัส | 16.00 MiB | 21.33 MiB |
| ขนาด PCK | 19,008,760 bytes | 20,801,464 bytes |

ข้อมูลภาพเพิ่ม **5.33 MiB** จาก mipchain (ไม่ใช่การวัด VRAM/RAM รวมทั้งเกม) และแพ็กใหญ่ขึ้น **1.71 MiB** งบ 3D ยังคงมาตรฐาน 1280×720 / ประหยัด 960×540 ความละเอียดและขอบหยักในโหมดประหยัดยังเป็นข้อแลกเปลี่ยนเดิม ตัวอย่าง FPS ถูกจำกัดด้วยเพดาน จึงไม่อ้างว่าได้ความเร็วเพิ่ม หรือรับรอง ≥55 FPS บนเว็บ/เครื่องสเปกต่ำ เบราว์เซอร์ที่ใช้ควบคุมยังมีข้อจำกัด pointer lock ตามบันทึกรุ่นก่อน และเกมแสดงทางสำรองลากเมาส์กลาง/R

## การเผยแพร่ 0.4.1

**เผยแพร่สำเร็จ:** [เล่นเดโม 0.4.1](https://avocadough.github.io/f-student-revenge/) จาก commit `2404dd606ebb4f05f0061ca1540ec710964f9045`, [Pages run 36783887414](https://github.com/Avocadough/f-student-revenge/actions/runs/36783887414) สำเร็จ ตรวจ HTTP 200/SHA-256 ตรงครบเก้าไฟล์ใน [publication_v0_4_1.json](Verification/publication_v0_4_1.json)

แพ็กมี SHA-256 `70ae587d04a708e1c030d631c593a3a00e445330b46f6793fefe15961872a823` เก็บจุดย้อนกลับรุ่น 0.4 ที่ `codex/pre-smoothing-v0.4`, commit `d38e3fe84451509a127d20fbbf07fb19e154928d` บน GitHub แล้ว

เปิดลิงก์สาธารณะด้วย Edge หลัง reload ยืนยัน HTML อ้างอิงขนาด PCK ใหม่ 20,801,464 bytes และเลือกเข้าเล่นด่าน AI เห็นพื้น/เพดานใหม่จริง ดู [ภาพจาก GitHub Pages](Verification/v0_4_1/pages_gameplay.jpg) แท็บที่ค้างจากรุ่นก่อนยังแสดงค่าเก่าจน reload จึงควรรีเฟรชหน้าเว็บก่อนสาธิต

---

# ประวัติผลตรวจเดโม 0.4 — UI สยองขวัญและลดภาระเครื่อง

ตรวจวันที่ **1 ตุลาคม 2026** ด้วย Godot 4.7.2 Stable / Compatibility renderer บน Windows, NVIDIA RTX 5060 Ti งานรอบนี้ปรับ UI และคุณภาพการเรนเดอร์ คงเดโมสามด่าน เนื้อเรื่อง และเงื่อนไขการต่อสู้เดิม

## สิ่งที่ตรวจผ่าน

| ขอบเขต | ผลและหลักฐาน |
|---|---|
| หน้าหลัก วิธีเล่น ตั้งค่า เลือกด่าน บทนำ เครดิต HUD พักเกม แพ้ ผ่านด่าน และตอนจบ | [UI fixtures](Verification/v0_4/horror_ui_checks.json): 1,167 assertions ผ่าน; เก็บภาพจริง 49 ภาพที่ 1280×720, 960×540, 800×720; ตรวจด้วยตาเพิ่มเติมเรื่องภาษาไทย กรอบ และการซ้อนทับ ตัวเลขนี้เป็นการตรวจ layout/focus ไม่ใช่จำนวนระบบเกม |
| ข้อความยาวและคีย์บอร์ด | แก้ focus ก่อน layout เสร็จที่ทำให้ปุ่มท้ายถูกตัด; หน้ายาวเปิดที่หัวข้อแล้ว Tab ไปเห็นปุ่มครบ หน้าตั้งค่าครบในหน้าเดียวที่ 720p; 540p เลื่อนได้ |
| คุณภาพจากหน้าตั้งค่าจริง | [Native checks](Verification/v0_4/render_quality_checks_native.json), [headless checks](Verification/v0_4/render_quality_checks_headless.json): 14/14 แต่ละโหมดรันทดสอบ ครอบคลุม 720p/1080p, DPI, ระดับภาพ, แสง, FX, AA, 60 FPS cap และฟิสิกส์ 60 Hz |
| ภาระฉาก | [27 snapshots](Verification/v0_4/quality_resource_audit.json): ปกติ → ประหยัด → ปกติ ครบเก้าจุดเริ่มใหม่; จุดเกิด ทางออก และอุปกรณ์ภารกิจคงเดิม |
| เมนู/เซฟ/การกลับเข้าเกม | [25 checks](Verification/v0_4/menu_persistence_checks.json) ผ่านใน user directory แยก |
| God Mode บน UI / ทางสำรองจับเมาส์ | [18 checks](Verification/v0_4/god_mode_ui_checks.json), [15 checks](Verification/v0_4/browser_fallback_checks.json) ผ่าน |
| แพ็กส่งออกสุดท้าย | [28 checks](Verification/v0_4/release_pack_gameplay.json) ผ่านจาก PCK ด้วย native headless; บอตใช้คำสั่งตัวละครเดินครบเก้า checkpoint ถึง F → D, retry 0, 142.37 วินาทีจำลอง |
| เว็บโหลด/แจ้งข้อผิดพลาด | JavaScript parse และ lifecycle แบบ stub 14 checks ผ่าน; template placeholders ตรง Godot ที่ติดตั้งครบ 8 ตัว ดู [shell checks](Verification/v0_4/web_shell_checks.json) |

ชุด UI ใช้ fixture เปิดสถานะต่าง ๆ เพื่อเก็บภาพ ไม่ถือว่าเล่นชนะเกม ชุด PCK ใช้ runner นอกโครงการในโฟลเดอร์ชั่วคราวว่าง แล้วโหลด Scenes/Scripts/Assets จากแพ็กจริง ไม่ใช้ source เป็นทางสำรอง ไม่แก้ HP/teleport/เปิดอมตะในช่วงเดินเรื่อง บอตอ่านสถานะศัตรูและกดปุ่มเมนูผ่านสัญญาณ จึงไม่แทนการเล่นครั้งแรกของคน รายละเอียด [pack receipt](Verification/v0_4/release_pack_receipt.json)

## ผลลดงานเรนเดอร์

ลบฉาก 3D ที่ถูกภาพหน้าปกบัง ใช้กรอบ UI เวกเตอร์คงที่ ไม่มี noise shader เคลื่อนไหวทั้งจอ จำกัดการเรนเดอร์ **60 FPS** ทั้งสองระดับโดยคงฟิสิกส์ 60 Hz กำหนดงบจากขนาด render target จริง ไม่ใช้ขนาด UI ที่อาจเล็กกว่าบนจอ DPI สูง

| ค่า | มาตรฐาน | ประหยัด |
|---|---|---|
| ความละเอียด 3D สูงสุด | 1280×720 | 960×540 |
| เงา / ลบรอยหยัก | เปิด / 2× | ปิด / ปิด |
| ไฟ | ห้องปัจจุบันครบ + ไฟหลักห้องใกล้เคียง | ไฟหลักต่อห้องที่มองเห็น |
| ประกายสูงสุดใน pool | 12×7 = 84 | 6×4 = 24 |

ทดสอบ native ในห้องเซิร์ฟเวอร์ ศัตรูปกติสี่ตัว ตัวละครเดินซ้ายขวาและอมตะเฉพาะช่วงวัด Warm-up สองวินาที แล้ววัดเวลาเฟรมจริงประมาณ 12 วินาที:

| ตัวอย่าง | เฉลี่ย FPS | p95 frame time | คำสั่งวาดมัธยฐาน |
|---|---:|---:|---:|
| แพ็กเดิม ภายใต้เพดานทดสอบ 120 | 120.22 | 9.199 ms | 301 |
| ใหม่ มาตรฐาน ภายใต้เพดานทดสอบ 120 | 120.22 | 9.002 ms | 301 |
| ใหม่ ประหยัด ภายใต้เพดานทดสอบ 120 | 120.09 | 9.137 ms | 148 |
| ใหม่ มาตรฐาน เพดานส่งมอบจริง 60 | 60.23 | 17.731 ms | 301 |

โหมดประหยัดลดคำสั่งวาดที่วัดได้ **50.8%** และงบพิกเซล 3D **43.75%** ขณะที่ UI ยังเรนเดอร์แยก ภาพฉากจะนุ่มขึ้นและมีขอบหยัก/เงาน้อยลง ตัวอย่างถูกจำกัดด้วยเพดาน FPS จึงไม่อ้างว่าเร็วขึ้นกี่ FPS หรือใช้ RAM ลดลงกี่เปอร์เซ็นต์ ดู [ข้อมูลดิบและข้อจำกัด](Verification/v0_4/render_quality_performance_summary.md)

## ตรวจเว็บจริง

เปิด Web export ชุดใหม่บน Edge ผ่าน localhost แล้วตรวจเมนู ตั้งค่า เลือกโหมดประหยัด เลือกด่าน เข้าเกมเห็น HUD/ศัตรู และพักเกมด้วย P ได้ ภาพ [พักเกมบน Edge](Verification/v0_4/screenshots/edge_local_pause.png) เบราว์เซอร์ที่เครื่องมือควบคุมใช้ปฏิเสธ pointer lock ด้วย WrongDocumentError; เกมแสดงคำแนะนำลากเมาส์กลาง/R ตามทางสำรองที่มีอยู่ จึงไม่ใช้รอบนี้ยืนยัน pointer lock สำหรับผู้เล่นหรือ FPS ของแท็บ foreground

**ยังไม่มีผล FPS บนเว็บที่ใช้รับรองเกณฑ์ ≥55 FPS/p95 ≤25 ms และยังไม่ได้ทดสอบเครื่องสเปกต่ำจริง** ผล native ของ RTX 5060 Ti ไม่แทนเครื่องทั่วไปหรือมือถือ รอบนี้ไม่ได้อ้างว่าเล่นครบเกมด้วยมือบน Chrome/Edge และไม่ได้วัดการฟังเสียงจากมนุษย์

## การเผยแพร่

**เผยแพร่สำเร็จ:** [เล่นเดโม 0.4](https://avocadough.github.io/f-student-revenge/) จาก commit `05f7a95fe6e2c5079205399d6687266ef52db611`, [Pages run 36781773030](https://github.com/Avocadough/f-student-revenge/actions/runs/36781773030) สำเร็จ ตรวจ HTTP 200/SHA-256 ตรงครบเก้าไฟล์ใน [publication_v0_4.json](Verification/publication_v0_4.json) และเปิดลิงก์สาธารณะด้วย Edge เห็นหน้าโหลดภาษาไทยแล้วเข้าสู่ [เมนูใหม่จริง](Verification/v0_4/screenshots/pages_first_view.png)

PCK ที่เผยแพร่และทดสอบเล่นจบมี SHA-256 `e3765e618483cddaf1377475036e228cd132550fdec0bf94ebc43947b8ae093d` ขนาด 19,008,760 ไบต์ (เพิ่มจากรุ่นก่อนเพียง 6,148 ไบต์) ตัวเปรียบเทียบยอมรับการแปลง CRLF ของ Git สำหรับ HTML/JS เท่านั้น; PCK/WASM ต้องตรงทุกไบต์

เก็บฐานเว็บ 0.3 ไว้ที่ `codex/pre-ui-v0.3`, commit `64b260a2a33873e8e5fe9619c3879866758ac114` หากต้องย้อนกลับ ให้คืน docs จากฐานแล้วสร้าง commit ใหม่โดยไม่ลบประวัติ

ประวัติแคมเปญ/โมเดล/เสียงและผล 299 checks ของรุ่นก่อนอยู่ใน [VALIDATION 0.3](https://github.com/Avocadough/f-student-revenge/blob/64b260a2a33873e8e5fe9619c3879866758ac114/VALIDATION.md) ไม่ใช้จำนวนดังกล่าวอ้างว่าได้รันทั้งหมดซ้ำในรอบ UI นี้ เวลาเล่นครั้งแรก 20–30 นาทีและความสนุกยังต้องประเมินกับผู้เล่นใหม่
