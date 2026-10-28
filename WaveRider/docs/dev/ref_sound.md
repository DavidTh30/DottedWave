# อ้างอิง: เสียงประกอบ (Sound FX)

> ที่มา `src/usynth.pas` — `TSynthParams`, `TSfxDef`, `DescribeSfx`, `DefaultSfxBank`

## ฟิลด์ของเสียง (`TSfxDef`, 72 ฟิลด์ = 2 ชั้น × `TSynthParams` + echo)

section ใน `data/sfx.ini`: `[Bank] Count` + `[Sfx0]` ... · ชั้น A ใช้ key `a.*` ชั้น B ใช้ `b.*`

**Sound**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `name` | Name | string | text | `field` |  |
| `gain` | Gain | float | 0.00 .. 3.00 | `1` |  |
| `echoMix` | Echo mix | float | 0.00 .. 1.00 | `0` |  |
| `echoTime` | Echo time (s) | float | 0.020 .. 1.000 | `0.18` |  |
| `echoFb` | Echo feedback | float | 0.00 .. 0.90 | `0.35` |  |
| `useB` | Use layer B (bass layer) | bool | 0 / 1 | `0` |  |

**A: Oscillator**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.wave` | Wave | enum | Sine / Saw / Square / Triangle / Noise | `Sine` |  |
| `a.detune` | Detune (cents) | float | 0.0 .. 60.0 | `0` | Second oscillator detune - thick supersaw style |
| `a.noise` | Noise mix | float | 0.00 .. 1.00 | `0` |  |
| `a.sub` | Sub level | float | 0.00 .. 1.50 | `0` | Sine one octave below: heavy bass weight |
| `a.note` | Base note (MIDI) | float | 12.0 .. 108.0 | `57` | SFX pitch. 33 = A1 (55 Hz), 45 = A2, 57 = A3 |
| `a.octave` | Octave (instr.) | int | -3 .. 3 | `0` |  |

**A: Pitch**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.pitchEnv` | Pitch env (semi) | float | -48.0 .. 48.0 | `0` | 808 / kick drop: start this many semitones above |
| `a.pitchDecay` | Pitch decay (s) | float | 0.005 .. 2.000 | `0.05` |  |
| `a.slide` | Slide (semi/s) | float | -96.0 .. 96.0 | `0` |  |
| `a.vibDepth` | Vibrato depth | float | 0.00 .. 2.00 | `0` |  |
| `a.vibRate` | Vibrato rate (Hz) | float | 0.1 .. 20.0 | `5` |  |
| `a.arp` | Arpeggio (semis) | string | text | `` | e.g. "0 4 7 12" - empty = off |
| `a.arpRate` | Arp rate (steps/s) | float | 1.0 .. 60.0 | `20` |  |

**A: Amp envelope**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.attack` | Attack (s) | float | 0.0005 .. 3.0000 | `0.002` |  |
| `a.decay` | Decay (s) | float | 0.005 .. 6.000 | `0.3` |  |
| `a.sustain` | Sustain | float | 0.00 .. 1.00 | `0` |  |
| `a.release` | Release (s) | float | 0.005 .. 6.000 | `0.1` |  |
| `a.duration` | Duration (SFX gate s) | float | 0.010 .. 4.000 | `0.2` |  |

**A: Filter**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.filter` | Filter type | enum | LowPass / HighPass / BandPass | `LowPass` |  |
| `a.cutoff` | Cutoff (Hz) | float | 20 .. 18000 | `18000` |  |
| `a.res` | Resonance | float | 0.00 .. 0.97 | `0.1` |  |
| `a.fenv` | Filter env (oct) | float | -8.00 .. 8.00 | `0` |  |
| `a.fdecay` | Filter decay (s) | float | 0.005 .. 4.000 | `0.2` |  |

