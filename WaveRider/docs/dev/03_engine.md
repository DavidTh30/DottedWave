# 3. Engine คลื่นจุด (Dotted Wave Mesh)

[← กลับสารบัญ](../DEVELOPER_GUIDE.md) · ตารางพารามิเตอร์ครบ: [ref_mesh.md](ref_mesh.md)

ที่มา: `DottedWave/src/uwaveengine.pas` (654 บรรทัด), `uwavetypes.pas`, `usimplexnoise.pas`

## 3.1 อัลกอริทึม

ภาพเป็น **เส้นแนวนอน `lines` เส้น** แต่ละเส้นมี **จุดทุก `dotSpacing` px** แต่ละจุดถูกยกขึ้นตามความสูงของผิวคลื่นแล้วให้แสง

| ขั้น | สิ่งที่คำนวณ | สูตร / หมายเหตุ |
|---|---|---|
| 1 Height | fBm ของ simplex noise 3 มิติ | `octaves` ชั้น ความถี่ × `lacunarity` แอมพลิจูด × `gain`, แกน x ยืดด้วย `stretchX`, เลื่อนตามเวลา `speed`, `driftX/Y` และ `ScrollY` |
| 2 Hook | บวกผลจากเกม | `Wells` = gaussian `Height·exp(−d²/r²)` และเงา `Darken`; `Rings` = วงแหวน `Strength·exp(−((d−R)/Width)²)`; ripple จากเมาส์ |
| 3 Displace | ย้ายตำแหน่งจุด | `y += h · amplitude · depthK` (มุมมองเอียง `tilt`), `x += warp · noise` |
| 4 Normal | ความชันจาก finite difference | ขยายด้วย `relief` |
| 5 แสง | Lambert + Blinn-Phong | ทิศ `lightAzimuth/Elevation`, `ambient + diffuse·N·L + specular·(N·H)^specPower`, จากนั้น `exposure` และยกกำลัง `contrast` |
| 6 สี Iridescent | thin-film แบบประมาณ | เฉดสี = มุมผิว × `iriFrequency` + ความสูง × `iriHeight` + ตำแหน่ง × `iriSpread` + เวลา × `iriSpeed` + `iriOffset` → LUT 256 สีจาก cosine palette, ผสมด้วย `iriAmount`, ประกายขาว `iriSpecWhite` |
| 7 Image hook | ให้จุดวาดภาพ | จุดในกรอบภาพรับสีของภาพ × `ImageMix`; นอกกรอบมืดลง `ImageBgDim` (0.45) |
| 8 Splat | วางจุดลง float buffer | สี่เหลี่ยมขนาด `dotSize` แบบ box-filter (ขอบนุ่ม) |
| 9 Colorize | float → BGRA | `BgColor`, `DotColor`, `vignette` |

## 3.2 เธรด

`TWaveEngine` แบ่งงานตามแถวให้ `TWavePoolWorker` (core − 1 ตัว) ปลุกด้วย RTL event ผลลัพธ์ตรงกับแบบเธรดเดียวทุกพิกเซล (ตรวจด้วยการเทียบ PNG)

วัดได้: ภาพ 463×900 ใช้ 14.2 ms บนเธรดเดียว เหลือประมาณ 3 ms บน 12 เธรด

## 3.3 พารามิเตอร์ 37 ตัว

| กลุ่ม | key |
|---|---|
| Geometry | `lines`, `dotSpacing`, `dotSize`, `amplitude`, `noiseScale`, `octaves`, `lacunarity`, `gain`, `stretchX`, `warp`, `tilt` |
| Motion | `speed`, `driftX`, `driftY` |
| Light | `lightAzimuth`, `lightElevation`, `relief`, `ambient`, `diffuse`, `specular`, `specPower`, `exposure`, `contrast` |
| Color | `vignette`, `iriAmount`, `iriPalette`, `iriFrequency`, `iriHeight`, `iriSpread`, `iriSpeed`, `iriOffset`, `iriSaturation`, `iriSpecWhite` |
| Interaction | `rippleStrength`, `rippleRadius` |
| Render | `renderScale`, `seed` |

ช่วงค่า ค่าเริ่มต้น และคำอธิบายของทุกตัวอยู่ใน [ref_mesh.md](ref_mesh.md)

## 3.4 Preset 8 แบบ

Original (ภาพต้นฉบับ) · Calm Silk · Storm · Dense Fabric · Sound Wave · Iridescent Pearl · Holographic · Oil Slick

ค่าของทุก preset เทียบกันใน [ref_mesh.md](ref_mesh.md) (ตัวหนา = ต่างจากค่าเริ่มต้น)

Palette ของ Iridescent: 0 Rainbow · 1 Pearl · 2 Oil slick · 3 Holographic · 4 Beetle (ในด่าน ค่า 5 = Mono คือปิดสีรุ้ง)

## 3.5 เกมใช้ engine อย่างไร (`TWaveGame.ApplyToEngine`)

| สิ่งที่เกมตั้ง | ค่า |
|---|---|
| preset | `MeshPreset` ของด่าน หรือ `BgPreset` ของหน้าจอเมนู |
| override | `lines`, `amplitude` (ถ้า > 0), `BgColor`, `DotColor`, `vignette` ของด่าน |
| สีรุ้ง | `iriAmount = FIri` ซึ่งไล่จาก `IriBase` ของด่านไปถึง 1 ตามความเข้มคอมโบ (Fever = 1), `iriSpeed = 1 + 0.6 × combo` |
| การไหล | `ScrollY` สะสมจากความเร็วด่าน, `driftX = 0.25`, `driftY = 0` |
| Wells | ยาน: r 55, สูง 0.55, เงา −0.9 (สว่างรอบยาน) · Shield: r 90 · วัตถุ: `wellRadius/Height/Darken` ของแต่ละชนิด |
| Rings | จากการเก็บของ การชน การระเบิด: รัศมี = อายุ × `speed`, แรงลดลง `exp(−อายุ × decay)` |
| Image | ด่านอนิเมะ: เลเยอร์ chibi ชั้น 0 (เมื่อ `EchoMix` > 0) |

## 3.6 โปรแกรม DottedWave

- หน้าต่างแสดงผล (OpenGL, vsync) + หน้าต่างควบคุมแยก ปรับพารามิเตอร์ทั้ง 37 ตัวแบบสด
- Export: PNG, INI (`[Params]`), JSON (`spec_default.json`), Pascal (`ApplyWavePreset`)
- ภาพตัวอย่าง: `DottedWave/docs/preview_*.png`
