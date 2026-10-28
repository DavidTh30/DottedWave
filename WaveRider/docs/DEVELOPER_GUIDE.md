# WAVE RIDER — คู่มือนักพัฒนา (ฉบับปรับปรุงใหม่ทั้งหมด)

> ที่มา โครงสร้าง ข้อมูลภายใน และแนวทางพัฒนาต่อ แยกเป็นไฟล์ตามประเภท
> สถานะ ณ 2026-10-21 · Lazarus 3.x / FPC 3.2.2 Win64 · BGRABitmap · OpenGL + vsync
> ฉบับนี้เขียนทับฉบับก่อนหน้าทั้งหมด ภาพหน้าจอทุกภาพถ่ายใหม่จากโค้ดปัจจุบัน และตารางอ้างอิงสร้างจากโค้ดโดยตรง

![ภาพรวมหน้าจอ](img/overview_screens.png)

---

## เอกสารแยกตามประเภท

| # | หมวด | ไฟล์ | เนื้อหา |
|---|---|---|---|
| 1 | ที่มา | [01_origin.md](dev/01_origin.md) | ภาพต้นแบบ ลำดับการพัฒนา คำขอของผู้ใช้ทุกข้อ และเหตุผลของการตัดสินใจ |
| 2 | สถาปัตยกรรม | [02_architecture.md](dev/02_architecture.md) | โฟลเดอร์ unit ทั้งหมด การพึ่งพา เธรด ลำดับต่อเฟรม ระบบพิกัด |
| 3 | Engine คลื่นจุด | [03_engine.md](dev/03_engine.md) | อัลกอริทึม Dotted Wave Mesh, Iridescent, hook ที่เกมใช้ |
| 4 | Gameplay | [04_gameplay.md](dev/04_gameplay.md) | สถานะเกม ป้ายชื่อด่าน ยาน คอมโบ คะแนน การเกิดวัตถุ effect ดาว progress |
| 5 | แสง 4 แบบ | [05_lightfx.md](dev/05_lightfx.md) | ฟิสิกส์ ray tracing และหน้าที่ของ Prism / Newton / Grating / Diamond |
| 6 | WATCH BOT | [06_bot.md](dev/06_bot.md) | สมองบอท Super Hard, การควบคุม, ความยาก |
| 7 | ด่านอนิเมะ | [07_anime.md](dev/07_anime.md) | ตัวละคร chibi 4 ตัว ท่า 4 แบบ เธรดวาด ความโปร่งแสง |
| 8 | เสียงและเพลง | [08_audio.md](dev/08_audio.md) | synth, SFX 25 เสียง, เพลง Pearl Pressure, เพลงตอบสนองเกม |
| 9 | หน้าจอและ UI | [09_ui.md](dev/09_ui.md) | เมนู ตัวอักษร Dotted Iridescent Pearl, HUD, เมาส์/คีย์บอร์ด |
| 10 | ไฟล์ข้อมูล | [10_data_files.md](dev/10_data_files.md) | รูปแบบ INI ทุกไฟล์, migration, progress |
| 11 | Studio | [11_studio.md](dev/11_studio.md) | 6 editor พร้อม simulation |
| 12 | Build และทดสอบ | [12_build_test.md](dev/12_build_test.md) | คำสั่ง build, โหมด headless, เครื่องมือ, ประสิทธิภาพที่วัดได้ |
| 13 | พัฒนาต่อ | [13_extend.md](dev/13_extend.md) | สูตรเพิ่มของใหม่ทีละขั้น ค่าคงที่ ข้อจำกัด แนวทางในอนาคต |

### ตารางอ้างอิง (สร้างอัตโนมัติด้วย `tools/docgen`)

