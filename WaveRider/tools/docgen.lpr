program docgen;
{ Writes the reference tables of docs/dev/ref_*.md straight from the code:
  every descriptor (key, caption, type, range, hint) and every built-in default
  (objects, levels, screens, sound, music, light, mesh presets).
  Usage: docgen <out dir> }

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, SysUtils, Math, StrUtils, BGRABitmapTypes, uParams, uWaveTypes, uGameData, uSynth, uMusic, uLightFx;

var
  OutDir: string;
  Doc: TStringList;

function Esc(const S: string): string;
begin
  Result := StringReplace(S, '|', '\|', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  if Length(Result) > 60 then Result := Copy(Result, 1, 57) + '...';
end;

function KindText(const D: TPDesc): string;
begin
  case D.Kind of
    pkFloat: Result := 'float';
    pkInt: Result := 'int';
    pkEnum: Result := 'enum';
    pkBool: Result := 'bool';
    pkColor: Result := 'color';
  else
    Result := 'string';
  end;
end;

function RangeText(const D: TPDesc): string;
begin
  case D.Kind of
    pkFloat: Result := FloatToInv(D.MinV, D.Decimals) + ' .. ' + FloatToInv(D.MaxV, D.Decimals);
    pkInt: Result := IntToStr(Round(D.MinV)) + ' .. ' + IntToStr(Round(D.MaxV));
    pkEnum: Result := StringReplace(D.Items, '|', ' / ', [rfReplaceAll]);
    pkBool: Result := '0 / 1';
    pkColor: Result := '#RRGGBB[AA]';
  else
    Result := 'text';
  end;
end;

function TrimZeros(const S: string): string;
begin
  Result := S;
  if Pos('.', Result) = 0 then Exit;
  while (Result <> '') and (Result[Length(Result)] = '0') do Delete(Result, Length(Result), 1);
  if (Result <> '') and (Result[Length(Result)] = '.') then Delete(Result, Length(Result), 1);
end;

function Val(const L: TPDescList; const AKey: string): string;
var
  i: Integer;
begin
  for i := 0 to High(L) do
    if SameText(L[i].Key, AKey) then
    begin
      Result := DescValueText(L[i]);
      if L[i].Kind = pkEnum then Result := EnumName(L[i].Items, PInteger(L[i].P)^);
      if L[i].Kind = pkFloat then Result := TrimZeros(Result);
      Exit(Esc(Result));
    end;
  Result := '?';
end;

procedure Line(const S: string);
begin
  Doc.Add(S);
end;

{ field table of one descriptor list; ADefaults adds the value column }
procedure FieldTable(const L: TPDescList; ADefaults: Boolean);
var
  i: Integer;
  g, row: string;
begin
  g := #0;
  for i := 0 to High(L) do
  begin
    if L[i].Group <> g then
    begin
      g := L[i].Group;
      Line('');
      Line('**' + g + '**');
      Line('');
      if ADefaults then
      begin
        Line('| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | ค่าเริ่มต้น | คำอธิบาย |');
        Line('|---|---|---|---|---|---|');
      end
      else
      begin
        Line('| key | ชื่อใน Studio | ชนิด | ช่วง / ตัวเลือก | คำอธิบาย |');
        Line('|---|---|---|---|---|');
      end;
    end;
    row := '| `' + L[i].Key + '` | ' + Esc(L[i].Caption) + ' | ' + KindText(L[i]) + ' | ' + Esc(RangeText(L[i])) + ' | ';
    if ADefaults then row := row + '`' + Val(L, L[i].Key) + '` | ';
    Line(row + Esc(L[i].Hint) + ' |');
  end;
end;

procedure Save(const AName, ATitle, AIntro: string);
begin
  Doc.Insert(0, '');
  Doc.Insert(0, '> ' + AIntro);
  Doc.Insert(0, '');
  Doc.Insert(0, '# ' + ATitle);
  Doc.Add('');
  Doc.Add('---');
  Doc.Add('*สร้างอัตโนมัติด้วย `tools/docgen` จากโค้ด — อย่าแก้ไฟล์นี้ด้วยมือ ให้รัน docgen ใหม่*');
  Doc.SaveToFile(OutDir + AName);
  Doc.Clear;
  WriteLn('  ', AName);
end;

{ ---------------- mesh ---------------- }

procedure GenMesh;
var
  p: TWaveParam;
  g: TWaveParamGroup;
  i: Integer;
  cfg: array[0..7] of TWaveConfig;
  row: string;
begin
  for i := 0 to 7 do cfg[i] := PresetConfig(i);
  Line('## พารามิเตอร์ 37 ตัว (`TWaveParam`, `ParamDefs`)');
  for g := Low(TWaveParamGroup) to High(TWaveParamGroup) do
  begin
    Line('');
    Line('**' + GroupNames[g] + '**');
    Line('');
    Line('| key | ชื่อ | ช่วง | ค่าเริ่มต้น | คำอธิบาย |');
    Line('|---|---|---|---|---|');
    for p := Low(TWaveParam) to High(TWaveParam) do
      if ParamDefs[p].Group = g then
        Line(Format('| `%s` | %s | %s .. %s | `%s` | %s |', [ParamDefs[p].Key, ParamDefs[p].Caption,
          FloatToInv(ParamDefs[p].MinV, ParamDefs[p].Decimals), FloatToInv(ParamDefs[p].MaxV, ParamDefs[p].Decimals),
          FloatToInv(ParamDefs[p].DefV, ParamDefs[p].Decimals), ParamDefs[p].Hint]));
  end;
  Line('');
  Line('## ค่าของ preset ทั้ง 8 แบบ (`PresetConfig`)');
  Line('');
  row := '| key |';
  for i := 0 to 7 do row := row + ' ' + StringReplace(PresetNames[i], ' (ภาพต้นฉบับ)', '', []) + ' |';
  Line(row);
  row := '|---|';
  for i := 0 to 7 do row := row + '---|';
  Line(row);
  for p := Low(TWaveParam) to High(TWaveParam) do
  begin
    row := '| `' + ParamDefs[p].Key + '` |';
    for i := 0 to 7 do
    begin
      if SameValue(cfg[i].Values[p], ParamDefs[p].DefV, 1e-6) then
        row := row + ' ' + FloatToInv(cfg[i].Values[p], ParamDefs[p].Decimals) + ' |'
      else
        row := row + ' **' + FloatToInv(cfg[i].Values[p], ParamDefs[p].Decimals) + '** |';
    end;
    Line(row);
  end;
  Line('');
  Line('ตัวหนา = ต่างจากค่าเริ่มต้น');
  Save('ref_mesh.md', 'อ้างอิง: พารามิเตอร์คลื่นจุด (Dotted Wave Mesh)',
    'ที่มา `DottedWave/src/uwavetypes.pas` · หน่วย px เป็น "reference px" ของภาพต้นแบบ 736×1431');
end;

{ ---------------- objects ---------------- }

procedure GenObjects;
var
  objs: TObjDefs;
  o: TObjDef;
  b: TPBuilder;
  i: Integer;
const
  COLS: array[0..13] of string = ('role', 'effect', 'motion', 'style', 'colorMode', 'radius', 'speed', 'score',
    'duration', 'power', 'letter', 'sfx', 'particles', 'shake');
var
  row: string;
  c: Integer;
begin
  o := DefaultObject('Field');
  b.Clear;
  DescribeObject(b, o);
  Line(Format('## ฟิลด์ทั้งหมดของวัตถุ (`TObjDef`, %d ฟิลด์)', [Length(b.List)]));
  Line('');
  Line('section ใน `data/objects.ini`: `[Object0]`, `[Object1]` ... · ค่าเริ่มต้นในตารางนี้มาจาก `DefaultObject(name)` ก่อนแต่ละวัตถุตั้งค่าเฉพาะ');
  FieldTable(b.List, True);
  objs := DefaultObjects;
  Line('');
  Line(Format('## วัตถุค่าเริ่มต้น %d ชนิด (`DefaultObjects`)', [Length(objs)]));
  Line('');
  row := '| # | name |';
  for c := 0 to High(COLS) do row := row + ' ' + COLS[c] + ' |';
  Line(row);
  row := '|---|---|';
  for c := 0 to High(COLS) do row := row + '---|';
  Line(row);
  for i := 0 to High(objs) do
  begin
    b.Clear;
    DescribeObject(b, objs[i]);
    row := '| ' + IntToStr(i) + ' | **' + objs[i].Name + '** |';
    for c := 0 to High(COLS) do row := row + ' ' + Val(b.List, COLS[c]) + ' |';
    Line(row);
  end;
  Line('');
  Line('## ลักษณะ (look) และสีของแต่ละวัตถุ');
  Line('');
  Line('| name | caption | color1 | color2 | glowSize | glowAlpha | pulseRate | spin | wellRadius | wellHeight | ringStrength | flash | musicSweep | pixelArt |');
  Line('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for i := 0 to High(objs) do
  begin
    b.Clear;
    DescribeObject(b, objs[i]);
    Line('| ' + objs[i].Name + ' | ' + Val(b.List, 'caption') + ' | ' + Val(b.List, 'color1') + ' | ' + Val(b.List, 'color2') +
      ' | ' + Val(b.List, 'glowSize') + ' | ' + Val(b.List, 'glowAlpha') + ' | ' + Val(b.List, 'pulseRate') +
      ' | ' + Val(b.List, 'spin') + ' | ' + Val(b.List, 'wellRadius') + ' | ' + Val(b.List, 'wellHeight') +
      ' | ' + Val(b.List, 'ringStrength') + ' | ' + Val(b.List, 'flash') + ' | ' + Val(b.List, 'musicSweep') +
      ' | ' + IfThen(objs[i].PixelArt <> '', 'มี (' + IntToStr(Length(objs[i].PixelArt)) + ' ตัวอักษร)', '-') + ' |');
  end;
  Save('ref_objects.md', 'อ้างอิง: วัตถุในเกม (Objects & Effects)', 'ที่มา `src/ugamedata.pas` — `TObjDef`, `DescribeObject`, `DefaultObjects`');
end;

{ ---------------- levels ---------------- }

procedure GenLevels;
var
  lv: TLevelDefs;
  l: TLevelDef;
  b: TPBuilder;
  i: Integer;
begin
  l := DefaultLevel;
  b.Clear;
  DescribeLevel(b, l);
  Line(Format('## ฟิลด์ทั้งหมดของด่าน (`TLevelDef`, %d ฟิลด์)', [Length(b.List)]));
  Line('');
  Line('section ใน `data/levels.ini`: `[Level0]`, `[Level1]` ... · ค่าเริ่มต้นจาก `DefaultLevel`');
  FieldTable(b.List, True);
  lv := DefaultLevels;
  Line('');
  Line(Format('## ด่านค่าเริ่มต้น %d ด่าน (`DefaultLevels`)', [Length(lv)]));
  Line('');
  Line('| # | name | subtitle | ระดับ | mesh | pixel | เวลา (s) | ชีวิต | ดาว 1/2/3 | ความเร็ว | collect/hazard/bonus rate | ramp | chain | music | anime |');
  Line('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for i := 0 to High(lv) do
  begin
    b.Clear;
    DescribeLevel(b, lv[i]);
    Line(Format('| %d | **%s** | %s | %s | %s | %s | %s | %s | %s/%s/%s | %s→%s | %s / %s / %s | %s | %s | %s | %s |',
      [i + 1, lv[i].Name, Val(b.List, 'subtitle'), Val(b.List, 'difficulty'), Val(b.List, 'mesh'),
       IfThen(lv[i].Pixel, 'ใช่ (' + IntToStr(lv[i].PixelSize) + ' px)', '-'),
       IfThen(lv[i].Duration <= 0, 'ไม่จำกัด', Val(b.List, 'duration')), Val(b.List, 'lives'),
       Val(b.List, 'star1'), Val(b.List, 'star2'), Val(b.List, 'star3'),
       Val(b.List, 'speedStart'), Val(b.List, 'speedEnd'),
       Val(b.List, 'collectRate'), Val(b.List, 'hazardRate'), Val(b.List, 'bonusRate'),
       Val(b.List, 'rateRamp'), Val(b.List, 'chain'), Val(b.List, 'musicSection'), Val(b.List, 'anime')]));
  end;
  Line('');
  Line('## ส่วนผสมการเกิดวัตถุ (spawn mix) ของแต่ละด่าน');
  Line('');
  Line('รูปแบบ `ชื่อ:น้ำหนัก` คั่นด้วยช่องว่าง โอกาสเกิด = น้ำหนัก / ผลรวมน้ำหนักในกลุ่ม');
  Line('');
  Line('| name | collectMix | hazardMix | bonusMix |');
  Line('|---|---|---|---|');
  for i := 0 to High(lv) do
    Line('| ' + lv[i].Name + ' | ' + Esc(lv[i].CollectMix) + ' | ' + Esc(lv[i].HazardMix) + ' | ' + StringReplace(lv[i].BonusMix, '|', '\|', [rfReplaceAll]) + ' |');
  Save('ref_levels.md', 'อ้างอิง: ด่าน (Levels)', 'ที่มา `src/ugamedata.pas` — `TLevelDef`, `DescribeLevel`, `DefaultLevels`');
end;

{ ---------------- screens ---------------- }

procedure GenScreens;
var
  s: array[TScreenId] of TScreenFx;
  bl: array[TScreenId] of TPBuilder;
  id: TScreenId;
  i: Integer;
  row: string;
begin
  for id := Low(TScreenId) to High(TScreenId) do
  begin
    s[id] := DefaultScreen(id);
    bl[id].Clear;
    DescribeScreen(bl[id], s[id]);
  end;
  Line(Format('## ฟิลด์ของหน้าจอ (`TScreenFx`, %d ฟิลด์)', [Length(bl[scMain].List)]));
  Line('');
  Line('section ใน `data/screens.ini`: `[Main] [Levels] [Options] [Pause] [GameOver] [Complete] [Hud] [Ready] [Light]`');
  FieldTable(bl[scMain].List, False);
  Line('');
  Line('## ค่าเริ่มต้นของทั้ง 9 หน้าจอ (`DefaultScreen`)');
  Line('');
  row := '| key |';
  for id := Low(TScreenId) to High(TScreenId) do row := row + ' ' + SCREEN_KEYS[id] + ' |';
  Line(row);
  row := '|---|';
  for id := Low(TScreenId) to High(TScreenId) do row := row + '---|';
  Line(row);
  for i := 0 to High(bl[scMain].List) do
  begin
    row := '| `' + bl[scMain].List[i].Key + '` |';
    for id := Low(TScreenId) to High(TScreenId) do row := row + ' ' + Val(bl[id].List, bl[scMain].List[i].Key) + ' |';
    Line(row);
  end;
  Save('ref_screens.md', 'อ้างอิง: หน้าจอและเมนู (Menu & Screen FX)', 'ที่มา `src/ugamedata.pas` — `TScreenFx`, `DescribeScreen`, `DefaultScreen`');
end;

{ ---------------- sound ---------------- }

procedure GenSound;
var
  bank: TSfxDefs;
  sfx: TSfxDef;
  b: TPBuilder;
  i: Integer;
  buf: TSampleBuf;
begin
  sfx := DefaultSfx('field');
  b.Clear;
  DescribeSfx(b, sfx);
  Line(Format('## ฟิลด์ของเสียง (`TSfxDef`, %d ฟิลด์ = 2 ชั้น × `TSynthParams` + echo)', [Length(b.List)]));
  Line('');
  Line('section ใน `data/sfx.ini`: `[Bank] Count` + `[Sfx0]` ... · ชั้น A ใช้ key `a.*` ชั้น B ใช้ `b.*`');
  FieldTable(b.List, True);
  bank := DefaultSfxBank;
  Line('');
  Line(Format('## เสียงค่าเริ่มต้น %d เสียง (`DefaultSfxBank`)', [Length(bank)]));
  Line('');
  Line('| # | name | ยาว (s) | A: wave | A: note | A: pitchEnv | A: cutoff | ใช้ B | B: wave | B: note | echo | gain |');
  Line('|---|---|---|---|---|---|---|---|---|---|---|---|');
  for i := 0 to High(bank) do
  begin
    buf := RenderSfx(bank[i]);
    Line(Format('| %d | **%s** | %.2f | %s | %s | %s | %.0f | %s | %s | %s | %s | %s |',
      [i, bank[i].Name, Length(buf) / SAMPLE_RATE, EnumName(WAVE_NAMES, bank[i].A.Wave), NoteName(Round(bank[i].A.BaseNote)),
       FloatToInv(bank[i].A.PitchEnv, 1), bank[i].A.Cutoff, IfThen(bank[i].UseB, 'ใช่', '-'),
       IfThen(bank[i].UseB, EnumName(WAVE_NAMES, bank[i].B.Wave), '-'), IfThen(bank[i].UseB, NoteName(Round(bank[i].B.BaseNote)), '-'),
       IfThen(bank[i].EchoMix > 0, FloatToInv(bank[i].EchoTime, 2) + ' s', '-'), FloatToInv(bank[i].Gain, 2)]));
  end;
  Save('ref_sound.md', 'อ้างอิง: เสียงประกอบ (Sound FX)', 'ที่มา `src/usynth.pas` — `TSynthParams`, `TSfxDef`, `DescribeSfx`, `DefaultSfxBank`');
end;

{ ---------------- music ---------------- }

procedure GenMusic;
var
  song: TSong;
  ins: TInstrument;
  sec: TSection;
  b: TPBuilder;
  i, t, n, c: Integer;
begin
  song := DefaultSong;
  Line(Format('## เพลงค่าเริ่มต้น: "%s"', [song.Name]));
  Line('');
  Line(Format('BPM **%s** · swing %s · master gain %s · ความยาว **%d:%.2d** นาที · %d pattern · %d section',
    [FloatToInv(song.Bpm, 0), FloatToInv(song.Swing, 2), FloatToInv(song.MasterGain, 2),
     Trunc(SongLengthSeconds(song)) div 60, Trunc(SongLengthSeconds(song)) mod 60, Length(song.Patterns), Length(song.Sections)]));
  Line('');
  Line('### Track (เครื่องดนตรี) 8 ช่อง');
  Line('');
  Line('| # | name | wave | octave | gain | pan | chord | transposable | intensityMin | intensityCutoff | intensityLfo | sidechain | kick |');
  Line('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for t := 0 to MAX_TRACKS - 1 do
    with song.Tracks[t] do
      Line(Format('| %d | **%s** | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |',
        [t, Name, EnumName(WAVE_NAMES, Synth.Wave), Synth.Octave, FloatToInv(Gain, 2), FloatToInv(Pan, 2),
         EnumName(CHORD_NAMES, Chord), IfThen(Transposable, 'ใช่', '-'), FloatToInv(IntensityMin, 2),
         FloatToInv(IntensityCutoff, 2), FloatToInv(IntensityLfo, 2), FloatToInv(Sidechain, 2), IfThen(IsKick, 'ใช่', '-')]));
  Line('');
  Line('### Section (arrangement)');
  Line('');
  Line('| # | name | pattern | repeats | progression | energy |');
  Line('|---|---|---|---|---|---|');
  for i := 0 to High(song.Sections) do
    with song.Sections[i] do
      Line(Format('| %d | **%s** | %d (%s) | %d | `%s` | %s |', [i, Name, Pattern, song.Patterns[Pattern].Name, Repeats,
        Progression, FloatToInv(Energy, 2)]));
  Line('');
  Line('### Pattern (32 step × 8 track) — จำนวนโน้ตต่อ track');
  Line('');
  Line('| # | name | ' + 'Kick | Clap | Hats | Sub | Growl | Pad | Arp | Lead |');
  Line('|---|---|---|---|---|---|---|---|---|---|');
  for i := 0 to High(song.Patterns) do
  begin
    Doc.Add('| ' + IntToStr(i) + ' | ' + song.Patterns[i].Name + ' |');
    for t := 0 to MAX_TRACKS - 1 do
    begin
      n := 0;
      for c := 0 to PAT_STEPS - 1 do if song.Patterns[i].Cells[t, c].Note > 0 then Inc(n);
      Doc[Doc.Count - 1] := Doc[Doc.Count - 1] + ' ' + IntToStr(n) + ' |';
    end;
  end;
  Line('');
  Line('ตัวอย่างรูปแบบแถวใน `music.ini` (pattern 0, track 0):');
  Line('');
  Line('```ini');
  Line('t0=' + PatternRowToText(song.Patterns[0], 0));
  Line('```');
  ins := song.Tracks[0];
  b.Clear;
  DescribeInstrument(b, ins);
  Line('');
  Line(Format('## ฟิลด์ของเครื่องดนตรี (`TInstrument`, %d ฟิลด์ = ค่าผสม + `TSynthParams`)', [Length(b.List)]));
  Line('');
  Line('ค่าเริ่มต้นในตารางคือ track 0 (Kick)');
  FieldTable(b.List, True);
  sec := song.Sections[0];
  b.Clear;
  DescribeSection(b, sec);
  Line('');
  Line(Format('## ฟิลด์ของ section (`TSection`, %d ฟิลด์)', [Length(b.List)]));
  FieldTable(b.List, True);
  Save('ref_music.md', 'อ้างอิง: เพลง (Music)', 'ที่มา `src/umusic.pas` — `TSong`, `TInstrument`, `TSection`, `TPattern`, `DefaultSong`');
end;

{ ---------------- light ---------------- }

procedure GenLight;
var
  d: array[0..3] of TLightDef;
  bl: array[0..3] of TPBuilder;
  k, i: Integer;
  row: string;
begin
  for k := 0 to 3 do
  begin
    d[k] := DefaultLightDef(k);
    bl[k].Clear;
    DescribeLightDef(bl[k], d[k]);
  end;
  Line(Format('## ฟิลด์ของแสง (`TLightDef`, %d ฟิลด์)', [Length(bl[0].List)]));
  Line('');
  Line('section ใน `data/light.ini`: `[Light0]` Prism · `[Light1]` Newton · `[Light2]` Grating · `[Light3]` Diamond');
  FieldTable(bl[0].List, False);
  Line('');
  Line('## ค่าเริ่มต้นของแสง 4 แบบ (`DefaultLightDef`)');
  Line('');
  row := '| key |';
  for k := 0 to 3 do row := row + ' ' + EnumName(LIGHT_KINDS, k) + ' |';
  Line(row);
  Line('|---|---|---|---|---|');
  for i := 0 to High(bl[0].List) do
  begin
    row := '| `' + bl[0].List[i].Key + '` |';
    for k := 0 to 3 do row := row + ' ' + Val(bl[k].List, bl[0].List[i].Key) + ' |';
    Line(row);
  end;
  Save('ref_light.md', 'อ้างอิง: แสง 4 แบบ (Light FX)', 'ที่มา `src/ulightfx.pas` — `TLightDef`, `DescribeLightDef`, `DefaultLightDef`');
end;

begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: docgen <out dir>');
    Halt(1);
  end;
  OutDir := IncludeTrailingPathDelimiter(ParamStr(1));
  ForceDirectories(OutDir);
  Doc := TStringList.Create;
  try
    WriteLn('docgen ->', OutDir);
    GenMesh;
    GenObjects;
    GenLevels;
    GenScreens;
    GenSound;
    GenMusic;
    GenLight;
  finally
    Doc.Free;
  end;
end.
