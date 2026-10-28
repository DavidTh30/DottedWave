# อ้างอิง: ด่าน (Levels)

> ที่มา `src/ugamedata.pas` — `TLevelDef`, `DescribeLevel`, `DefaultLevels`

## ฟิลด์ทั้งหมดของด่าน (`TLevelDef`, 43 ฟิลด์)

section ใน `data/levels.ini`: `[Level0]`, `[Level1]` ... · ค่าเริ่มต้นจาก `DefaultLevel`

**Level**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `name` | Name | string | text | `New Level` |  |
| `subtitle` | Subtitle | string | text | `` |  |
| `difficulty` | Difficulty | enum | Easy / Normal / Hard / Expert / Insane | `Normal` |  |
| `duration` | Duration (s) | float | 0 .. 900 | `60` | 0 = endless |
| `lives` | Lives | int | 1 .. 9 | `3` |  |
| `star1` | Score for 1 star | int | 0 .. 1000000 | `1000` |  |
| `star2` | Score for 2 stars | int | 0 .. 1000000 | `2500` |  |
| `star3` | Score for 3 stars | int | 0 .. 1000000 | `5000` |  |

**Style**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `mesh` | Mesh preset | enum | Original / Calm Silk / Storm / Dense Fabric / Sound Wave ... | `Original` |  |
| `lines` | Lines override | int | 0 .. 300 | `0` | 0 = keep preset |
| `amplitude` | Amplitude override | float | 0.0 .. 250.0 | `0` | 0 = keep preset |
| `iriBase` | Base iridescence | float | 0.00 .. 1.00 | `0` | Combo adds on top |
| `iriPalette` | Iridescent palette | enum | Rainbow / Pearl / Oil Slick / Holographic / Beetle / Mono | `Rainbow` |  |
| `bg` | Background | color | #RRGGBB[AA] | `#000000` |  |
| `dots` | Dot color | color | #RRGGBB[AA] | `#F2F2F2` |  |
| `vignette` | Vignette | float | 0.00 .. 1.50 | `0.45` |  |
| `pixel` | Pixel art mode | bool | 0 / 1 | `0` |  |
| `pixelSize` | Pixel size | int | 2 .. 12 | `4` |  |
| `posterize` | Posterize levels | int | 0 .. 16 | `0` | 0 = off. Low values = retro palette |

**Pace**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `speedStart` | Speed start | float | 50 .. 1200 | `240` | Surface flow, reference px / s |
| `speedEnd` | Speed end | float | 50 .. 1500 | `420` |  |
| `collectRate` | Collectibles / s | float | 0.00 .. 8.00 | `1.4` |  |
| `hazardRate` | Hazards / s | float | 0.00 .. 8.00 | `0.5` |  |
| `bonusRate` | Bonuses / s | float | 0.000 .. 2.000 | `0.05` |  |
| `rateRamp` | Rate ramp (x at end) | float | 0.20 .. 6.00 | `1.8` |  |
| `chain` | Chain chance | float | 0.00 .. 1.00 | `0.25` | Collectibles spawn as a curved chain |
| `collectMix` | Collect mix | string | text | `Spark:1` | Object:weight ... e.g. "Spark:5 Prism:1" |
| `hazardMix` | Hazard mix | string | text | `Void:1` |  |
| `bonusMix` | Bonus mix | string | text | `Pulse:1` |  |

**Music**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `musicSection` | Start section | int | 0 .. 63 | `1` |  |

**Light FX (background optics)**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `lightScene` | Light scene | enum | None / Dispersion Prism / Newton's Prisms / Diffraction G... | `None` | Prism / Newton / grating / diamond lit behind the level |
| `lightX` | Light X (0..1) | float | -0.500 .. 1.500 | `0.5` |  |
| `lightY` | Light Y (0..1) | float | -0.500 .. 1.500 | `0.32` |  |
| `lightScale` | Light scale | float | 20 .. 400 | `110` |  |
| `lightIntensity` | Light intensity | float | 0.00 .. 2.00 | `0.55` |  |