| ไฟล์ | เนื้อหา |
|---|---|
| [ref_mesh.md](dev/ref_mesh.md) | พารามิเตอร์ mesh 37 ตัว + ค่าของ preset ทั้ง 8 แบบ |
| [ref_objects.md](dev/ref_objects.md) | ฟิลด์วัตถุ 38 ฟิลด์ + วัตถุค่าเริ่มต้น 21 ชนิด |
| [ref_levels.md](dev/ref_levels.md) | ฟิลด์ด่าน 43 ฟิลด์ + 14 ด่าน + spawn mix |
| [ref_screens.md](dev/ref_screens.md) | ฟิลด์หน้าจอ 35 ฟิลด์ + ค่าของ 9 หน้าจอ |
| [ref_sound.md](dev/ref_sound.md) | ฟิลด์เสียง 72 ฟิลด์ + SFX 25 เสียง |
| [ref_music.md](dev/ref_music.md) | เพลง, track 8 ช่อง, section, pattern, ฟิลด์เครื่องดนตรี |
| [ref_light.md](dev/ref_light.md) | ฟิลด์แสง 19 ฟิลด์ + ค่า 4 แบบ |

### แผนภาพ (docs/dev/*.svg)

| แผนภาพ | ใช้ในหมวด |
|---|---|
| [architecture.svg](dev/architecture.svg) | 2 สถาปัตยกรรม |
| [frame_pipeline.svg](dev/frame_pipeline.svg) | 2 สถาปัตยกรรม |
| [data_flow.svg](dev/data_flow.svg) | 2, 10 ข้อมูล |
| [state_machine.svg](dev/state_machine.svg) | 4 Gameplay |
| [level_lifecycle.svg](dev/level_lifecycle.svg) | 4 Gameplay |
| [combo_hub.svg](dev/combo_hub.svg) | 4 Gameplay |
| [light_physics.svg](dev/light_physics.svg) | 5 แสง |
| [bot_brain.svg](dev/bot_brain.svg) | 6 บอท |
| [anime_director.svg](dev/anime_director.svg) | 7 อนิเมะ |
| [audio_pipeline.svg](dev/audio_pipeline.svg) | 8 เสียง |

### ภาพหน้าจอ (docs/img/*.png)

ภาพขนาดจริง 736×1431 ถ่ายด้วย `WaveRider.exe --shot` (ดู [12_build_test.md](dev/12_build_test.md))

| กลุ่ม | ไฟล์ |
|---|---|
| หน้าจอ | `screen_menu`, `screen_levels`, `screen_options`, `screen_light_lab`, `screen_ready`, `level_card`, `screen_pause`, `screen_complete`, `screen_gameover` |
| ด่าน 14 ด่าน | `play_01_calm` … `play_14_endless` |
| แสง | `fx_prism_sentinel`, `fx_newton_guardian`, `fx_grating_charge`, `fx_grating_fire`, `fx_diamond` |
| บอท | `bot_watch` (+ `bot_watch.log`) |
| อนิเมะ | `anime_characters`, `anime_peek_mimi`, `anime_party_kuma`, `anime_cutin_neko`, `anime_pop_ao`, `anime_side_ao` |
| ภาพรวม | `overview_screens`, `overview_levels`, `overview_lightfx`, `overview_anime` |

---

## สรุปใน 1 หน้า

- **3 โปรแกรม** ใช้ engine เดียวกัน: `WaveRider.exe` (เกม), `WaveRiderStudio.exe` (6 editor), `DottedWave.exe` (ปรับ mesh)
- **Data-driven ทั้งหมด:** วัตถุ ด่าน หน้าจอ เสียง เพลง แสง อยู่ใน `data/*.ini` แก้ใน Studio ได้โดยไม่ต้อง compile
- **วาดบน CPU ทั้งหมด** ด้วย BGRABitmap แล้วส่งขึ้น OpenGL เป็น texture เดียวต่อเฟรม `SwapBuffers` รอ vblank
- **เสียงสังเคราะห์เอง** ผ่าน `winmm.dll` ไม่มี DLL ภายนอก ไม่มีไฟล์เสียงหรือภาพประกอบจากภายนอก
- **ขนาดโค้ด:** engine 2,321 · เกม 10,063 · Studio 3,907 · tools ~600 บรรทัด

![ทุกด่าน](img/overview_levels.png)
