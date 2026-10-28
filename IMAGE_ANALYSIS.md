# การวิเคราะห์ภาพ: Dotted Wave Mesh (คลื่นเส้นจุดขาว-ดำ)

> ไฟล์อ้างอิง: `19829fdf8954334590777efdaefd1f65.png`
> วันที่วิเคราะห์: 2026-10-20
> วัตถุประสงค์: เก็บข้อมูลภาพทั้งหมดเพื่อใช้พัฒนาเป็นพื้นหลัง/องค์ประกอบ UI แบบ Generative (Canvas / WebGL)

---

## 1. ข้อมูลทางเทคนิคของไฟล์

| รายการ | ค่า |
|---|---|
| รูปแบบไฟล์ | PNG (ต้นฉบับที่แนบมาเป็น WebP) |
| ขนาด | **736 × 1431 px** |
| อัตราส่วน | ≈ **1 : 1.94** (แนวตั้ง ใกล้เคียงหน้าจอมือถือ 9:17.5) |
| Bit depth / Color type | 8-bit, RGBA |
| ขนาดไฟล์ | ~1.25 MB |
| ประเภทการใช้งานที่เหมาะ | Wallpaper มือถือ, Hero background, Splash screen, Loading screen |

---

## 2. ภาพรวม (Overview)

ภาพเป็นงานกราฟิกแนว **Abstract / Generative / Data-visualization aesthetic** ประกอบด้วย
**เส้นแนวนอนจำนวนมากที่เรียงขนานกัน** แต่ละเส้นสร้างจาก **จุดสี่เหลี่ยมเล็ก ๆ (dots / particles)** ต่อกัน
เส้นทั้งหมดถูกบิดเป็น **ลอนคลื่น 3 มิติ (wave surface / displaced mesh)** คล้ายผืนผ้าไหมหรือพื้นผิวน้ำที่ถูกมองจากมุมเฉียง
ให้ความรู้สึก: **เทคโนโลยี, ดิจิทัล, เสียง/สัญญาณ (sound wave), ไซไฟ, มินิมอล, หรูหรา**

---

## 3. องค์ประกอบภาพ (Composition)

### 3.1 โครงสร้างเส้น
- เส้นแนวนอนประมาณ **110–130 เส้น** ตลอดความสูงภาพ
- ระยะห่างระหว่างเส้นเฉลี่ย **~11–13 px** (ที่ความสูง 1431 px) — ระยะห่าง **ไม่คงที่**: บีบเข้าใกล้กันตรงสันคลื่นที่หันออกจากผู้มอง และถ่างออกตรงที่หันเข้าหาผู้มอง (ผลจาก perspective/displacement)
- เส้นวิ่งเต็มความกว้างภาพ ทะลุขอบซ้าย-ขวา (ไม่มีจุดเริ่ม/จบให้เห็น)

### 3.2 จุด (Dots)
- รูปทรง: **สี่เหลี่ยมเล็ก ~1.5–2.5 px** (ไม่ใช่วงกลม — มองเห็นเป็นเส้นประ/dashed)
- ระยะห่างจุดตามแนวเส้น: **~3–4 px**
- บริเวณที่สว่างมาก จุดจะชิดจนดูเหมือน **เส้นทึบต่อเนื่อง**
- บริเวณมืด จุดจางจน **หายไปกับพื้นหลัง**

### 3.3 รูปทรงคลื่น (Wave topology)
พื้นผิวมีลักษณะเป็น **ลอนนุ่ม (smooth, organic)** ไม่ใช่ sine ธรรมดา — คล้าย **Perlin / Simplex noise หลาย octave** ผสมกับคลื่นซ้อน
จุดเด่นที่สังเกตได้ (อ้างอิงตำแหน่งเป็น % ของภาพ):

