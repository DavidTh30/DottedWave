# 10. ไฟล์ข้อมูล

[← กลับสารบัญ](../DEVELOPER_GUIDE.md)

![data flow](data_flow.svg)

## 10.1 ตำแหน่ง

`FindDataDir` หา `data/` จากโฟลเดอร์ของ exe (`bin/../data` สำหรับเกม และ `studio/bin/../../data` สำหรับ Studio) ทั้งสองโปรแกรมจึงใช้ข้อมูลชุดเดียวกัน

## 10.2 ไฟล์ทั้งหมด

| ไฟล์ | เนื้อหา | โครงสร้าง | ฟิลด์ |
|---|---|---|---|
| `data/objects.ini` | วัตถุ | `[Objects] Version, Count` + `[Object0..]` | [ref_objects.md](ref_objects.md) |
| `data/levels.ini` | ด่าน | `[Levels] Version, Count` + `[Level0..]` | [ref_levels.md](ref_levels.md) |
| `data/screens.ini` | 9 หน้าจอ | `[Main] [Levels] [Options] [Pause] [GameOver] [Complete] [Hud] [Ready] [Light]` | [ref_screens.md](ref_screens.md) |
| `data/sfx.ini` | SFX bank | `[Bank] Count` + `[Sfx0..]` key `a.*`, `b.*` | [ref_sound.md](ref_sound.md) |
| `data/music.ini` | เพลง | `[Song]`, `[Track0..7]`, `[Pattern0..]`, `[Section0..]` | [ref_music.md](ref_music.md) |
| `data/light.ini` | แสง 4 แบบ | `[Light0..3]` | [ref_light.md](ref_light.md) |
| `data/anime/` | ภาพของผู้ใช้ | ไฟล์ PNG หรือโฟลเดอร์เฟรม | [07_anime.md](07_anime.md) |
| `bin/waverider.ini` | progress + options | ดู 10.5 | — |

ไฟล์ที่ไม่มีอยู่ → ใช้ค่าเริ่มต้นในโค้ด (`DefaultObjects`, `DefaultLevels`, …) เกมจึงเปิดได้เสมอ

## 10.3 รูปแบบค่า

| ชนิด | ตัวอย่าง |
|---|---|
| ทศนิยม | ใช้จุดเสมอ ไม่ขึ้นกับ locale: `noiseScale=0.0017` |
| enum | ชื่อ: `role=Bonus`, `motion=Homing` (อ่านตัวเลขก็ได้) |
| สี | `#RRGGBB` หรือ `#RRGGBBAA` |
| bool | `0` / `1` |
| Mix | `collectMix=Spark:5 Prism:1 Gem:1 GratingCell:2` |
| Pixel art | แถวคั่นด้วย `/` ตัวอักษร `.` ว่าง, `1` color1, `2` color2, `W` ขาว, `K` ดำ |
| Pattern | `t0=36:8:1 . . . … 36:7:1 …` 32 ช่อง (โน้ต MIDI : ความแรง 1–9 : ความยาว step, `.` = ว่าง) |
| Progression | `progression=0 -4 3 -2` (transpose ต่อรอบ) |

ตัวอย่าง:

```ini
; ตัดมาจาก data/objects.ini จริง (ค่าทศนิยมเขียนตาม decimals ของ descriptor)
name=Magnet
caption=MAGNET
role=Bonus
effect=Magnet
score=25
duration=8.000
power=280.0000
motion=Fall
radius=17.000
style=Ring
colorMode=Fixed
color1=#FF50DC
color2=#78C8FF
letter=M
wellRadius=28.000
wellDarken=-1.2000
ringSpeed=520.00
musicSweep=0.6000
sfx=magnet
```

## 10.4 Migration (`DATA_VERSION = 6`)

การโหลดเริ่มจาก **ค่าเริ่มต้นของวัตถุ/ด่านที่ชื่อตรงกัน** แล้วทับด้วยค่าในไฟล์ ฟิลด์ใหม่ที่ไฟล์เก่าไม่มีจึงได้ค่าที่เหมาะสม

| ไฟล์เก่า | สิ่งที่ทำตอนโหลด |
|---|---|
| objects `Version < 6` | เติมวัตถุใหม่ที่ไม่มีในไฟล์ (Diamond, Spectrum, GratingCell, Gem, …) |
| ทุกเวอร์ชัน | วัตถุ style Gem ที่ไม่ใช่โบนัส Diamond → เปลี่ยนเป็น Star (เพชรเป็นของโบนัส Diamond เท่านั้น) |
| levels `Version < 6` | `ApplyLightDefaults`: เติมโบนัสแสงและ GratingCell ลงใน mix |
| levels `Version < 4` | แทรกด่านอนิเมะ 3 ด่านก่อนด่านสุดท้าย (Endless) |
| ทุกเวอร์ชัน | `lightScene = 0` (ปิดฉากแสงหลังด่านถาวร) |
| sfx | เติมเสียงค่าเริ่มต้นที่ไม่มีใน bank (เช่น charge, grate_fire) |

> **สถานะไฟล์ในเครื่องตอนนี้:** `data/*.ini` ยังเป็นเวอร์ชันแรก (`[Objects] Count=17`, ไม่มี `Version`, ไม่มี `light.ini`) ทุกครั้งที่เปิดเกมจะ migrate ในหน่วยความจำ ค่าที่ใช้จริงจึงอาจต่างจากตารางค่าเริ่มต้นใน `ref_*.md` เล็กน้อย กด **Save all** ใน Studio หนึ่งครั้งเพื่อเขียนไฟล์เป็นเวอร์ชันปัจจุบัน

## 10.5 Progress (`bin/waverider.ini`)

```ini
[Progress]
Unlocked=12          ; จำนวนด่านที่เล่นได้
Best0=7710           ; คะแนนสูงสุดของด่านลำดับ 0
Stars0=3             ; ดาวที่ได้
...
GratingPower=12.00   ; พลัง Grating ที่สะสมไว้
[Options]
Music=80
Sfx=90
Fullscreen=0
LightFx=0            ; ชนิดแสงของโบนัส Spectrum (0 = Dispersion Prism)
AmbientLight=1
```

> คะแนนผูกกับ **ลำดับ** ของด่าน ถ้าแทรกด่านใหม่ คะแนนเดิมจะเลื่อนไปอยู่กับด่านอื่น (ดู [13_extend.md](13_extend.md))