**Anime (character drawn by the dots)**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `anime` | Character | enum | None / Mimi / Kuma / Neko / Ao / Party / Image | `None` | Mimi / Kuma / Neko / Ao / Party are built-in chibis. Imag... |
| `animeImage` | Image file | string | text | `` | PNG / JPG in data/anime/ (transparent background works best) |
| `animeMix` | Dot mix | float | 0.00 .. 1.00 | `0.9` | How strongly the dots take the picture |
| `animeX` | Center X (0..1) | float | -0.500 .. 1.500 | `0.5` |  |
| `animeY` | Center Y (0..1) | float | -0.500 .. 1.500 | `0.5` |  |
| `animeScale` | Height (screen) | float | 0.10 .. 2.00 | `0.78` |  |
| `animePan` | Camera pan | float | 0.00 .. 3.00 | `1` | Slow anime-style camera drift / zoom |
| `animeCutIn` | Cut-ins on combo / bonus | bool | 0 / 1 | `1` |  |

## ด่านค่าเริ่มต้น 14 ด่าน (`DefaultLevels`)

| # | name | subtitle | ระดับ | mesh | pixel | เวลา (s) | ชีวิต | ดาว 1/2/3 | ความเร็ว | collect/hazard/bonus rate | ramp | chain | music | anime |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Calm Waters** | Learn to ride the dots | Easy | Original | - | 45 | 3 | 600/1500/3000 | 200→300 | 1.4 / 0.3 / 0.05 | 1.8 | 0.25 | 0 | None |
| 2 | **Pearl Drift** | Combo lights up the pearl | Easy | Iridescent Pearl | - | 60 | 3 | 1200/3000/6000 | 220→340 | 1.4 / 0.5 / 0.05 | 1.8 | 0.25 | 1 | None |
| 3 | **8-Bit Tide** | Pixel art waves | Normal | Sound Wave | ใช่ (4 px) | 60 | 3 | 1200/3000/6000 | 240→380 | 1.4 / 0.5 / 0.05 | 1.8 | 0.25 | 2 | None |
| 4 | **Silk Storm** | Seekers hunt the light | Normal | Calm Silk | - | 75 | 3 | 2000/4500/8000 | 260→440 | 1.4 / 0.6 / 0.05 | 1.8 | 0.25 | 2 | None |
| 5 | **Holo Rush** | Comets incoming | Hard | Holographic | - | 75 | 3 | 2500/6000/11000 | 300→520 | 1.4 / 0.75 / 0.05 | 1.8 | 0.25 | 5 | None |
| 6 | **Pixel Abyss** | Glitches in the dark | Hard | Original | ใช่ (5 px) | 80 | 3 | 2500/6000/10000 | 280→500 | 1.4 / 0.8 / 0.05 | 1.8 | 0.25 | 3 | None |
| 7 | **Oil Slick** | Twin voids orbit | Hard | Oil Slick | - | 90 | 3 | 3000/7000/13000 | 300→560 | 1.4 / 0.8 / 0.05 | 1.8 | 0.25 | 5 | None |
| 8 | **Dense Fabric** | Threads of danger | Expert | Dense Fabric | - | 90 | 3 | 4000/9000/16000 | 340→620 | 1.4 / 1 / 0.05 | 1.8 | 0.25 | 6 | None |
| 9 | **Neon Arcade** | 8-bit at full speed | Expert | Holographic | ใช่ (3 px) | 90 | 3 | 5000/11000/20000 | 380→680 | 1.4 / 1.1 / 0.05 | 1.8 | 0.25 | 7 | None |
| 10 | **The Maelstrom** | Everything, all at once | Insane | Storm | - | 120 | 3 | 8000/18000/32000 | 420→760 | 1.4 / 1.3 / 0.05 | 2.2 | 0.25 | 7 | None |
| 11 | **Anime Rush** | Chibi party on the dots | Normal | Dense Fabric | - | 70 | 3 | 2000/4500/8000 | 240→400 | 1.4 / 0.55 / 0.05 | 1.8 | 0.25 | 2 | Party |
| 12 | **Neon Idol** | Neko steals the show | Hard | Dense Fabric | - | 80 | 3 | 3000/7000/12000 | 300→520 | 1.4 / 0.8 / 0.05 | 1.8 | 0.25 | 5 | Neko |
| 13 | **Blade Wind** | Ao says peace! | Expert | Dense Fabric | - | 90 | 3 | 4000/9000/16000 | 340→640 | 1.4 / 1.05 / 0.05 | 1.8 | 0.25 | 7 | Ao |
| 14 | **Endless** | How long can you ride? | Insane | Iridescent Pearl | - | ไม่จำกัด | 3 | 5000/15000/40000 | 260→820 | 1.4 / 0.6 / 0.05 | 3 | 0.25 | 1 | None |

