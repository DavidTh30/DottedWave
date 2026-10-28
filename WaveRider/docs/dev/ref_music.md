# อ้างอิง: เพลง (Music)

> ที่มา `src/umusic.pas` — `TSong`, `TInstrument`, `TSection`, `TPattern`, `DefaultSong`

## เพลงค่าเริ่มต้น: "Pearl Pressure"

BPM **140** · swing 0.00 · master gain 0.90 · ความยาว **5:01** นาที · 6 pattern · 9 section

### Track (เครื่องดนตรี) 8 ช่อง

| # | name | wave | octave | gain | pan | chord | transposable | intensityMin | intensityCutoff | intensityLfo | sidechain | kick |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | **Kick** | Sine | 0 | 1.00 | 0.00 | Single | - | 0.00 | 0.00 | 1.00 | 0.00 | ใช่ |
| 1 | **Clap** | Noise | 0 | 0.80 | 0.00 | Single | - | 0.15 | 0.00 | 1.00 | 0.20 | - |
| 2 | **Hats** | Noise | 0 | 0.55 | 0.25 | Single | - | 0.20 | 0.00 | 1.00 | 0.30 | - |
| 3 | **Sub Bass** | Sine | 0 | 1.00 | 0.00 | Single | ใช่ | 0.00 | 1.00 | 1.00 | 0.85 | - |
| 4 | **Growl Bass** | Saw | 1 | 0.85 | 0.00 | Single | ใช่ | 0.60 | 1.20 | 2.00 | 0.70 | - |
| 5 | **Pad** | Saw | 0 | 0.60 | 0.00 | Minor | ใช่ | 0.00 | 1.60 | 1.00 | 0.65 | - |
| 6 | **Arp** | Square | 1 | 0.55 | -0.30 | Single | ใช่ | 0.35 | 2.00 | 1.00 | 0.50 | - |
| 7 | **Lead** | Saw | 0 | 0.60 | 0.20 | Single | ใช่ | 0.75 | 1.50 | 1.00 | 0.40 | - |

### Section (arrangement)

| # | name | pattern | repeats | progression | energy |
|---|---|---|---|---|---|
| 0 | **Intro** | 0 (Intro) | 8 | `0 -4 3 -2` | 0.10 |
| 1 | **Build** | 1 (Build) | 8 | `0 -4 3 -2` | 0.40 |
| 2 | **Drop A** | 2 (Drop A) | 16 | `0 -4 3 -2` | 0.85 |
| 3 | **Break** | 3 (Break) | 8 | `0 -4 3 -2` | 0.20 |
| 4 | **Build 2** | 1 (Build) | 4 | `0 -4 3 -2` | 0.50 |
| 5 | **Drop B** | 4 (Drop B) | 16 | `0 -4 3 -2` | 0.95 |
| 6 | **Break 2** | 3 (Break) | 4 | `0 3 -2 -4` | 0.30 |
| 7 | **Drop A2** | 2 (Drop A) | 16 | `0 3 -2 -4` | 1.00 |
| 8 | **Outro** | 5 (Outro) | 8 | `0 -4 3 -2` | 0.15 |

### Pattern (32 step × 8 track) — จำนวนโน้ตต่อ track

| # | name | Kick | Clap | Hats | Sub | Growl | Pad | Arp | Lead |
|---|---|---|---|---|---|---|---|---|---|
| 0 | Intro | 2 | 0 | 4 | 2 | 0 | 1 | 8 | 0 |
| 1 | Build | 8 | 14 | 8 | 8 | 0 | 1 | 16 | 0 |
| 2 | Drop A | 8 | 4 | 8 | 8 | 8 | 4 | 32 | 16 |
| 3 | Break | 0 | 0 | 0 | 1 | 0 | 1 | 16 | 3 |
| 4 | Drop B | 4 | 2 | 16 | 4 | 6 | 1 | 8 | 8 |
| 5 | Outro | 1 | 0 | 0 | 1 | 0 | 1 | 8 | 0 |

ตัวอย่างรูปแบบแถวใน `music.ini` (pattern 0, track 0):

```ini
t0=36:8:1 . . . . . . . . . . . . . . . 36:7:1 . . . . . . . . . . . . . . .
```

## ฟิลด์ของเครื่องดนตรี (`TInstrument`, 44 ฟิลด์ = ค่าผสม + `TSynthParams`)

ค่าเริ่มต้นในตารางคือ track 0 (Kick)

**Track**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `name` | Name | string | text | `Kick` |  |
| `gain` | Gain | float | 0.00 .. 2.00 | `1` |  |
| `pan` | Pan | float | -1.00 .. 1.00 | `0` |  |
| `transposable` | Follows progression | bool | 0 / 1 | `0` | Off for drums |
| `chord` | Chord | enum | Single / Minor / Major / Power / Minor7 / Sus2 / Octave | `Single` |  |
| `kick` | Is kick (drives sidechain) | bool | 0 / 1 | `1` |  |
| `mute` | Mute | bool | 0 / 1 | `0` |  |

