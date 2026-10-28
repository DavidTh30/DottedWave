# 11. WaveRider Studio

[← กลับสารบัญ](../DEVELOPER_GUIDE.md)

ที่มา: `studio/WaveRiderStudio.lpr`, `studio/src/*.pas` (3,907 บรรทัด)

## 11.1 หลักการ

- Studio แก้ **record เดียวกับที่เกมใช้** (`TGameData`) และหน้าจอจำลอง (`TGamePreview` ใน `uPreview`) คือ `TWaveGame` ตัวจริง สิ่งที่เห็นในหน้าจำลองจึงตรงกับในเกม
- แผงควบคุมทุกช่องสร้างอัตโนมัติจาก descriptor (`uParamPanel`) เพิ่มฟิลด์ในโค้ด 1 บรรทัดแล้ว Studio มีช่องแก้ทันที
- ทุก editor มี **Save / Revert / Defaults** และ editor แบบรายการ (`uEdBase`) มี **Add / Duplicate / Delete**
- หน้าต่างหลักมี **Save all** / **Reload all**
- เปิด editor ตรงได้ด้วย `WaveRiderStudio.exe --open=screens|sound|music|levels|objects|light`

## 11.2 Editor ทั้ง 6

| # | Editor | Unit | แก้อะไร | จำลอง / เครื่องมือ |
|---|---|---|---|---|
| 1 | Menu & Screen FX | `uEdScreens` | 9 หน้าจอ (35 ฟิลด์ต่อหน้า) | หน้าจอนั้นแสดงสดใน preview, คัดลอกสไตล์ไปทุกหน้า |
| 2 | Sound FX | `uEdSound` | เสียง 2 ชั้น + echo (72 ฟิลด์) | waveform, วัดสัดส่วนเบส, template 11 แบบ, Randomize, Mutate, Export WAV |
| 3 | Music | `uEdMusic` | arrangement, pattern 32 × 8, เครื่องดนตรี (44 ฟิลด์) | เล่นสด, loop section, จำลอง combo / fever / pause / slow-mo / bonus, Export WAV |
| 4 | Levels | `uEdLevels` | ทุกฟิลด์ด่าน (43) | autopilot เล่นด่านสด, ความเร็ว x0.5–x4, กราฟอัตรา spawn, ตรวจชื่อใน mix |
| 5 | Objects & Effects | `uEdObjects` | ทุกฟิลด์วัตถุ (38) | วัตถุเกิดซ้ำให้ยานชน (`SimObject`), ซูม sprite, ตัววาด pixel art |
| 6 | Light FX | `uEdLight` | แสง 4 แบบ (19 ฟิลด์) | Light Lab, prism sentinel, grating ยิงอัตโนมัติ, diamond bonus |

## 11.3 API จำลองที่ Studio ใช้ (`TWaveGame`)

| เมธอด | ใช้ทำ |
|---|---|
| `SimLevel(i)` | เล่นด่าน i แบบ autopilot + อมตะ (`SimMode = smLevel`) |
| `SimObject(obj, styleLevel)` | ปล่อยวัตถุชนิดเดียวทุก 1.1 วินาที (Orbit ปล่อยเป็นคู่) |
| `SimScreen(id)` | แสดงหน้าจอเมนูนั้น (Ready วนนับถอยหลังซ้ำ) |
| `SpawnNearShip(obj)` | วางวัตถุเหนือยาน (ทดสอบโบนัส) |
| `DebugFire(charge)` | ยิง Grating โดยไม่ต้องกด |
| `DrawObjectPreview` | วาดวัตถุเดี่ยวสำหรับรายการ |
| `DataChanged` | ล้าง cache sprite หลังแก้ค่า |
| `LightLabFocus` | เน้นแสงชนิดหนึ่งใน Light Lab |

โหมดจำลองทั้งหมดไม่บันทึก progress และ HUD แสดง `SIMULATION`