**A: LFO / wobble**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.lfoRate` | LFO rate | float | 0.05 .. 32.00 | `2` | Hz, or cycles per beat when synced |
| `a.lfoSync` | LFO tempo sync | bool | 0 / 1 | `0` |  |
| `a.lfoCutoff` | LFO -> cutoff (oct) | float | 0.00 .. 8.00 | `0` | Dubstep wobble |
| `a.lfoPitch` | LFO -> pitch (semi) | float | 0.00 .. 12.00 | `0` |  |
| `a.lfoAmp` | LFO -> amp | float | 0.00 .. 1.00 | `0` |  |

**A: Character**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `a.drive` | Drive | float | 1.0 .. 30.0 | `1` | Saturation - makes bass heavy and loud |
| `a.crush` | Bit crush (bits) | int | 0 .. 16 | `0` | 0 = off. 4-6 = 8-bit pixel sound |
| `a.downsample` | Sample hold | int | 1 .. 32 | `1` |  |
| `a.volume` | Volume | float | 0.00 .. 2.00 | `0.8` |  |
| `a.pan` | Pan | float | -1.00 .. 1.00 | `0` |  |

**B: Oscillator**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.wave` | Wave | enum | Sine / Saw / Square / Triangle / Noise | `Sine` |  |
| `b.detune` | Detune (cents) | float | 0.0 .. 60.0 | `0` | Second oscillator detune - thick supersaw style |
| `b.noise` | Noise mix | float | 0.00 .. 1.00 | `0` |  |
| `b.sub` | Sub level | float | 0.00 .. 1.50 | `0` | Sine one octave below: heavy bass weight |
| `b.note` | Base note (MIDI) | float | 12.0 .. 108.0 | `33` | SFX pitch. 33 = A1 (55 Hz), 45 = A2, 57 = A3 |
| `b.octave` | Octave (instr.) | int | -3 .. 3 | `0` |  |

**B: Pitch**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.pitchEnv` | Pitch env (semi) | float | -48.0 .. 48.0 | `0` | 808 / kick drop: start this many semitones above |
| `b.pitchDecay` | Pitch decay (s) | float | 0.005 .. 2.000 | `0.05` |  |
| `b.slide` | Slide (semi/s) | float | -96.0 .. 96.0 | `0` |  |
| `b.vibDepth` | Vibrato depth | float | 0.00 .. 2.00 | `0` |  |
| `b.vibRate` | Vibrato rate (Hz) | float | 0.1 .. 20.0 | `5` |  |
| `b.arp` | Arpeggio (semis) | string | text | `` | e.g. "0 4 7 12" - empty = off |
| `b.arpRate` | Arp rate (steps/s) | float | 1.0 .. 60.0 | `20` |  |

**B: Amp envelope**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.attack` | Attack (s) | float | 0.0005 .. 3.0000 | `0.002` |  |
| `b.decay` | Decay (s) | float | 0.005 .. 6.000 | `0.3` |  |
| `b.sustain` | Sustain | float | 0.00 .. 1.00 | `0` |  |
| `b.release` | Release (s) | float | 0.005 .. 6.000 | `0.1` |  |
| `b.duration` | Duration (SFX gate s) | float | 0.010 .. 4.000 | `0.2` |  |

**B: Filter**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.filter` | Filter type | enum | LowPass / HighPass / BandPass | `LowPass` |  |
| `b.cutoff` | Cutoff (Hz) | float | 20 .. 18000 | `18000` |  |
| `b.res` | Resonance | float | 0.00 .. 0.97 | `0.1` |  |
| `b.fenv` | Filter env (oct) | float | -8.00 .. 8.00 | `0` |  |
| `b.fdecay` | Filter decay (s) | float | 0.005 .. 4.000 | `0.2` |  |

**B: LFO / wobble**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.lfoRate` | LFO rate | float | 0.05 .. 32.00 | `2` | Hz, or cycles per beat when synced |
| `b.lfoSync` | LFO tempo sync | bool | 0 / 1 | `0` |  |
| `b.lfoCutoff` | LFO -> cutoff (oct) | float | 0.00 .. 8.00 | `0` | Dubstep wobble |
| `b.lfoPitch` | LFO -> pitch (semi) | float | 0.00 .. 12.00 | `0` |  |
| `b.lfoAmp` | LFO -> amp | float | 0.00 .. 1.00 | `0` |  |

**B: Character**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `b.drive` | Drive | float | 1.0 .. 30.0 | `1` | Saturation - makes bass heavy and loud |
| `b.crush` | Bit crush (bits) | int | 0 .. 16 | `0` | 0 = off. 4-6 = 8-bit pixel sound |
| `b.downsample` | Sample hold | int | 1 .. 32 | `1` |  |
| `b.volume` | Volume | float | 0.00 .. 2.00 | `0.8` |  |
| `b.pan` | Pan | float | -1.00 .. 1.00 | `0` |  |

