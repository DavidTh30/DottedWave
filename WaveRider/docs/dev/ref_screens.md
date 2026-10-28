# อ้างอิง: หน้าจอและเมนู (Menu & Screen FX)

> ที่มา `src/ugamedata.pas` — `TScreenFx`, `DescribeScreen`, `DefaultScreen`

## ฟิลด์ของหน้าจอ (`TScreenFx`, 35 ฟิลด์)

section ใน `data/screens.ini`: `[Main] [Levels] [Options] [Pause] [GameOver] [Complete] [Hud] [Ready] [Light]`

**Title (dotted iridescent)**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `title` | Title | string | text |  |
| `subtitle` | Subtitle | string | text |  |
| `titleSize` | Title size | float | 10 .. 220 |  |
| `titleY` | Title Y (0..1) | float | 0.000 .. 1.000 |  |
| `dotSpacing` | Dot spacing | float | 1.50 .. 12.00 | Grid step of the dotted letters (reference px) |
| `dotSize` | Dot size | float | 0.50 .. 10.00 |  |
| `dotRound` | Round dots | bool | 0 / 1 |  |
| `dotWave` | Dot wave | float | 0.0 .. 30.0 | Vertical wave through the letters |
| `dotWaveFreq` | Dot wave freq | float | 0.000 .. 0.500 |  |
| `dotWaveSpeed` | Dot wave speed | float | 0.00 .. 20.00 |  |
| `shimmer` | Shimmer | float | 0.00 .. 1.00 | Pearl light sweep |
| `shimmerSpeed` | Shimmer speed | float | 0.00 .. 4.00 |  |
| `palette` | Palette | enum | Rainbow / Pearl / Oil Slick / Holographic / Beetle / Mono |  |
| `saturation` | Saturation | float | 0.00 .. 1.50 |  |
| `hueSpeed` | Hue speed | float | 0.000 .. 2.000 |  |
| `hueScale` | Hue scale | float | 0.00 .. 6.00 |  |
| `glow` | Glow | float | 0.00 .. 1.50 |  |
| `textColor` | Text color | color | #RRGGBB[AA] |  |

**Background**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `bgPreset` | Mesh preset | enum | Original / Calm Silk / Storm / Dense Fabric / Sound Wave ... |  |
| `bgIri` | Iridescence | float | 0.00 .. 1.00 |  |
| `bgDim` | Dim | float | 0.00 .. 1.00 |  |
| `bgSpeed` | Flow speed | float | 0 .. 800 |  |
| `particles` | Ambient pixels | int | 0 .. 300 |  |

**Menu**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `menuY` | Menu Y (0..1) | float | 0.000 .. 1.000 |  |
| `menuSize` | Item size | float | 8 .. 90 |  |
| `menuSpacing` | Item spacing | float | 10 .. 160 |  |
| `menuColor` | Item color | color | #RRGGBB[AA] |  |
| `menuSelMode` | Selected color | enum | Fixed / HueCycle / Pearl / Holo / Oil / Rainbow / Beetle |  |
| `menuDotted` | Dotted selected item | bool | 0 / 1 |  |
| `menuGlow` | Selection glow | float | 0.00 .. 1.50 |  |

**Light FX**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `lightFx` | Light scene | enum | None / Dispersion Prism / Newton's Prisms / Diffraction G... | Optics drawn behind this screen |
| `lightX` | Light X (0..1) | float | -0.500 .. 1.500 |  |
| `lightY` | Light Y (0..1) | float | -0.500 .. 1.500 |  |
| `lightSize` | Light size | float | 20 .. 400 |  |
| `lightIntensity` | Light intensity | float | 0.00 .. 2.00 |  |

## ค่าเริ่มต้นของทั้ง 9 หน้าจอ (`DefaultScreen`)

| key | Main | Levels | Options | Pause | GameOver | Complete | Hud | Ready | Light |
|---|---|---|---|---|---|---|---|---|---|
| `title` | WAVE RIDER | SELECT LEVEL | OPTIONS | PAUSED | GAME OVER | LEVEL CLEAR |  | READY | LIGHT LAB |
| `subtitle` | Ride the dotted light |  |  |  |  |  |  |  | Choose the light of your beam |
| `titleSize` | 92 | 56 | 64 | 72 | 74 | 70 | 46 | 110 | 50 |
| `titleY` | 0.24 | 0.07 | 0.12 | 0.28 | 0.22 | 0.2 | 0.24 | 0.36 | 0.02 |
| `dotSpacing` | 3.2 | 3.2 | 3.2 | 3.2 | 3.2 | 3.2 | 3.2 | 3.2 | 3.2 |
| `dotSize` | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 |
| `dotRound` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `dotWave` | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| `dotWaveFreq` | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 |
| `dotWaveSpeed` | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| `shimmer` | 0.6 | 0.6 | 0.6 | 0.6 | 0.9 | 0.6 | 0.6 | 0.6 | 0.6 |
| `shimmerSpeed` | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 |
| `palette` | Pearl | Pearl | Pearl | Holographic | Oil Slick | Rainbow | Pearl | Holographic | Pearl |
| `saturation` | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 | 1.3 | 0.8 | 0.8 | 0.8 |
| `hueSpeed` | 0.08 | 0.08 | 0.08 | 0.08 | 0.08 | 0.2 | 0.08 | 0.08 | 0.08 |
| `hueScale` | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 |
| `glow` | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 |
| `textColor` | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 | #BEBEC8 |
| `bgPreset` | Iridescent Pearl | Original | Original | Original | Original | Original | Original | Original | Original |
| `bgIri` | 0.25 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0 |
| `bgDim` | 0.3 | 0.45 | 0.45 | 0.6 | 0.5 | 0.45 | 0 | 0.2 | 0.6 |
| `bgSpeed` | 120 | 120 | 120 | 120 | 120 | 120 | 120 | 120 | 120 |
| `particles` | 40 | 40 | 40 | 0 | 40 | 40 | 0 | 0 | 20 |
| `menuY` | 0.5 | 0.2 | 0.34 | 0.48 | 0.62 | 0.64 | 0.5 | 0.5 | 0.885 |
| `menuSize` | 34 | 26 | 34 | 34 | 34 | 34 | 22 | 34 | 24 |
| `menuSpacing` | 62 | 46 | 62 | 62 | 62 | 62 | 62 | 62 | 52 |
| `menuColor` | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 | #C8C8D2 |
| `menuSelMode` | Pearl | Pearl | Pearl | Pearl | Pearl | Pearl | Pearl | Pearl | Pearl |
| `menuDotted` | 1 | 0 | 1 | 1 | 1 | 1 | 0 | 1 | 1 |
| `menuGlow` | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 |
| `lightFx` | None | None | None | None | None | None | None | None | None |
| `lightX` | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 |
| `lightY` | 0.86 | 0.86 | 0.86 | 0.86 | 0.86 | 0.86 | 0.86 | 0.86 | 0.86 |
| `lightSize` | 70 | 70 | 70 | 70 | 70 | 70 | 70 | 70 | 70 |
| `lightIntensity` | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 | 0.8 |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
