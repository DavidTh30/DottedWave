# อ้างอิง: วัตถุในเกม (Objects & Effects)

> ที่มา `src/ugamedata.pas` — `TObjDef`, `DescribeObject`, `DefaultObjects`

## ฟิลด์ทั้งหมดของวัตถุ (`TObjDef`, 38 ฟิลด์)

section ใน `data/objects.ini`: `[Object0]`, `[Object1]` ... · ค่าเริ่มต้นในตารางนี้มาจาก `DefaultObject(name)` ก่อนแต่ละวัตถุตั้งค่าเฉพาะ

**Identity**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `name` | Name (id) | string | text | `Field` | Referenced by levels (spawn mixes) |
| `caption` | Caption | string | text | `FIELD` | Shown in the HUD when picked up |
| `role` | Role | enum | Collect / Hazard / Bonus | `Collect` |  |
| `effect` | Effect | enum | Score / ClearHazards / Shield / Magnet / SlowMo / DoubleS... | `Score` |  |
| `score` | Score | int | 0 .. 100000 | `10` |  |
| `duration` | Duration (s) | float | 0.0 .. 60.0 | `8` | Timed bonuses: shield, magnet, slow-mo, double, fever |
| `power` | Power | float | 0.00 .. 2000.00 | `1` | Magnet radius / slow-mo factor / score multiplier / homin... |

**Motion**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `motion` | Motion | enum | Fall / Sine / ZigZag / Homing / Orbit / Fast / Drift | `Fall` |  |
| `speed` | Fall speed x | float | 0.10 .. 4.00 | `1` |  |
| `motionAmp` | Motion amplitude | float | 0.0 .. 300.0 | `20` |  |
| `motionFreq` | Motion frequency | float | 0.00 .. 10.00 | `2` |  |
| `radius` | Radius | float | 4.0 .. 80.0 | `14` | Collision radius (reference px) |

**Look**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `style` | Style | enum | Orb / Ring / Void / Triangle / Star / Pixel / Comet / Pri... | `Orb` |  |
| `colorMode` | Color mode | enum | Fixed / HueCycle / Pearl / Holo / Oil / Rainbow / Beetle | `HueCycle` |  |
| `color1` | Color 1 | color | #RRGGBB[AA] | `#FFFFFF` |  |
| `color2` | Color 2 | color | #RRGGBB[AA] | `#78C8FF` |  |
| `letter` | Letter | string | text | `` | Drawn in the center (bonuses) |
| `glowSize` | Glow size | float | 0.0 .. 120.0 | `34` |  |
| `glowAlpha` | Glow strength | float | 0.00 .. 2.00 | `1` |  |
| `pulseRate` | Pulse rate | float | 0.0 .. 30.0 | `8` |  |
| `spin` | Spin | float | -10.00 .. 10.00 | `0` |  |
| `pixelArt` | Pixel art | string | text | `` | Rows split by "/": . empty, 1 color1, 2 color2, W white, ... |
| `pixelScale` | Pixel scale | float | 1.0 .. 12.0 | `4` |  |

**Surface effect (mesh)**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `wellRadius` | Well radius | float | 0.0 .. 300.0 | `28` | Deformation of the dotted surface around the object |
| `wellHeight` | Well height | float | -3.00 .. 3.00 | `0.3` | Negative = pit, positive = bump |
| `wellDarken` | Well darken | float | -3.00 .. 1.00 | `-1.2` | Positive swallows light, negative makes dots glow |

