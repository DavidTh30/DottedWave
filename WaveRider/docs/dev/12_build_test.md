# 12. Build, คำสั่ง และการทดสอบ

[← กลับสารบัญ](../DEVELOPER_GUIDE.md)

## 12.1 สิ่งที่ต้องมี

- Lazarus 3.x + FPC 3.2.2 (Win64) ที่ `C:/lazarus`
- Package: **BGRABitmapPack** (ติดตั้งผ่าน Online Package Manager), **LazOpenGLContext** (มากับ Lazarus)
- Windows (vsync ใช้ `wglSwapIntervalEXT`, เสียงใช้ `winmm.dll`)

## 12.2 Build

```bash
C:/lazarus/lazbuild.exe WaveRider/WaveRider.lpi
```
```bash
C:/lazarus/lazbuild.exe WaveRider/studio/WaveRiderStudio.lpi
```
```bash
C:/lazarus/lazbuild.exe DottedWave/DottedWave.lpi
```

ผลลัพธ์อยู่ใน `WaveRider/bin/` และ `DottedWave/bin/`

## 12.3 คำสั่งของเกม

| คำสั่ง | ผล |
|---|---|
| `WaveRider.exe` | เล่นปกติ |
| `WaveRider.exe --demo N` | เปิดหน้าต่างจริง เล่นด่านลำดับ N (เริ่มที่ 0) แบบ autopilot พร้อม fps |
| `WaveRider.exe --shot out.png [วินาที] [mode] [level]` | headless: จำลองที่ 736×1431, 60 เฟรมต่อวินาทีจำลอง แล้วบันทึก PNG (+ .log บางโหมด) |

**โหมดของ `--shot`** (`level` เริ่มที่ **0** = ด่านแรก)

| mode | ใช้ทำอะไร | log |
|---|---|---|
| `menu`, `levels`, `options`, `light`, `ready`, `pause`, `over`, `complete` | ภาพหน้าจอ | — |
| `play` (ค่าเริ่มต้น) | autopilot เล่นด่าน | จำนวน newton เกิด/ชน, คะแนน, ชีวิต |
| `beam` | ให้โบนัส Spectrum ทุก 4 วินาที (prism sentinel) | เฟรมที่แก้มุมสำเร็จ, ศัตรูที่เผา |
| `diamond` | ให้โบนัส Diamond ทุก 6 วินาที | ของที่ดูดได้ |
| `charge` / `grate` | ทดสอบชาร์จ / ยิง Grating | — |
| `watch` | WATCH BOT ทั้งเกม | สถานะทุก 5 วินาที |
| `showctl` | ทดสอบปุ่ม PAUSE / EXIT, ปุ่ม P, Esc และการคลิก RESUME ของบอท | state หลังแต่ละขั้น + ภาพ `_paused`, `_running` |
| `object` | `SimObject` | — |
| `perf` | วัดเวลาต่อเฟรม (env `ADBG` ปิดบางส่วนเพื่อ profile) | ms ต่อส่วน |

ภาพทั้งหมดใน `docs/img/` สร้างจากคำสั่งเหล่านี้ เช่น

```bash
WaveRider/bin/WaveRider.exe --shot docs/img/play_02_pearl.png 9 play 1
```
```bash
WaveRider/bin/WaveRider.exe --shot docs/img/level_card.png 0.5 play 1
```
```bash
WaveRider/bin/WaveRider.exe --shot docs/img/bot_watch.png 25 watch
```

**ปุ่มลัดในเกม:** F3 = fps, F5 = โหลด data ใหม่ (แก้ใน Studio แล้วกดดูได้ทันที), F11 = เต็มจอ

## 12.4 เครื่องมือ (`WaveRider/tools/`)

| เครื่องมือ | ใช้ทำ | ตัวอย่าง |
|---|---|---|
| `audiotest` | render SFX ทุกเสียงและเพลงเป็น WAV + รายงานความดัง/เบส | `audiotest.exe wav [section]` (ไม่ใส่ `wav` = รายงานอย่างเดียว) |
| `lighttest` | ภาพแสง 4 แบบ + เวลา | `lighttest.exe out.png` |
| `animetest` | ภาพ chibi 4 ตัว | `animetest.exe docs/img/anime_characters.png` |
| **`docgen`** | สร้าง `docs/dev/ref_*.md` จาก descriptor และค่าเริ่มต้นในโค้ด | `docgen.exe ../docs/dev` |
| **`contact`** | รวมภาพหลายภาพเป็นตาราง (overview) | `contact.exe out.png 5 220 a.png b.png …` |

**เมื่อแก้ฟิลด์ ค่าเริ่มต้น หรือเพิ่มวัตถุ/ด่าน ให้รัน `docgen` ใหม่** เอกสารอ้างอิงจะตรงกับโค้ดเสมอ

```bash
C:/lazarus/lazbuild.exe WaveRider/tools/docgen.lpi
```
```bash
cd WaveRider/tools && ./docgen.exe ../docs/dev
```

## 12.5 ประสิทธิภาพที่วัดได้

| สถานการณ์ | ผล |
|---|---|
| engine คลื่น 463×900 | 14.2 ms (เธรดเดียว) → ประมาณ 3 ms (12 เธรด) |
| ด่านปกติ (headless) | 7–9 ms ต่อเฟรม |
| ด่านอนิเมะ (headless) | 11–14 ms ต่อเฟรม |
| หน้าต่างจริง (vsync) | 55–61 fps |
| เพลง | เร็วกว่าเวลาจริงประมาณ 20 เท่า (~5 % ของหนึ่ง core) |
| แสง 4 แบบ (`lighttest`) | 15 ms ทั้ง 4 ฉาก |

## 12.6 การทดสอบที่มี

ยังไม่มี unit test อัตโนมัติ การทดสอบใช้โหมด headless + log:

| ตรวจอะไร | คำสั่ง | ผลล่าสุด |
|---|---|---|
| prism แก้มุมได้ | `--shot x.png 6 beam 1` | 235/324 เฟรม (73 %) |
| diamond ดูดของ | `--shot x.png 3 diamond 1` | ดูดได้ 2 ชิ้นใน 3 วินาที |
| บอทเล่นได้ | `--shot x.png 25 watch` | คอมโบ x9, ไม่เสียชีวิต, 3,200 คะแนนใน 25 วินาที |
| newton | `--shot x.png 9 play 0` | เกิด 1 ครั้ง |
| engine หลายเธรด | เทียบ PNG กับแบบเธรดเดียว | ตรงทุกพิกเซล |
