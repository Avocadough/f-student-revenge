# Astra สำหรับพัฒนาเกม: หลักฐานชุมชนและสิ่งที่นำมาใช้กับโปรเจกต์นี้ได้

ตรวจเมื่อ **12 ตุลาคม 2026**; ช่วงค้น **12 กันยายน–12 ตุลาคม 2026** ตามวันที่เผยแพร่ ไม่ใช้วันที่ crawler เป็นวันที่โพสต์ วันที่จาก Reddit JSON แสดงเป็น UTC; บทความที่มีเฉพาะวันเผยแพร่ไม่ทราบเขตเวลา ขอบเขตเป็น **host web-only** ไม่ใช่การรัน last30days engine หลายแพลตฟอร์มเต็มรูปแบบ

## ข้อสรุปเพื่อใช้งาน

พบรายงานจากผู้ทำเกมเองที่ระบุ **OpenAI GPT‑6 Astra ใน Codex** จริง รวมถึง Godot แต่หลักฐานยังไม่รองรับว่า Astra ทำเกมสำเร็จพร้อมส่งมอบจากคำสั่งเดียว หรือให้ภาพดีกว่าทุกรุ่นเสมอ เทคนิคที่เหมาะกับเกมนี้ที่สุดคือ **กำหนดภาพเป้าหมายจากเกมเดิม → แก้ทีละส่วน → เปิดดูภาพจากเกมจริง → ให้ผู้ตรวจอีกคนชี้ข้อบกพร่อง → ทดสอบการเล่นและงบเรนเดอร์ร่วมกัน**