**Pickup / hit effect**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `ringSpeed` | Ring speed | float | 0 .. 2000 | `520` |  |
| `ringWidth` | Ring width | float | 5.0 .. 200.0 | `26` |  |
| `ringStrength` | Ring strength | float | -3.00 .. 3.00 | `0.55` |  |
| `ringDecay` | Ring decay | float | 0.20 .. 6.00 | `2.2` |  |
| `particles` | Particles | int | 0 .. 200 | `14` |  |
| `particleSpeed` | Particle speed | float | 0 .. 1500 | `260` |  |
| `particleSize` | Particle size | float | 1.0 .. 12.0 | `3` |  |
| `shake` | Screen shake | float | 0.00 .. 2.00 | `0` |  |
| `flash` | Screen flash | float | 0.00 .. 1.00 | `0` |  |
| `musicSweep` | Music sweep | float | 0.00 .. 1.00 | `0` | Filter sweep + echo throw in the music |
| `sfx` | Sound | string | text | `collect` | Name in sfx.ini |
| `sfxPitch` | Sound pitch | float | 0.25 .. 4.00 | `1` |  |

## วัตถุค่าเริ่มต้น 21 ชนิด (`DefaultObjects`)

| # | name | role | effect | motion | style | colorMode | radius | speed | score | duration | power | letter | sfx | particles | shake |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | **Spark** | Collect | Score | Sine | Orb | HueCycle | 13 | 1 | 10 | 8 | 1 |  | collect | 14 | 0 |
| 1 | **Prism** | Collect | Score | ZigZag | Triangle | Holo | 15 | 1.15 | 40 | 8 | 1 |  | prism | 22 | 0 |
| 2 | **Coin** | Collect | Score | Sine | Pixel | Fixed | 15 | 1 | 20 | 8 | 1 |  | collect | 14 | 0 |
| 3 | **Void** | Hazard | Damage | Drift | Void | HueCycle | 27 | 0.85 | 0 | 8 | 1 |  | hit | 18 | 1 |
| 4 | **Seeker** | Hazard | Damage | Homing | Void | Fixed | 22 | 0.7 | 0 | 8 | 140 |  | hit | 14 | 1 |
| 5 | **Comet** | Hazard | Damage | Fast | Comet | Fixed | 13 | 2.3 | 0 | 8 | 1 |  | hit | 14 | 0.8 |
| 6 | **Twin** | Hazard | Damage | Orbit | Void | Oil | 18 | 0.8 | 0 | 8 | 1 |  | hit | 14 | 1 |
| 7 | **Glitch** | Hazard | Damage | ZigZag | Pixel | Fixed | 18 | 1 | 0 | 8 | 1 |  | hit | 14 | 1 |
| 8 | **Pulse** | Bonus | ClearHazards | Fall | Ring | HueCycle | 18 | 1 | 50 | 8 | 1 | P | pulse | 40 | 0.4 |
| 9 | **Shield** | Bonus | Shield | Fall | Ring | Fixed | 17 | 1 | 25 | 8 | 1 | S | shield | 14 | 0 |
| 10 | **Magnet** | Bonus | Magnet | Fall | Ring | Fixed | 17 | 1 | 25 | 8 | 280 | M | magnet | 14 | 0 |
| 11 | **SlowMo** | Bonus | SlowMo | Fall | Ring | Fixed | 17 | 1 | 25 | 6 | 0.55 | T | slowmo | 14 | 0 |
| 12 | **Double** | Bonus | DoubleScore | Fall | Ring | Fixed | 17 | 1 | 25 | 10 | 2 | 2x | double | 14 | 0 |
| 13 | **OneUp** | Bonus | ExtraLife | Fall | Pixel | Fixed | 16 | 1 | 100 | 8 | 1 |  | life | 14 | 0 |
| 14 | **Star** | Bonus | Score | Fall | Star | Pearl | 18 | 1 | 500 | 8 | 1 |  | star | 40 | 0 |
| 15 | **Fever** | Bonus | Fever | Fall | Star | Rainbow | 18 | 1 | 100 | 6 | 1 | F | fever | 50 | 0 |
| 16 | **Nova** | Bonus | Nova | Fall | Pixel | Fixed | 17 | 1 | 150 | 8 | 1 |  | nova | 70 | 0.8 |
| 17 | **GratingCell** | Collect | GratingPower | Sine | Grating | Holo | 13 | 1 | 5 | 8 | 1 |  | collect | 10 | 0 |
| 18 | **Diamond** | Bonus | DiamondLight | Fall | Gem | Pearl | 18 | 1 | 40 | 5 | 1 |  | prism | 40 | 0 |
| 19 | **Spectrum** | Bonus | LightBeam | Fall | Prism | Holo | 18 | 1 | 50 | 5 | 1 |  | beam | 36 | 0 |
| 20 | **Gem** | Collect | Score | Sine | Star | Pearl | 15 | 1 | 60 | 8 | 1 |  | prism | 24 | 0 |