| ตำแหน่ง (x%, y%) | ลักษณะ |
|---|---|
| (60–100%, 0–10%) | สันคลื่นสว่าง เส้นโค้งลงทางขวา |
| (0–40%, 12–20%) | แถบสว่างกว้าง ลอนเรียบ |
| (55–100%, 18–30%) | หุบมืดลึก เส้นบีบตัวแน่น |
| (0–25%, 35–45%) | **จุดรวม (pinch/vortex)** ด้านซ้าย เส้นบีบเป็นกรวยเข้าหาขอบซ้าย |
| (30–60%, 48–55%) | สันคลื่นสว่างพาดเฉียง |
| (75–100%, 40–50%) | ลอนพับ/ม้วน สว่างที่ขอบขวา |
| (25–50%, 58–65%) | **จุดรวมที่สอง** — เส้นพับเข้าหากันแบบ saddle |
| (0–40%, 70–78%) | แถบสว่างกว้าง (highlight หลักด้านล่าง) |
| (50–100%, 80–95%) | ลอนคลื่นเฉียงขึ้นขวา สว่างปานกลาง |

- ทิศทางการไหลโดยรวม: **ทแยงจากซ้ายบนลงขวาล่าง** สลับลอน
- จำนวน "ลอนใหญ่" ในแนวตั้ง: **~5–6 ลอน**
- แอมพลิจูดลอนใหญ่: **~40–90 px** (ราว 3–6% ของความสูงภาพ)

---

## 4. สีและแสง (Color & Lighting)

### 4.1 Palette
| บทบาท | HEX | หมายเหตุ |
|---|---|---|
| Background | `#000000` – `#050505` | ดำสนิท |
| Dot – เงา | `#1A1A1A` – `#3A3A3A` | แทบกลืนกับพื้น |
| Dot – กลาง | `#7A7A7A` – `#A0A0A0` | |
| Dot – สว่าง | `#D8D8D8` – `#F2F2F2` | |
| Dot – highlight สูงสุด | `#FFFFFF` | บนสันคลื่น |

- **Monochrome ล้วน (Grayscale)** — ไม่มี hue
- อาจมีเฉดเย็นอ่อนมาก (cool silver) ในบางจุด — ถือว่าเป็นขาวกลาง

### 4.2 การจัดแสง
- ความสว่างของจุดขึ้นกับ **มุมของพื้นผิวเทียบกับแหล่งแสง** (เหมือน diffuse/Lambert + specular อ่อน)
- แหล่งแสงโดยประมาณ: **จากด้านซ้ายบน–ด้านหน้า**
- ด้านคลื่นที่หันออกจากแสง → มืดสนิท สร้างมิติลึกแบบ **chiaroscuro**
- Contrast สูงมาก (ดำ 0% ↔ ขาว 95%) — ช่วยให้ข้อความขาวบนพื้นนี้ต้องวางในโซนมืด

---

## 5. สไตล์และอารมณ์ (Mood / Style keywords)

`dark mode` · `monochrome` · `particle wave` · `sound wave` · `data flow` · `generative art` ·
`op-art` · `silk/fabric` · `futuristic` · `minimal luxury` · `AI / neural` · `audio visualizer`

แนวอ้างอิง: Unknown Pleasures (Joy Division) แบบ 3D, Three.js particle wave, Apple/Teenage Engineering-style dark UI

---

## 6. แนวทางนำไปพัฒนา (Implementation Guide)

### 6.1 เทคนิคที่แนะนำ
| วิธี | ข้อดี | ข้อเสีย |
|---|---|---|
| **Canvas 2D + Simplex noise** | ง่าย, ไม่ต้องมี lib ใหญ่ | จุดเยอะ (≈30k) อาจหนักบนมือถือถ้า animate |
| **WebGL / Three.js `Points`** (แนะนำ) | ลื่น 60fps, ทำ perspective + lighting จริงได้ | ต้องเขียน shader |
| GLSL fragment shader ล้วน | เบาที่สุด เต็มจอ | ปรับแต่งรายจุดยาก |
| ภาพนิ่ง (WebP/AVIF) | ไม่มีโหลด CPU | ไม่ขยับ, เบลอเมื่อ scale |

### 6.2 พารามิเตอร์สำหรับสร้างซ้ำ (ค่าเริ่มต้น)
```js
const CONFIG = {
  lines:        120,     // จำนวนเส้นแนวนอน
  dotsPerLine:  220,     // จุดต่อเส้น (ระยะ ~3.3px ที่กว้าง 736)
  dotSize:      1.8,     // px (สี่เหลี่ยม)
  bg:           '#000000',
  dotColor:     [255,255,255],
  noiseScale:   0.0022,  // ความถี่ noise (ยิ่งน้อยยิ่งลอนใหญ่)
  octaves:      3,
  amplitude:    70,      // px การเลื่อนแนวตั้งสูงสุด
  depth:        1.0,     // แรง perspective
  lightDir:     [-0.5, -0.6, 0.6], // ซ้ายบน-หน้า
  minAlpha:     0.0,     // จุดในเงา
  maxAlpha:     1.0,
  speed:        0.00015, // ความเร็ว animation (ถ้ามี)
};
```