## เสียงค่าเริ่มต้น 25 เสียง (`DefaultSfxBank`)

| # | name | ยาว (s) | A: wave | A: note | A: pitchEnv | A: cutoff | ใช้ B | B: wave | B: note | echo | gain |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | **collect** | 0.21 | Square | A5 | 0.0 | 5000 | ใช่ | Sine | A2 | - | 1.00 |
| 1 | **collect_hi** | 0.76 | Saw | E6 | 0.0 | 7000 | ใช่ | Sine | E2 | 0.11 s | 1.00 |
| 2 | **prism** | 1.18 | Triangle | C6 | 0.0 | 18000 | ใช่ | Sine | D2 | 0.18 s | 1.00 |
| 3 | **hit** | 0.92 | Noise | A3 | 0.0 | 900 | ใช่ | Sine | G1 | - | 1.10 |
| 4 | **pulse** | 1.84 | Sine | E1 | 36.0 | 18000 | ใช่ | Noise | A1 | - | 1.00 |
| 5 | **shield** | 1.58 | Saw | A3 | 0.0 | 800 | ใช่ | Sine | A1 | 0.18 s | 1.00 |
| 6 | **magnet** | 0.69 | Sine | A2 | 0.0 | 18000 | - | - | - | - | 1.00 |
| 7 | **slowmo** | 1.57 | Saw | E4 | 0.0 | 1500 | ใช่ | Sine | C2 | - | 1.00 |
| 8 | **double** | 0.39 | Square | E5 | 0.0 | 18000 | ใช่ | Sine | C2 | - | 1.00 |
| 9 | **life** | 1.45 | Triangle | C5 | 0.0 | 18000 | ใช่ | Sine | A1 | 0.18 s | 1.00 |
| 10 | **star** | 1.97 | Saw | A4 | 0.0 | 6000 | ใช่ | Sine | F1 | 0.18 s | 1.00 |
| 11 | **fever** | 1.84 | Saw | A2 | 0.0 | 400 | ใช่ | Sine | E1 | - | 1.00 |
| 12 | **nova** | 2.10 | Noise | A3 | 0.0 | 300 | ใช่ | Sine | D1 | - | 1.00 |
| 13 | **levelup** | 2.36 | Saw | A3 | 0.0 | 300 | ใช่ | Sine | E1 | 0.18 s | 1.00 |
| 14 | **complete** | 2.76 | Saw | A4 | 0.0 | 5000 | ใช่ | Sine | A1 | 0.18 s | 1.00 |
| 15 | **gameover** | 2.42 | Sine | E2 | 0.0 | 18000 | ใช่ | Noise | A1 | - | 1.00 |
| 16 | **combo** | 0.66 | Square | G5 | 0.0 | 18000 | ใช่ | Sine | G1 | - | 1.00 |
| 17 | **block** | 0.39 | Triangle | C4 | 12.0 | 18000 | ใช่ | Sine | C2 | - | 1.00 |
| 18 | **menu_move** | 0.14 | Triangle | D6 | 0.0 | 18000 | ใช่ | Sine | C3 | - | 1.00 |
| 19 | **menu_select** | 0.59 | Saw | A4 | 0.0 | 4000 | ใช่ | Sine | A1 | - | 1.00 |
| 20 | **pause** | 0.53 | Sine | C2 | -12.0 | 18000 | - | - | - | - | 1.00 |
| 21 | **beam** | 2.28 | Saw | A3 | 0.0 | 600 | ใช่ | Sine | E1 | 0.16 s | 1.00 |
| 22 | **charge** | 0.16 | Triangle | C4 | 0.0 | 18000 | ใช่ | Sine | E2 | - | 1.00 |
| 23 | **grate_fire** | 2.23 | Saw | E5 | 0.0 | 9000 | ใช่ | Sine | D1 | 0.12 s | 1.00 |
| 24 | **ready** | 0.33 | Square | C5 | 0.0 | 18000 | ใช่ | Sine | C2 | - | 1.00 |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