## ลักษณะ (look) และสีของแต่ละวัตถุ

| name | caption | color1 | color2 | glowSize | glowAlpha | pulseRate | spin | wellRadius | wellHeight | ringStrength | flash | musicSweep | pixelArt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Spark | SPARK | #FFFFFF | #78C8FF | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0 | - |
| Prism | PRISM | #FFFFFF | #78C8FF | 40 | 1 | 8 | 2 | 28 | 0.3 | 0.7 | 0 | 0 | - |
| Coin | COIN | #FFC828 | #AA640A | 26 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0 | มี (71 ตัวอักษร) |
| Void | VOID | #FFFFFF | #78C8FF | 0 | 1 | 8 | 0 | 84 | -1.5 | 0.7 | 0.6 | 0 | - |
| Seeker | SEEKER | #FF3C50 | #78C8FF | 30 | 1 | 8 | 0 | 66 | -1.2 | 0.55 | 0.6 | 0 | - |
| Comet | COMET | #C8E6FF | #78C8FF | 36 | 1 | 8 | 0 | 40 | 0.8 | 0.55 | 0.5 | 0 | - |
| Twin | TWIN | #FFFFFF | #78C8FF | 0 | 1 | 8 | 0 | 56 | -1.2 | 0.55 | 0.6 | 0 | - |
| Glitch | GLITCH | #FF285A | #5A0028 | 24 | 1 | 8 | 0 | 50 | -1 | 0.55 | 0.6 | 0 | มี (71 ตัวอักษร) |
| Pulse | PULSE | #FFFFFF | #78C8FF | 34 | 1 | 8 | 0 | 45 | 0.6 | 1.1 | 0.35 | 1 | - |
| Shield | SHIELD | #50DCFF | #78C8FF | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0.6 | - |
| Magnet | MAGNET | #FF50DC | #78C8FF | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0.6 | - |
| SlowMo | SLOW-MO | #5A8CFF | #78C8FF | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0.4 | - |
| Double | DOUBLE SCORE | #FFC828 | #78C8FF | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0.7 | - |
| OneUp | 1-UP | #5AFF8C | #14783C | 34 | 1 | 8 | 0 | 28 | 0.3 | 0.55 | 0 | 0.8 | มี (62 ตัวอักษร) |
| Star | STAR | #FFE678 | #78C8FF | 48 | 1 | 8 | 1.5 | 28 | 0.3 | 0.9 | 0 | 0.8 | - |
| Fever | FEVER | #FFFFFF | #78C8FF | 52 | 1 | 8 | 3 | 28 | 0.3 | 0.55 | 0.3 | 1 | - |
| Nova | NOVA | #FF7828 | #FFF078 | 34 | 1 | 8 | 0 | 28 | 0.3 | 1.4 | 0.6 | 1 | มี (71 ตัวอักษร) |
| GratingCell | GRATING | #FFFFFF | #78C8FF | 30 | 1 | 8 | 0 | 28 | 0.3 | 0.35 | 0 | 0 | - |
| Diamond | DIAMOND LIGHT | #FFFFFF | #78C8FF | 50 | 1 | 8 | 1.6 | 28 | 0.3 | 0.9 | 0.3 | 1 | - |
| Spectrum | LIGHT BEAM | #FFFFFF | #78C8FF | 46 | 1 | 8 | 1.2 | 28 | 0.3 | 0.9 | 0.4 | 1 | - |
| Gem | GEM | #FFFFFF | #78C8FF | 38 | 1 | 8 | 1.4 | 28 | 0.3 | 0.55 | 0 | 0 | - |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