**Game reactivity**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `intMin` | Layer threshold | float | 0.00 .. 1.50 | `0` | Track fades in when section energy + combo intensity reac... |
| `intCutoff` | Intensity -> cutoff (oct) | float | 0.00 .. 6.00 | `0` | Combo opens this track's filter |
| `intLfo` | Intensity -> wobble x | float | 1.00 .. 4.00 | `1` | LFO rate multiplier at full combo |
| `sidechain` | Sidechain duck | float | 0.00 .. 1.00 | `0` | Pumping against the kick |

**Oscillator**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.wave` | Wave | enum | Sine / Saw / Square / Triangle / Noise | `Sine` |  |
| `syn.detune` | Detune (cents) | float | 0.0 .. 60.0 | `0` | Second oscillator detune - thick supersaw style |
| `syn.noise` | Noise mix | float | 0.00 .. 1.00 | `0` |  |
| `syn.sub` | Sub level | float | 0.00 .. 1.50 | `0.25` | Sine one octave below: heavy bass weight |
| `syn.note` | Base note (MIDI) | float | 12.0 .. 108.0 | `57` | SFX pitch. 33 = A1 (55 Hz), 45 = A2, 57 = A3 |
| `syn.octave` | Octave (instr.) | int | -3 .. 3 | `0` |  |

**Pitch**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.pitchEnv` | Pitch env (semi) | float | -48.0 .. 48.0 | `36` | 808 / kick drop: start this many semitones above |
| `syn.pitchDecay` | Pitch decay (s) | float | 0.005 .. 2.000 | `0.04` |  |
| `syn.slide` | Slide (semi/s) | float | -96.0 .. 96.0 | `0` |  |
| `syn.vibDepth` | Vibrato depth | float | 0.00 .. 2.00 | `0` |  |
| `syn.vibRate` | Vibrato rate (Hz) | float | 0.1 .. 20.0 | `5` |  |
| `syn.arp` | Arpeggio (semis) | string | text | `` | e.g. "0 4 7 12" - empty = off |
| `syn.arpRate` | Arp rate (steps/s) | float | 1.0 .. 60.0 | `20` |  |

**Amp envelope**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.attack` | Attack (s) | float | 0.0005 .. 3.0000 | `0.002` |  |
| `syn.decay` | Decay (s) | float | 0.005 .. 6.000 | `0.32` |  |
| `syn.sustain` | Sustain | float | 0.00 .. 1.00 | `0` |  |
| `syn.release` | Release (s) | float | 0.005 .. 6.000 | `0.1` |  |
| `syn.duration` | Duration (SFX gate s) | float | 0.010 .. 4.000 | `0.2` |  |

**Filter**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.filter` | Filter type | enum | LowPass / HighPass / BandPass | `LowPass` |  |
| `syn.cutoff` | Cutoff (Hz) | float | 20 .. 18000 | `18000` |  |
| `syn.res` | Resonance | float | 0.00 .. 0.97 | `0.1` |  |
| `syn.fenv` | Filter env (oct) | float | -8.00 .. 8.00 | `0` |  |
| `syn.fdecay` | Filter decay (s) | float | 0.005 .. 4.000 | `0.2` |  |

**LFO / wobble**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.lfoRate` | LFO rate | float | 0.05 .. 32.00 | `2` | Hz, or cycles per beat when synced |
| `syn.lfoSync` | LFO tempo sync | bool | 0 / 1 | `0` |  |
| `syn.lfoCutoff` | LFO -> cutoff (oct) | float | 0.00 .. 8.00 | `0` | Dubstep wobble |
| `syn.lfoPitch` | LFO -> pitch (semi) | float | 0.00 .. 12.00 | `0` |  |
| `syn.lfoAmp` | LFO -> amp | float | 0.00 .. 1.00 | `0` |  |

**Character**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `syn.drive` | Drive | float | 1.0 .. 30.0 | `3.5` | Saturation - makes bass heavy and loud |
| `syn.crush` | Bit crush (bits) | int | 0 .. 16 | `0` | 0 = off. 4-6 = 8-bit pixel sound |
| `syn.downsample` | Sample hold | int | 1 .. 32 | `1` |  |
| `syn.volume` | Volume | float | 0.00 .. 2.00 | `1` |  |
| `syn.pan` | Pan | float | -1.00 .. 1.00 | `0` |  |

## ฟิลด์ของ section (`TSection`, 5 ฟิลด์)

**Section**

| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |
|---|---|---|---|---|---|
| `name` | Name | string | text | `Intro` |  |
| `pattern` | Pattern # | int | 0 .. 63 | `0` |  |
| `repeats` | Repeats | int | 1 .. 64 | `8` |  |
| `progression` | Progression (semis) | string | text | `0 -4 3 -2` | Transpose per repeat, cycled. "0 -4 3 -2" = i-VI-III-VII |
| `energy` | Energy | float | 0.00 .. 1.00 | `0.1` | Base intensity of this section |

---
*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*
