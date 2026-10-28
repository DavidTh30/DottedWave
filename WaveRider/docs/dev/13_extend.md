# 13. แนวทางพัฒนาต่อ

[← กลับสารบัญ](../DEVELOPER_GUIDE.md)

## 13.1 สูตรเพิ่มของใหม่

### เพิ่มวัตถุ (ไม่ต้อง compile)
1. Studio > Objects & Effects > **+** (หรือ Duplicate ของที่ใกล้เคียง)
2. ตั้ง `name`, `role`, `effect`, `motion`, `style`, สี, เสียง
3. Studio > Levels > ใส่ `ชื่อ:น้ำหนัก` ลงใน `collectMix` / `hazardMix` / `bonusMix` ของด่าน
4. Save แล้วกด F5 ในเกม

### เพิ่มด่าน (ไม่ต้อง compile)
Studio > Levels > **+** ตั้งเวลา ดาว ความเร็ว อัตรา mix สไตล์ mesh แล้ว Save · **ควรเพิ่มต่อท้ายก่อน Endless** เพราะคะแนนผูกกับลำดับ (13.3 ข้อ 2)

### เพิ่มเสียง (ไม่ต้อง compile)
Studio > Sound FX > **+** แล้วใส่ชื่อในฟิลด์ `sfx` ของวัตถุ

### เพิ่ม effect ใหม่ (ต้องเขียนโค้ด)
1. `ugamedata.pas`: เพิ่มชื่อท้าย `EFFECT_NAMES` และค่าคงที่ `EF_ใหม่`
2. ถ้ามีเวลา: ขยาย `FFx: array[EF_SHIELD..EF_ใหม่]` ใน `ugame.pas` และเพิ่มใน `case` ของ `ApplyEffect`
3. เขียน `UpdateXxx(dt)` เรียกใน `Update` ช่วง gsPlaying และ `DrawXxx` เรียกใน `DrawWorld`
4. เพิ่มวัตถุค่าเริ่มต้นใน `DefaultObjects` และเพิ่ม `DATA_VERSION` (ไฟล์เก่าจะได้วัตถุใหม่อัตโนมัติ)
5. ถ้าใช้ mix: แก้ `ApplyLightDefaults` หรือ `DefaultLevels`
6. รัน `tools/docgen` และเพิ่มคำอธิบายใน [04_gameplay.md](04_gameplay.md)

### เพิ่มฟิลด์ข้อมูล
เพิ่มใน record + ค่าเริ่มต้นใน `Default*` + บรรทัด `B.X(...)` ใน `Describe*` → INI, Studio และเอกสาร (docgen) ได้ทันที

### เพิ่มพารามิเตอร์ mesh
enum `TWaveParam` + แถวใน `ParamDefs` (`uwavetypes.pas`) + ใช้ `V[wpXxx]` ใน `uwaveengine.pas` + ค่าใน `PresetConfig`

### เพิ่มตัวละคร chibi
ค่าคงที่ `AN_*` + ชื่อใน `ANIME_NAMES` (ก่อน Party) + palette/อุปกรณ์ใน `DrawChibi` + `DefaultChibiPose` + อัปเดต `animetest`

### เพิ่มหน้าจอเมนู
ค่าใน `TScreenId` + `SCREEN_KEYS` / `SCREEN_NAMES` + `DefaultScreen` + state ใหม่ใน `TGameState` + `ScreenFor` + `BuildMenu` + `MenuActivate`

### เพิ่มแสงแบบใหม่
ชื่อใน `LIGHT_KINDS` + ขยาย `TLightDefs` + `DefaultLightDef` + `BuildKindScene` + **ให้หน้าที่ gameplay หนึ่งอย่าง** (ไม่ใช่ฉากประดับ, ดู [01_origin.md](01_origin.md) 1.3)

## 13.2 ค่าคงที่ที่ปรับบ่อย