ยืนยันตัวตนจาก [หน้า OpenAI GPT‑6 Astra](https://openai.com/index/gpt-6-astra/) และรายงานผู้ทดลองที่ระบุ `gpt-6-astra` โดยตรง ไม่ใช้ Google Project Astra หรือเอนจินอื่นชื่อ Astra แทน หลักฐานต่อไปนี้แยกคำบอกเล่า ผลงานที่อ่านได้ และข้อเสนอของผู้วิจัยออกจากกัน

## หลักฐานในช่วงที่กำหนด

| แหล่งต้นทาง / วันที่ | สิ่งที่ตรวจพบจริง | น้ำหนักและข้อจำกัด | ผลต่อการตัดสินใจ |
|---|---|---|---|
| [FutureProof Agents: HEADQUARTERS case study](https://futureproofagents.com/blog/game-design-case-study-gpt-6-astra/), **2026-09-16**; เหตุการณ์ 15–16 ก.ย. | ผู้เขียนระบุ Codex + Astra + Godot 4.7.2 ใช้เอกสารออกแบบและ feedback 6 รอบ; อ่านรายละเอียด pipeline สไปรต์ เครื่องมือตรวจ pivot และข้อผิดพลาดด้านสเกล/ความรู้สึกการเล่น ผู้เขียนแยก first playable ออกจากเกมพร้อมขาย | **รายงานลงมือทำของผู้เขียนหนึ่งราย** มีภาพและขั้นตอนละเอียด แต่ไม่ได้ตรวจ source repository หรือเล่น build; ผู้เขียนขายบริการ agent จึงมีแรงจูงใจเชิงธุรกิจด้วย ตัวเลขเวลา/จำนวนระบบเป็นคำรายงานของเขา | **Adopt** หลักการแปลง feedback ที่ตรวจซ้ำได้เป็น acceptance check และให้คนเล่นตรวจ feel; ไม่ยืมขนาดโปรเจกต์หรือคำกล่าวอ้างเวลาเป็นประมาณการของเรา |
| [Certain_Friendship16: GPT‑6 Astra + Godot + Blender](https://www.reddit.com/r/TopologyAI/comments/1wh4ne0/gpt6_astra_godot_blender/), **2026-09-15 16:08:16 UTC** | ผู้โพสต์ให้ขั้นตอนรวมภาพ/วิดีโอใน Ref, ให้โมเดลอ่านทิศทางภาพ แล้วใช้ Godot/Blender MCP และ Dream-loop; อ่านโพสต์และคำถามตอบกลับ | **คำบอกเล่า/โชว์ผลงาน** ไม่มี source, บันทึกต้นทุน หรือผลทำซ้ำที่ตรวจได้ในหน้าที่อ่าน ผู้ตอบถามที่มาทรัพยากรและค่าใช้จ่ายโดยยังไม่มีคำตอบชัดเจน จึงไม่ถือเป็นหลักฐานว่าปั้นทั้งหมดเอง | **Trial** ภาพอ้างอิงร่วมกัน; **Defer** การติดตั้ง MCP ตามคลิป เพราะยังไม่เห็นช่องว่างที่เครื่องมือเดิมทำไม่ได้ |
| [Delicious-Shower8401: Unreal + Blender workflow](https://www.reddit.com/r/ChatGPT/comments/1wljrn8/gpt6_astra_unreal_blender_faster_game_development/), **2026-09-20 15:18:17 UTC** | ผู้ทำระบุ Tripo สำหรับบาง assets, Blender สำหรับ cleanup, Dream-loop, ใช้ภาพอ้างอิงแสง และแก้ต้นไม้/แสงด้วยตนเองหลังจากนั้น; ผู้ชมวิจารณ์เสียงเท้าดัง | **รายงานใช้งานจริงหนึ่งราย** รายละเอียดช่วยแยกสิ่งที่ Astra ทำกับเครื่องมือสร้างโมเดลอื่น แต่ไม่ได้ชมวิดีโอเต็มหรือเล่นเกมเอง; Unreal ไม่ใช่ข้อพิสูจน์บน Godot Web | **Adopt** การเปิดเผย pipeline/ที่มา assets และตรวจภาพกับเสียงแยกกัน; **Defer** Tripo/บริการเสียเงิน |
| [DarthOrganism: คำอธิบาย art guide](https://www.reddit.com/r/aigamedev/comments/1w9bkiw/comment/pb47anv/), **2026-09-21 06:50:57 UTC** | คำตอบใหม่ในกระทู้เก่า: ผู้ทำสร้างแนวทางภาพกับ Codex แล้วให้การสร้าง assets ยึดแนวทางเดียวกัน อ่าน comment ต้นทางและ JSON ของ comment | **คำบอกเล่าเชิงกระบวนการ** ไม่มีไฟล์ template สาธารณะใน comment; ต้นกระทู้สร้างก่อนช่วงค้น จึงนับเฉพาะคำตอบ 21 ก.ย. เป็นข้อมูลใหม่ ไม่เปลี่ยนวันที่ของเดโมเดิม | **Adopt** art brief สั้นที่ชี้สเกล สัดส่วน สี วัสดุ และภาพตัวอย่างที่ยอมรับได้ |
| [Varrianda: ปัญหา one-shot](https://www.reddit.com/r/aigamedev/comments/1wxxcqk/claude_or_astra_which_is_better_and_what_game/pe2l7cv/), **2026-10-05 19:00:57 UTC** | ผู้ตอบรายงานว่า Astra สร้างวัตถุหลักใหญ่ โครงข้อมูลหลายแบบ และ implementation ซ้ำ จนต้องให้ Opus เก็บงาน ยอมรับด้วยว่าไม่ได้กำหนดโครงสร้างให้ชัด | **Anecdote / counterevidence** ไม่มี repo ให้ audit; อ่านข้อความ วันที่ และ permalink ใน [thread JSON](https://www.reddit.com/r/aigamedev/comments/1wxxcqk/claude_or_astra_which_is_better_and_what_game/.json?limit=10) เพราะเปิด comment โดยตรง timeout ไม่ใช้เป็นอันดับความเก่งของโมเดล | **Adopt** ขอบเขตไฟล์เล็กและผู้ตรวจแยก; ไม่สั่งเขียนระบบเดิมใหม่ทั้งเกมเพื่อหวังภาพดีขึ้น |

วันที่ Reddit ตรวจจาก `created_utc`: `1789488496`, `1789917497`, `1789973457`, `1791226857` ตามลำดับแถว Reddit ด้านบน หลักฐานต่างผู้เขียนช่วยสนับสนุนว่า reference/iteration ถูกใช้จริง แต่ยังไม่ใช่การทำซ้ำแบบควบคุม หรือหลักฐานว่าต้องใช้ Astra เท่านั้น

## Skill ที่ตรวจ source ได้

**[achimala/dream-loop](https://github.com/achimala/dream-loop)** — อ่าน [README](https://github.com/achimala/dream-loop/blob/main/README.md), [SKILL.md](https://raw.githubusercontent.com/achimala/dream-loop/main/SKILL.md), [Pro workflow](https://raw.githubusercontent.com/achimala/dream-loop/main/references/pro-mode/workflow.md) และ [MIT license](https://github.com/achimala/dream-loop/blob/main/LICENSE) โดยตรง ผู้เขียนระบุว่าทดลองกับ GPT‑6 Astra ใน Codex; ต้องมีการสร้างภาพและอ่านภาพ และแนะนำผู้ตรวจแยก มี demo link แต่ครั้งนี้ **ไม่ได้รันหรือเล่น demo**

กลไกที่อ่านได้คือสร้างภาพเป้าหมายจากภาพเกมเดิม เปรียบเทียบ screenshot จริงด้วยผู้ตรวจใหม่ และให้ feedback แยกองค์ประกอบ แสง วัสดุ รายละเอียด พร้อมดู FPS ด้วย อย่างไรก็ตาม skill ต้นฉบับผลักให้ตรงภาพทุกพิกเซลและทำต่อจนเข้าเงื่อนไข ซึ่งอาจชนกับเวลาและงบภาพของเดโมเว็บ จึงแนะนำ **Trial เฉพาะกลไก แบบจำกัดรอบ** ไม่ใช้ข้อความต้นฉบับทั้งชุดโดยอัตโนมัติ หลัง root ขอ audit เพื่อติดตั้งตามคำสั่งเฉพาะของผู้ใช้ ยืนยัน HEAD ด้วย `git ls-remote` และ GitHub public API ได้เป็น [`9bddb901f7d071cfefdd21e264267c757177a9df`](https://github.com/achimala/dream-loop/commit/9bddb901f7d071cfefdd21e264267c757177a9df), committer date **2026-09-09 22:33:50 UTC** จึงยังเป็น reference เก่านอกช่วงค้น

ไม่พบเหตุผลให้ติดตั้ง skill เพิ่มสำหรับ animation/UI ในรอบนี้: catalog เครื่องมี `animation-system`, `godot-ui`, `godot-code-review`, `godot-testing` อยู่แล้ว และ repo มีเครื่องมือจับภาพ/ตรวจภาพ การมีชื่อ MCP ในโพสต์ไม่ได้พิสูจน์ว่า MCP เป็นองค์ประกอบที่ทำให้สำเร็จ

### Audit ขอบเขตติดตั้ง Dream-loop ณ commit ที่ตรึง

- **ขนาด:** tree มี 13 ไฟล์ รวม 7,024,601 bytes; 6,976,947 bytes เป็น `assets/vesper-preview.gif` ส่วนไฟล์อื่นรวม 47,654 bytes ไม่มี `package.json`, package installer, binary หรือ install hook ใน tree ที่ตรวจ การคัดลอก skill แบบตรึง commit ไม่จำเป็นต้องเรียก `npx` หรือติดตั้ง dependencies
- **อ่าน source ของ executable ครบสามไฟล์:** [`scripts/fal-batch.mjs`](https://github.com/achimala/dream-loop/blob/9bddb901f7d071cfefdd21e264267c757177a9df/scripts/fal-batch.mjs) ใช้ Node 18+ กับ built-in modules; `check` อ่าน JSON/ภาพในเครื่อง ส่วน `submit` ส่งภาพไปบริการ Fal โดยใช้ `FAL_KEY`/`FAL_API_KEY` และอาจเสียเงิน; `collect` ดาวน์โหลด GLB และเขียน output ตาม jobs file โดยไม่บังคับ path อยู่ใน workspace ต้องไม่เรียกสองคำสั่งหลังในงานนี้
- [`scripts/fal-batch.test.mjs`](https://github.com/achimala/dream-loop/blob/9bddb901f7d071cfefdd21e264267c757177a9df/scripts/fal-batch.test.mjs) ใช้ Node test runner, mock fetch และ temp directories ตาม source; ครั้งนี้อ่านอย่างเดียว ไม่ได้รันหรือรับรองผลทดสอบ
- [`scripts/preview-server.py`](https://github.com/achimala/dream-loop/blob/9bddb901f7d071cfefdd21e264267c757177a9df/scripts/preview-server.py) ใช้ Python standard library, bind `127.0.0.1:4172`, เสิร์ฟ directory ที่ระบุ และรับ PNG ผ่าน POST ไป `.dream-loop/captures/` ไม่จำเป็นสำหรับโปรเจกต์นี้เพราะมี capture pipeline เดิม ไม่ได้เริ่ม server
- **คำสั่งที่ต้องให้ข้อจำกัดผู้ใช้มีอำนาจเหนือกว่า:** เอกสาร assets แนะนำให้ใช้ Fal เมื่อพบ key และจัด image-to-3D ว่าไม่ใช่การดาวน์โหลด; Plus workflow อาจขอเปลี่ยนโมเดล; SKILL ต้องสร้างภาพ target หากไม่มี; Pro workflow อาจวนไม่จำกัดและรื้อฉากเมื่อคะแนนตัน การอ่านคำแนะนำนี้ไม่ได้อนุญาตให้ค้น key ใช้บริการเสียเงิน เปลี่ยนโมเดลเอง หรือขยายงาน
- **การตั้งค่า:** พบเพียงคำแนะนำสร้าง `.dream-loop` และเพิ่ม gitignore ใน workspace ไม่พบ executable ที่แก้ global config/บัญชี/ระบบ มีจุดอ้างอิงเอกสารผิดตำแหน่ง: `[fal.md](fal.md)` ภายใน `references/pro-mode/assets-3d.md` และ `plus-mode/assets-3d.md` แต่ไฟล์จริงอยู่ `references/fal.md`; ต้องแก้เส้นทางในการอ่านหากใช้ส่วนนี้ในภายหลัง
- **ผลแนะนำ:** ตามคำสั่งติดตั้งเฉพาะล่าสุด สามารถเก็บ skill ที่ audit และตรึง commit นี้ได้โดยไม่รัน helper และไม่ติดตั้งแพ็กเกจเพิ่ม สำหรับงาน UI ให้เลือกขอบเขต **Pro critique จากภาพ UI เดิม/ภาพเป้าหมายที่ได้รับอนุญาต จำกัด 2 รอบ ไม่เพิ่มฉากหรือ 3D assets ไม่เรียก Fal** หากต้องการเพียงตรวจ screenshot โดยไม่มีภาพ target อย่าอ้างว่าได้รัน Dream-loop เต็ม workflow; ใช้ `godot-ui` และผู้ตรวจภาพโดยตรงจะตรงงานกว่า

## ข้อมูลเก่า / สิ่งที่ไม่นับเป็นผลใหม่

- **2026-09-09:** [oubakiou: Godot effort comparison](https://zenn.dev/oubakiou/articles/faa33490272980) ทดลอง parent `claude-opus-5@max` กับ child Astra 4 effort ระดับละ 3 รอบ ในโจทย์มินิเกม 2D หนึ่งโจทย์ที่ไม่เปิด spec รายงาน high ผ่าน 57/57 แต่ xhigh ผ่าน 55/57 โดยพลาด input คลิกขวา มีหนึ่ง protocol failure ของ parent แยกจากคะแนน artifact นี่เป็นคำเตือนว่าการเพิ่ม effort ไม่รับประกันผลดีขึ้น ไม่ใช่หลักฐานเลือก effort ที่ดีที่สุดสำหรับเกมสามมิตินี้ และเราไม่ได้ทำซ้ำ
- **2026-09-11:** [OpenAI: Rethinking skills and prompts](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra) ยืนยันวันบนบทความและตัวตน Astra เป็น official background อยู่ก่อนช่วงค้น ไม่ใช่เสียงจากชุมชนหรือผลทดลองกับเกมนี้
- **2026-09-14:** [Gencay: I Built a Skill to Make $1M Games](https://www.learnwithmeai.com/p/build-games-gpt-6-astra) เป็นเนื้อหาจำกัดสมาชิก อ่านได้เฉพาะส่วนสาธารณะ ไม่ได้เข้าถึง skill เต็ม ไม่ยืนยันรายได้และไม่แนะนำซื้อจากชื่อเรื่อง
- [yangzhou-chaofan/awesome-gpt6-astra-game-prompts](https://github.com/yangzhou-chaofan/awesome-gpt6-astra-game-prompts) ใช้ค้นร่องรอยเท่านั้น รายการรวม/ดาว/ยอดชมไม่ใช่การทำซ้ำ ไม่ได้นำจำนวนเกมใน README มานับเป็นหลักฐานอิสระ

## วิธีที่เสนอสำหรับ “การล้างแค้นของนักศึกษาติด F”

1. **Adopt — brief และภาพจริงเป็นตัวตั้ง:** ยึดเรื่องและ 3×3 progression เดิม เขียนข้อบกพร่องที่สังเกตได้ เช่นเงารอยต่อคอ ท่าตีอ่านยาก ป้ายเล็ก หรือศัตรูกลืนกับฉาก เลือกภาพเกมหนึ่งจุดเป็น baseline และมีภาพเป้าหมายในมุมเล่นจริง ไม่ใช้ภาพปกแทนภาพเกม
2. **Trial — วงรอบภาพไม่เกิน 2 รอบในพื้นที่เดียว:** แก้เฉพาะประเด็นสำคัญ 2–3 ข้อ ผู้ตรวจที่ไม่ได้ลงมือแก้เปรียบเทียบมุมกล้อง/แสงเดียวกัน หากยังไม่ดีขึ้นให้สรุปสาเหตุและหยุดขยายขอบเขต การจำกัด 2 รอบเป็นข้อเสนอของงานนี้ ไม่ใช่เกณฑ์ที่ชุมชนพิสูจน์แล้ว
3. **Adopt — ภาพต้องผ่านพร้อมการเล่น:** ตรวจ idle/run/attack และระยะกล้องจริง ตามด้วยอ่านป้าย เป้าภารกิจ หลบ/โจมตี และ pause/restart ใช้เครื่องมือที่มี เช่น `tools/capture_final_characters.gd`, `tools/capture_stage_art.gd`, `tools/test_render_quality.gd`, `tools/test_surface_filtering.gd` โดยตรวจวิธีเรียกปัจจุบันก่อนรัน ไม่จำเป็นต้องเปิดเกมหลังทุกบรรทัดที่แก้
4. **Adopt — ประเมินโดยไม่ให้ผู้สร้างรับรองตัวเอง:** เกณฑ์รับงานคือข้อบกพร่องเป้าหมายลดลง ไม่มีอาการเสียใหม่ ภาพมีความสม่ำเสมอ และยังอยู่ในงบเรนเดอร์เว็บเดิม ต้องแยกผล native ออกจากเว็บ เก็บ screenshot/diff และผลตรวจที่ทำจริง
5. **Defer — ย้ายเอนจิน ซื้อบริการ และติดตั้งเพิ่ม:** หลักฐานยังไม่แสดงว่าต้องใช้ Unreal, Tripo หรือ MCP ใหม่เพื่อปรับเดโม Godot นี้ให้ดีขึ้น และไม่มีผลเทียบควบคุมที่พิสูจน์ว่า Astra/effort ใดให้ต้นทุนต่อความสำเร็จต่ำที่สุดบน repo นี้

ข้อเสนอข้างต้นเป็นการประยุกต์จากหลักฐานและเครื่องมือที่พบใน repo ไม่ใช่ผลทดลองใหม่ ระหว่างการค้นครั้งนี้ไม่ได้เปลี่ยนเกม สร้างภาพ รัน public code ติดตั้ง software ใช้ provider เสียเงิน ดึง cookies แก้ config ส่วนกลาง หรือเผยแพร่อะไร

## Coverage และช่องว่าง

ใช้ `last30days` ร่วมกับ `practitioner-intelligence-research` ผ่าน host search เท่านั้น ค้น 4 กลุ่ม: ตัวตน/ตัวอย่าง Astra, Godot/Blender workflow, skill/reference loop, และความล้มเหลว/การเปรียบเทียบ รวมคำค้นแบบ `"gpt-6-astra" game`, `"Astra" "Godot" "Codex"`, `"GPT-6 Astra" game "skill" after:2026-09-11 before:2026-10-13`, `"Dream-loop" "github" "Astra"`, `"GPT-6 Astra" Godot bugs failed` และตามลิงก์ต้นทางที่มีผลต่อคำแนะนำ

อ่าน Reddit, GitHub/raw files, บล็อกของผู้ลงมือทำ และ official identity/background ไม่ได้ใช้ native Reddit/X/YouTube adapters ของ engine และไม่ได้ตรวจ transcript/video/game builds จึงไม่อ้างว่าได้สำรวจทุกแพลตฟอร์ม ส่วนที่ไม่สำเร็จ: host web fetch ของ GitHub commit API/history (ภายหลังยืนยันด้วย Git/read-only public API ได้), permalink counterreport หนึ่งรายการ (อ่านสำเร็จจาก JSON แทน), และ URL official games guide ที่ลองเปิดได้ 404 ไม่มีผลสำเร็จของการเปิดเหล่านี้ถูกแต่งขึ้น การ audit เพิ่มเติมใช้ public GitHub HTTP อ่าน source ที่ตรึง commit เท่านั้น ไม่ clone ไม่ติดตั้ง ไม่รัน public code

**ความมั่นใจ:** สูงสำหรับตัวตนของ Astra และสิ่งที่เขียนอยู่ใน source ที่อ่าน; ปานกลางสำหรับข้อเสนอว่า reference + screenshot critique เหมาะเป็นการทดลองเล็กใน pipeline เดิม; ต่ำสำหรับคุณภาพโดยรวม ต้นทุน ความเร็ว และการเทียบชนะโมเดลอื่น เพราะไม่มีการทำซ้ำบนโปรเจกต์นี้

## ผลนำมาใช้ในเดโม 0.6

ส่วนนี้เป็นงานพัฒนาที่ทำหลังรายงานค้นคว้าข้างต้น ไม่ใช่การทดลองซ้ำของผู้เขียนกระทู้ ติดตั้ง Dream-loop ตามคำสั่งเฉพาะของผู้ใช้จาก commit `9bddb901f7d071cfefdd21e264267c757177a9df` ที่ตรวจแล้ว ลงใน `C:/Users/Admin/.codex/skills/dream-loop` ด้วยตัวติดตั้ง skill แบบดาวน์โหลดไฟล์ ไม่ติดตั้ง dependency ไม่แก้การตั้งค่าส่วนกลาง ไม่เรียก Fal หรือ helper ที่ส่งข้อมูลออกไป SHA-256 ของ `SKILL.md` ที่ติดตั้งคือ `6f736c4d663e5b394fb322035a2d28f197f02372e4479762b127d2c954738054` รวม 13 ไฟล์ 7,024,601 bytes

อ่านคำแนะนำ Pro โดยตรงและใช้เฉพาะวงรอบภาพที่เข้ากับขอบเขตเดโม: สร้าง target จากเมนูเดิมด้วย built-in imagegen แล้วแยกผู้แก้ UI ออกจากผู้ตรวจภาพ ทิศทางภาพคือแฟ้มคำร้องมหาวิทยาลัย สีดำหม่น/กระดาษเก่า/แดงเลือด/ทองบาง ตัวอักษรไทยใหญ่ ปุ่มหลักหนึ่งปุ่ม และรายการรองที่ไม่แย่งภาพปก เก็บ target ที่ `.dream-loop/target.png` เป็นภาพออกแบบภายในและตัดออกจาก export ไม่ใช้เป็นหลักฐานภาพในเกมหรือเพิ่มเข้าแพ็กเกม

ผู้ตรวจรอบแรกพบเมนูเลื่อนเกินจำเป็นที่ 720p ปุ่มบันทึกถูกตัด แผงอาจารย์สูงเกินเนื้อหา และชื่ออาจารย์บังฉาก จึงแก้เฉพาะสี่จุดแล้วจับภาพซ้ำ รายละเอียดและข้อจำกัดใน [รายงานผู้ตรวจ](2026-10-12-polish-review.md) การเปิดเว็บจริงยังพบตัวคั่นที่ฟอนต์ไม่มีแม้ภาพ native ผ่าน จึงแก้ตัวอักษรและเพิ่มกรณีตรวจ font coverage ก่อนส่งออกอีกครั้ง นี่เป็นเหตุผลที่ใช้ภาพจากเว็บประกอบด้วย

แอนิเมชันแก้จากอาการและการวัดคลิปเดิม ได้แก่ ท่าเดินขณะชนผนัง จังหวะเท้าตอนเปลี่ยนเดิน/วิ่ง และจังหวะหมัดกับ damage event ส่วนอาจารย์เพิ่มการเดินร่วม/ต่อยพื้นฐานแยกจากท่า T โดยมีกรณีตรวจทิศทางหมัด ผนังขวาง หยุดเกม และการคืนสถานะ checkpoint ผลการพัฒนาและผลวัดที่ทำจริงอยู่ใน [Verification/v0_6](../../Verification/v0_6/README.md) ไม่ใช้คะแนนจากชุมชนแทนการตรวจเกมนี้ และไม่อ้างว่าวิธีนี้ดีที่สุดกับทุกโปรเจกต์