### 6.3 อัลกอริทึม (Canvas 2D — ต้นแบบ)
1. สำหรับแต่ละเส้น `i` และจุด `j`: `u = j / (dotsPerLine-1)`, `v = i / (lines-1)`
2. ตำแหน่งฐาน: `x = u * W`, `y0 = v * H`
3. ความสูงพื้นผิว: `h = fbm(x*noiseScale, y0*noiseScale, t)` (Simplex noise รวม octaves)
4. Displacement: `y = y0 + h * amplitude` (เพิ่มการบิด x เล็กน้อยด้วย noise อีกชุดเพื่อให้เกิดจุด pinch)
5. คำนวณ normal จาก gradient ของ `h` (finite difference) → `brightness = max(0, dot(normal, lightDir))`
6. เพิ่ม specular: `brightness += pow(brightness, 8) * 0.6`
7. วาด `fillRect(x, y, dotSize, dotSize)` ด้วย alpha = `brightness`
8. (ถ้า animate) เพิ่ม `t` ทุกเฟรม, วาดใหม่ด้วย `requestAnimationFrame`

### 6.4 Three.js (Production)
- สร้าง `PlaneGeometry(W, H, dotsPerLine, lines)` → ใช้ `THREE.Points`
- Vertex shader: displace `position.z` ด้วย simplex noise 3D (`pos.xy * scale, uTime`)
- คำนวณ normal ใน shader ด้วย finite difference → ส่ง `vLight` ไป fragment
- Fragment shader: `gl_FragColor = vec4(vec3(1.0), vLight);` และใช้ `gl_PointSize` ≈ 2.0 * devicePixelRatio
- กล้อง: `PerspectiveCamera(fov 35–45)`, หมุนแกน X ประมาณ **-15° ถึง -25°** ให้ได้มุมเฉียงแบบในภาพ
- `AdditiveBlending` ช่วยให้จุดที่ซ้อนกันสว่างขึ้นเหมือนเส้นทึบ

### 6.5 ข้อควรพิจารณา UI/UX
- **Accessibility**: ข้อความบนพื้นนี้ควรมี overlay `rgba(0,0,0,0.4–0.6)` หรือวางในโซนมืด (เช่น 55–100% x, 18–30% y)
- **Performance**: บนมือถือลด `dotsPerLine`/`lines` ลง 40–50%, เคารพ `prefers-reduced-motion` (หยุด animation)
- **Responsive**: คำนวณจำนวนจุดจาก `width/3.3` และ `height/12` แทนค่าคงที่
- **Dark-only**: ภาพนี้ออกแบบมาสำหรับธีมมืด — หากต้องมี light mode ให้กลับสี (พื้น `#F5F5F5`, จุด `#111`)
- **Interaction ไอเดีย**: เมาส์/นิ้วสร้างแรงกระเพื่อม (ripple), เชื่อมกับ audio input เป็น visualizer, parallax ตาม gyroscope

---

## 7. Checklist ก่อนพัฒนา
- [ ] เลือกเทคโนโลยี (Canvas 2D / Three.js / Shader)
- [ ] กำหนดว่าเป็นภาพนิ่งหรือ animation
- [ ] กำหนดขนาดเป้าหมาย (มือถือแนวตั้ง 736×1431 หรือ responsive)
- [ ] ใส่ไลบรารี noise (เช่น `simplex-noise` v4)
- [ ] ปรับ `noiseScale`/`amplitude` ให้ได้ลอน 5–6 ลอนตามต้นฉบับ
- [ ] ตั้งทิศแสงซ้ายบน ให้ได้ highlight/เงาตามตารางข้อ 3.3
- [ ] ทดสอบ FPS บนมือถือ + โหมด reduced-motion
- [ ] วางเลเยอร์ UI/ข้อความ และตรวจ contrast