| ค่า | ไฟล์ / ตำแหน่ง | ความหมาย |
|---|---|---|
| `SHIP_R = 16`, `MAX_COMBO = 9` | ugame.pas | รัศมียาน, คอมโบสูงสุด |
| `SHOW_SPEED 1.3`, `SHOW_HAZARD 1.6`, `SHOW_COLLECT 1.2` | ugame.pas | ความยาก WATCH BOT |
| `CUTIN_OPACITY = 90` | ugame.pas | ความทึบ cut-in / ข้อความ COMBO |
| `Opacity := 90` | uanime.pas | ความทึบ chibi |
| `FReadyT := 2.4 / 1.8 / 1.2` | ugame.pas | นับถอยหลัง: เริ่มด่าน / CONTINUE / RESUME |
| `PlayTime < 1.2` | ugame.pas `DrawHud` | เวลาจางของป้ายชื่อด่าน |
| `LEAD = 0.9`, `dt × 0.35`, `0.22` | `UpdatePrism` | ทำนาย cursor, ความเร็วตาม, เวลาเผาศัตรู |
| `FNewHP 2..8`, `FNewT 7`, `12 − age`, `dt × 0.9` | `NewtonCombo / UpdateNewton` | HP, เวลา, เวลารวมสูงสุด, ความเร็วตาม |
| `4 + 3·√pool`, `380 + 150·√q`, `1 + q/2` | `UpdateGrating / BuildShot` | อัตราชาร์จ, ระยะ, จำนวน order |
| `dt × 1.15`, `78`, `1100`, `2200` | `UpdateDiamond` | หมุน, ขนาด, ระยะประกาย, ความเร็วดูด |
| `COLS 11`, `ROWS 5`, `HORIZON 1.0`, `STEP 0.1` | `UpdateBot` | ความละเอียดการคิดของบอท |
| `520000` | ugameform.pas `RenderScale` | ความละเอียดภายในสูงสุด |
| `DATA_VERSION = 6` | ugamedata.pas | เวอร์ชันไฟล์ข้อมูล |

## 13.3 ข้อจำกัดที่รู้อยู่

1. **Windows เท่านั้น** — vsync (`uPlatform`) และเสียง (`uAudio`) ยังไม่มีเวอร์ชัน Linux/macOS
2. **คะแนนผูกกับลำดับด่าน** — แทรกด่านกลางรายการแล้วคะแนนเดิมเลื่อน ควรเปลี่ยนเป็นผูกกับชื่อด่าน
3. **ไฟล์ data ในเครื่องยังเป็นเวอร์ชันแรก** — migrate ทุกครั้งที่เปิด (กด Save all ใน Studio)
4. **วาดบน CPU** — จอใหญ่ต้องลดความละเอียดภายใน (`RenderScale`)
5. `TLightLayer.Line` สแกนทีละเส้น รังสีเกิน ~300 ช่วงจะช้า
6. ไม่มี unit test อัตโนมัติ — ใช้ headless + log
7. ยังไม่ได้ทดสอบด้วยการกดจริงครบทุกปุ่ม: ปุ่ม Save/Export หลายปุ่มใน Studio, ตัววาด pixel art
8. ค่าบางอย่างฝังในโค้ด (ตาราง 13.2) ยังแก้ใน Studio ไม่ได้

## 13.4 แนวทางในอนาคต

| ลำดับ | ไอเดีย | งานหลัก |
|---|---|---|
| 1 | ย้าย mesh ไป GPU (GLSL vertex/fragment shader) | รองรับจุดหลักล้าน, 4K เต็มจอ |
| 2 | คะแนนผูกกับชื่อด่าน + กระดานคะแนน / Daily seed | `LoadProgress`, `SaveProgress` |
| 3 | รองรับ Linux | ALSA/SDL audio, `glXSwapIntervalEXT` |
| 4 | จอยสติ๊ก, ตั้งปุ่มเอง | `uGameForm` |
| 5 | บอส: Well ขนาดใหญ่ไล่ตาม + เปลี่ยนเฟสตาม section เพลง | effect ใหม่ + ด่านใหม่ |
| 6 | ค่าคงที่ใน 13.2 ย้ายเป็นข้อมูล (descriptor) | `TGameTuning` + editor |
| 7 | Unit test: `uParams`, migration, sequencer, ray tracing | โปรเจกต์ test แยก |
| 8 | ตัวละคร chibi เพิ่ม + ท่าใหม่ (เช่น Dance) | `uAnime` |
