# อ้างอิง: แสง 4 แบบ (Light FX)

> ที่มา `src/ulightfx.pas` — `TLightDef`, `DescribeLightDef`, `DefaultLightDef`

## ฟิลด์ของแสง (`TLightDef`, 19 ฟิลด์)

section ใน `data/light.ini`: `[Light0]` Prism · `[Light1]` Newton · `[Light2]` Grating · `[Light3]` Diamond

**Glass**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `name` | Name | string | text |  |
| `index` | Refractive index | float | 1.000 .. 3.000 | Glass 1.5, diamond 2.42 |
| `dispersion` | Dispersion | float | 0.000 .. 0.600 | How far the colours split |
| `size` | Size | float | 20 .. 400 | Optic size (reference px) |
| `tilt` | Tilt (deg) | float | -90.0 .. 90.0 |  |
| `swing` | Swing (deg) | float | 0.0 .. 45.0 | Animated rotation amplitude |
| `swingSpeed` | Swing speed | float | 0.00 .. 5.00 |  |
| `glassAlpha` | Glass opacity | float | 0.00 .. 1.00 |  |
| `edgeGlow` | Edge glow | float | 0.00 .. 2.00 |  |

**Light**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `bands` | Spectral bands | int | 3 .. 32 | More bands = smoother rainbow, slower |
| `beamWidth` | Beam width | float | 0.50 .. 8.00 |  |
| `glow` | Halo | float | 0.00 .. 3.00 |  |
| `intensity` | Intensity | float | 0.00 .. 3.00 |  |
| `innerGlow` | Inside glass | float | 0.00 .. 1.50 | Brightness of the beam inside the glass |
| `maxBounce` | Max bounces | int | 1 .. 16 |  |
| `beamLength` | Beam length | float | 100 .. 4000 |  |
| `reflect` | Partial reflection | float | 0.00 .. 0.80 | Fresnel reflections: more sparkle, more beams |

**Grating**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |
|---|---|---|---|---|
| `pitch` | Pitch (spread) | float | 0.050 .. 1.500 | sin(out) = sin(in) + m * lambda * pitch |
| `orders` | Orders +- | int | 0 .. 4 |  |

## ค่าเริ่มต้นของแสง 4 แบบ (`DefaultLightDef`)

| key | Dispersion Prism | Newton's Prisms | Diffraction Grating | Diamond |
|---|---|---|---|---|
| `name` | Dispersion Prism | Newton's Prisms | Diffraction Grating | Diamond |
| `index` | 1.52 | 1.52 | 1.52 | 2.42 |
| `dispersion` | 0.08 | 0.1 | 0.08 | 0.3 |
| `size` | 120 | 95 | 120 | 120 |
| `tilt` | 0 | 0 | 0 | 0 |
| `swing` | 8 | 8 | 8 | 8 |
| `swingSpeed` | 0.6 | 0.6 | 0.6 | 0.6 |
| `glassAlpha` | 0.6 | 0.6 | 0.6 | 0.6 |
| `edgeGlow` | 0.8 | 0.8 | 0.8 | 0.8 |
| `bands` | 14 | 14 | 12 | 12 |
| `beamWidth` | 1.8 | 1.8 | 1.8 | 1.8 |
| `glow` | 1 | 1 | 1 | 1 |
| `intensity` | 1.1 | 1.1 | 1.1 | 1.2 |
| `innerGlow` | 0.35 | 0.35 | 0.35 | 0.45 |
| `maxBounce` | 6 | 6 | 6 | 9 |
| `beamLength` | 1600 | 1600 | 1600 | 1600 |
| `reflect` | 0.12 | 0.12 | 0.12 | 0.3 |
| `pitch` | 0.55 | 0.55 | 0.6 | 0.55 |
| `orders` | 2 | 2 | 2 | 2 |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