## ส่วนผสมการเกิดวัตถุ (spawn mix) ของแต่ละด่าน

รูปแบบ `ชื่อ:น้ำหนัก` คั่นด้วยช่องว่าง โอกาสเกิด = น้ำหนัก / ผลรวมน้ำหนักในกลุ่ม

| name | collectMix | hazardMix | bonusMix |
|---|---|---|---|
| Calm Waters | Spark:1 GratingCell:2 | Void:1 | Pulse:2 Shield:1 Star:1 Diamond:1 |
| Pearl Drift | Spark:5 Prism:1 Gem:1 GratingCell:2 | Void:1 | Pulse:2 Shield:1 Star:1 Double:1 Spectrum:1 Diamond:1 |
| 8-Bit Tide | Coin:4 Spark:1 GratingCell:2 | Glitch:2 Void:1 | OneUp:1 Pulse:2 Double:1 Diamond:1 Spectrum:1 |
| Silk Storm | Spark:6 Prism:1 GratingCell:2 | Void:3 Seeker:1 | Pulse:2 Shield:2 Magnet:1 Star:1 Diamond:1 Spectrum:1 |
| Holo Rush | Spark:4 Prism:2 GratingCell:2 Gem:1 | Void:2 Comet:2 Seeker:1 | Pulse:2 Shield:1 Magnet:1 SlowMo:1 Double:1 Star:1 Diamond:1 Spectrum:1 |
| Pixel Abyss | Coin:3 Spark:2 GratingCell:2 Gem:1 | Glitch:3 Void:2 Twin:1 | OneUp:1 Pulse:2 Shield:1 SlowMo:1 Nova:1 Diamond:1 Spectrum:1 |
| Oil Slick | Spark:4 Prism:2 GratingCell:2 Gem:1 | Void:2 Twin:2 Seeker:1 | Pulse:2 Shield:1 Magnet:1 Fever:1 Double:1 Diamond:1 Spectrum:1 |
| Dense Fabric | Spark:3 Prism:2 GratingCell:2 Gem:1 | Void:2 Seeker:2 Comet:2 Twin:1 | Pulse:2 Shield:2 SlowMo:1 Fever:1 OneUp:1 Nova:1 Diamond:1 Spectrum:1 |
| Neon Arcade | Coin:3 Prism:1 GratingCell:2 Gem:1 | Glitch:3 Comet:2 Seeker:1 | OneUp:1 Pulse:2 Fever:1 Double:1 Nova:1 Magnet:1 Diamond:1 Spectrum:1 |
| The Maelstrom | Spark:3 Prism:2 Coin:1 GratingCell:2 Gem:1 | Void:3 Seeker:2 Comet:2 Twin:2 Glitch:1 | Pulse:2 Shield:2 Magnet:1 SlowMo:1 Double:1 OneUp:1 Fever:1 Nova:1 Star:1 Diamond:1 Spectrum:1 |
| Anime Rush | Spark:5 Prism:1 GratingCell:2 | Void:3 Seeker:1 | Pulse:2 Shield:1 Star:1 Spectrum:1 Diamond:1 |
| Neon Idol | Spark:4 Gem:1 GratingCell:2 | Void:2 Comet:2 Twin:1 | Pulse:2 Fever:1 Double:1 Spectrum:1 Star:1 Diamond:1 |
| Blade Wind | Spark:3 Prism:2 GratingCell:2 Gem:1 | Void:2 Seeker:2 Comet:2 Glitch:1 | Pulse:2 Shield:2 SlowMo:1 Nova:1 Spectrum:1 Diamond:1 |
| Endless | Spark:4 Prism:1 Coin:1 GratingCell:2 Gem:1 | Void:3 Seeker:2 Comet:2 Twin:1 Glitch:1 | Pulse:2 Shield:2 Magnet:1 SlowMo:1 Double:1 OneUp:1 Fever:1 Nova:1 Star:1 Diamond:1 Spectrum:1 |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
