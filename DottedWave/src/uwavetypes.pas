{ Dotted Wave Mesh - parameter model, presets and config import/export }
unit uWaveTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, IniFiles, TypInfo, BGRABitmapTypes;

const
  APP_NAME     = 'Dotted Wave Mesh';
  APP_VERSION  = '1.0.0';
  { Reference canvas: all lengths in the config are expressed in pixels of
    this canvas, then scaled by (TargetHeight / REF_HEIGHT) at render time,
    so the look is identical at any resolution. }
  REF_WIDTH    = 736;
  REF_HEIGHT   = 1431;
  SOURCE_IMAGE = '19829fdf8954334590777efdaefd1f65.png';

type
  TWaveParam = (
    { geometry }
    wpLines, wpDotSpacing, wpDotSize, wpAmplitude, wpNoiseScale, wpOctaves,
    wpLacunarity, wpGain, wpStretchX, wpWarp, wpTilt,
    { motion }
    wpSpeed, wpDriftX, wpDriftY,
    { light }
    wpLightAzimuth, wpLightElevation, wpRelief, wpAmbient, wpDiffuse,
    wpSpecular, wpSpecPower, wpExposure, wpContrast,
    { color / post }
    wpVignette,
    { iridescent color }
    wpIriAmount, wpIriPalette, wpIriFrequency, wpIriHeight, wpIriSpread,
    wpIriSpeed, wpIriOffset, wpIriSaturation, wpIriSpecWhite,
    { interaction }
    wpRippleStrength, wpRippleRadius,
    { render }
    wpRenderScale, wpSeed);

  TWaveParamGroup = (pgGeometry, pgMotion, pgLight, pgColor, pgInteraction, pgRender);

  TWaveParamDef = record
    Key: string;
    Caption: string;
    Group: TWaveParamGroup;
    MinV, MaxV, DefV: Single;
    Decimals: Integer;
    Hint: string;
  end;

  TWaveConfig = record
    Values: array[TWaveParam] of Single;
    BgColor: TBGRAPixel;
    DotColor: TBGRAPixel;
    VSync: Boolean;
    ShowFPS: Boolean;
    Paused: Boolean;
  end;

const
  GroupNames: array[TWaveParamGroup] of string = (
    'Geometry / รูปทรง', 'Motion / การเคลื่อนไหว', 'Light / แสง',
    'Color / สี', 'Interaction / เมาส์', 'Render / การเรนเดอร์');
  GroupKeys: array[TWaveParamGroup] of string = (
    'geometry', 'motion', 'light', 'color', 'interaction', 'render');

  ParamDefs: array[TWaveParam] of TWaveParamDef = (
    (Key: 'lines';          Caption: 'Lines';           Group: pgGeometry; MinV: 20;     MaxV: 300;   DefV: 120;    Decimals: 0; Hint: 'จำนวนเส้นแนวนอนตลอดความสูงภาพ'),
    (Key: 'dotSpacing';     Caption: 'Dot spacing';     Group: pgGeometry; MinV: 1.5;    MaxV: 12;    DefV: 3.4;    Decimals: 2; Hint: 'ระยะห่างจุดตามแนวเส้น (px อ้างอิง)'),
    (Key: 'dotSize';        Caption: 'Dot size';        Group: pgGeometry; MinV: 0.5;    MaxV: 6;     DefV: 1.9;    Decimals: 2; Hint: 'ขนาดจุดสี่เหลี่ยม (px อ้างอิง)'),
    (Key: 'amplitude';      Caption: 'Amplitude';       Group: pgGeometry; MinV: 0;      MaxV: 250;   DefV: 115;     Decimals: 1; Hint: 'ระยะการยกตัวของคลื่นสูงสุด (px อ้างอิง)'),
    (Key: 'noiseScale';     Caption: 'Noise scale';     Group: pgGeometry; MinV: 0.0003; MaxV: 0.01;  DefV: 0.0017; Decimals: 4; Hint: 'ความถี่ noise ยิ่งน้อยลอนยิ่งใหญ่'),
    (Key: 'octaves';        Caption: 'Octaves';         Group: pgGeometry; MinV: 1;      MaxV: 6;     DefV: 3;      Decimals: 0; Hint: 'จำนวนชั้นรายละเอียดของ noise (fBm)'),
    (Key: 'lacunarity';     Caption: 'Lacunarity';      Group: pgGeometry; MinV: 1.2;    MaxV: 3.5;   DefV: 2.0;    Decimals: 2; Hint: 'ตัวคูณความถี่ต่อ octave'),
    (Key: 'gain';           Caption: 'Gain';            Group: pgGeometry; MinV: 0.1;    MaxV: 0.9;   DefV: 0.45;   Decimals: 2; Hint: 'ตัวคูณแอมพลิจูดต่อ octave'),
    (Key: 'stretchX';       Caption: 'Stretch X';       Group: pgGeometry; MinV: 0.1;    MaxV: 2;     DefV: 0.55;   Decimals: 2; Hint: 'ยืดลอนตามแนวนอน (<1 = ลอนยาวขึ้น)'),
    (Key: 'warp';           Caption: 'Warp X';          Group: pgGeometry; MinV: 0;      MaxV: 80;    DefV: 18;     Decimals: 1; Hint: 'บิดจุดในแนวนอน สร้างจุดบีบ/กรวย'),
    (Key: 'tilt';           Caption: 'Perspective tilt';Group: pgGeometry; MinV: 0;      MaxV: 0.6;   DefV: 0.15;   Decimals: 2; Hint: 'มุมมองเอียง: เส้นด้านบนชิดกว่าด้านล่าง'),

    (Key: 'speed';          Caption: 'Speed';           Group: pgMotion;   MinV: 0;      MaxV: 2;     DefV: 0.12;   Decimals: 3; Hint: 'ความเร็วการเปลี่ยนรูปของคลื่น'),
    (Key: 'driftX';         Caption: 'Drift X';         Group: pgMotion;   MinV: -3;     MaxV: 3;     DefV: 0.6;    Decimals: 2; Hint: 'การไหลของคลื่นแนวนอน'),
    (Key: 'driftY';         Caption: 'Drift Y';         Group: pgMotion;   MinV: -3;     MaxV: 3;     DefV: 0.25;   Decimals: 2; Hint: 'การไหลของคลื่นแนวตั้ง'),

    (Key: 'lightAzimuth';   Caption: 'Light azimuth';   Group: pgLight;    MinV: 0;      MaxV: 360;   DefV: 225;    Decimals: 0; Hint: 'ทิศแสง (องศา) 225 = ซ้ายบน'),
    (Key: 'lightElevation'; Caption: 'Light elevation'; Group: pgLight;    MinV: 2;      MaxV: 89;    DefV: 32;     Decimals: 0; Hint: 'มุมเงยของแสง (องศา) ต่ำ = เงาเข้ม'),
    (Key: 'relief';         Caption: 'Relief';          Group: pgLight;    MinV: 0;      MaxV: 10;    DefV: 2.6;    Decimals: 2; Hint: 'ขยายความชันสำหรับการคำนวณแสง'),
    (Key: 'ambient';        Caption: 'Ambient';         Group: pgLight;    MinV: 0;      MaxV: 1;     DefV: 0.07;   Decimals: 3; Hint: 'แสงพื้นฐาน (ในเงา)'),
    (Key: 'diffuse';        Caption: 'Diffuse';         Group: pgLight;    MinV: 0;      MaxV: 2;     DefV: 1.0;    Decimals: 2; Hint: 'แสงกระจาย Lambert'),
    (Key: 'specular';       Caption: 'Specular';        Group: pgLight;    MinV: 0;      MaxV: 2;     DefV: 0.6;   Decimals: 2; Hint: 'ประกายบนสันคลื่น (Blinn-Phong)'),
    (Key: 'specPower';      Caption: 'Spec power';      Group: pgLight;    MinV: 1;      MaxV: 128;   DefV: 20;     Decimals: 0; Hint: 'ความคมของประกาย'),
    (Key: 'exposure';       Caption: 'Exposure';        Group: pgLight;    MinV: 0.1;    MaxV: 4;     DefV: 1.45;    Decimals: 2; Hint: 'ความสว่างรวม'),
    (Key: 'contrast';       Caption: 'Contrast (gamma)';Group: pgLight;    MinV: 0.3;    MaxV: 5;     DefV: 1.5;    Decimals: 2; Hint: 'ยกกำลังความสว่าง: สูง = เงาลึก'),

    (Key: 'vignette';       Caption: 'Vignette';        Group: pgColor;    MinV: 0;      MaxV: 1.5;   DefV: 0.25;   Decimals: 2; Hint: 'ขอบภาพมืดลง'),
    (Key: 'iriAmount';      Caption: 'Iridescent mix';  Group: pgColor;    MinV: 0;      MaxV: 1;     DefV: 0;      Decimals: 2; Hint: 'ผสมสีรุ้งประกายมุก 0 = ขาวดำ, 1 = Iridescent เต็มที่'),
    (Key: 'iriPalette';     Caption: 'Iri palette';     Group: pgColor;    MinV: 0;      MaxV: 4;     DefV: 1;      Decimals: 0; Hint: 'ชุดสี: 0 Rainbow, 1 Pearl, 2 Oil slick, 3 Holographic, 4 Beetle'),
    (Key: 'iriFrequency';   Caption: 'Iri angle bands'; Group: pgColor;    MinV: 0;      MaxV: 10;    DefV: 1.2;    Decimals: 2; Hint: 'จำนวนแถบสีตามมุมเอียงของผิว (thin-film)'),
    (Key: 'iriHeight';      Caption: 'Iri by height';   Group: pgColor;    MinV: 0;      MaxV: 4;     DefV: 0.4;    Decimals: 2; Hint: 'เปลี่ยนสีตามความสูงของคลื่น'),
    (Key: 'iriSpread';      Caption: 'Iri by position'; Group: pgColor;    MinV: 0;      MaxV: 4;     DefV: 0.5;    Decimals: 2; Hint: 'ไล่สีตามตำแหน่งบนจอ (แนวทแยง)'),
    (Key: 'iriSpeed';       Caption: 'Iri hue speed';   Group: pgColor;    MinV: 0;      MaxV: 10;    DefV: 1.0;    Decimals: 2; Hint: 'ความเร็วการหมุนเฉดสีตาม phase'),
    (Key: 'iriOffset';      Caption: 'Iri hue offset';  Group: pgColor;    MinV: 0;      MaxV: 1;     DefV: 0;      Decimals: 3; Hint: 'เลื่อนเฉดสีทั้งชุด'),
    (Key: 'iriSaturation';  Caption: 'Iri saturation';  Group: pgColor;    MinV: 0;      MaxV: 1.5;   DefV: 1.2;   Decimals: 2; Hint: 'ความอิ่มของสี'),
    (Key: 'iriSpecWhite';   Caption: 'Iri spec white';  Group: pgColor;    MinV: 0;      MaxV: 1;     DefV: 0.35;    Decimals: 2; Hint: 'ประกาย specular เป็นสีขาว (สมจริงแบบมุก)'),

    (Key: 'rippleStrength'; Caption: 'Ripple strength'; Group: pgInteraction; MinV: 0;   MaxV: 3;     DefV: 0.9;    Decimals: 2; Hint: 'แรงกระเพื่อมเมื่อคลิก/ลากเมาส์'),
    (Key: 'rippleRadius';   Caption: 'Ripple radius';   Group: pgInteraction; MinV: 20;  MaxV: 600;   DefV: 160;    Decimals: 0; Hint: 'รัศมีการกระเพื่อม (px อ้างอิง)'),

    (Key: 'renderScale';    Caption: 'Render scale';    Group: pgRender;   MinV: 0.25;   MaxV: 2;     DefV: 1.0;    Decimals: 2; Hint: 'ความละเอียดภายในเทียบขนาดหน้าต่าง'),
    (Key: 'seed';           Caption: 'Seed';            Group: pgRender;   MinV: 0;      MaxV: 9999;  DefV: 7;      Decimals: 0; Hint: 'ค่าสุ่มของ noise')
  );

  PresetNames: array[0..7] of string = (
    'Original (ภาพต้นฉบับ)', 'Calm Silk', 'Storm', 'Dense Fabric', 'Sound Wave',
    'Iridescent Pearl', 'Holographic', 'Oil Slick');
  IriPaletteNames: array[0..4] of string = (
    'Rainbow', 'Pearl', 'Oil slick', 'Holographic', 'Beetle');

function DefaultConfig: TWaveConfig;
function PresetConfig(AIndex: Integer): TWaveConfig;
function ClampParam(P: TWaveParam; V: Single): Single;
function FindParam(const AKey: string; out P: TWaveParam): Boolean;

function ColorToHex(const C: TBGRAPixel): string;
function HexToColor(const S: string; const ADefault: TBGRAPixel): TBGRAPixel;
function FloatToInv(V: Single; Decimals: Integer = 6): string;
function InvToFloat(const S: string; ADefault: Single): Single;

procedure SaveConfigIni(const C: TWaveConfig; const AFileName: string);
function LoadConfigIni(const AFileName: string; const ABase: TWaveConfig): TWaveConfig;
function ConfigToJSON(const C: TWaveConfig): string;
function ConfigToPascal(const C: TWaveConfig): string;

implementation

var
  InvFS: TFormatSettings;

function DefaultConfig: TWaveConfig;
var
  p: TWaveParam;
begin
  for p := Low(TWaveParam) to High(TWaveParam) do
    Result.Values[p] := ParamDefs[p].DefV;
  Result.BgColor := BGRA(0, 0, 0, 255);
  Result.DotColor := BGRA(242, 242, 242, 255);
  Result.VSync := True;
  Result.ShowFPS := True;
  Result.Paused := False;
end;

function PresetConfig(AIndex: Integer): TWaveConfig;
begin
  Result := DefaultConfig;
  case AIndex of
    1: begin { Calm Silk }
         Result.Values[wpAmplitude] := 55;
         Result.Values[wpNoiseScale] := 0.0011;
         Result.Values[wpOctaves] := 2;
         Result.Values[wpSpeed] := 0.07;
         Result.Values[wpRelief] := 2.4;
         Result.Values[wpSpecular] := 0.8;
         Result.Values[wpSpecPower] := 32;
         Result.Values[wpContrast] := 1.6;
       end;
    2: begin { Storm }
         Result.Values[wpAmplitude] := 160;
         Result.Values[wpNoiseScale] := 0.0026;
         Result.Values[wpOctaves] := 4;
         Result.Values[wpSpeed] := 0.35;
         Result.Values[wpDriftX] := 1.4;
         Result.Values[wpWarp] := 30;
         Result.Values[wpRelief] := 4.5;
         Result.Values[wpContrast] := 2.4;
       end;
    3: begin { Dense Fabric }
         Result.Values[wpLines] := 200;
         Result.Values[wpDotSpacing] := 2.4;
         Result.Values[wpDotSize] := 1.2;
         Result.Values[wpAmplitude] := 70;
         Result.Values[wpRelief] := 3.6;
       end;
    4: begin { Sound Wave }
         Result.Values[wpLines] := 70;
         Result.Values[wpDotSpacing] := 4.5;
         Result.Values[wpDotSize] := 2.2;
         Result.Values[wpStretchX] := 1.4;
         Result.Values[wpTilt] := 0.0;
         Result.Values[wpSpeed] := 0.5;
         Result.Values[wpDriftY] := 0;
         Result.Values[wpWarp] := 0;
         Result.DotColor := BGRA(170, 220, 255, 255);
         Result.BgColor := BGRA(2, 4, 10, 255);
       end;
    5: begin { Iridescent Pearl }
         Result.Values[wpIriAmount] := 1;
         Result.Values[wpIriPalette] := 1;
         Result.Values[wpIriFrequency] := 1.2;
         Result.Values[wpIriSaturation] := 1.4;
         Result.Values[wpExposure] := 1.6;
       end;
    6: begin { Holographic }
         Result.Values[wpIriAmount] := 1;
         Result.Values[wpIriPalette] := 3;
         Result.Values[wpIriFrequency] := 2;
         Result.Values[wpIriSpread] := 1.2;
         Result.Values[wpIriSpeed] := 2;
         Result.Values[wpIriSaturation] := 1.1;
         Result.Values[wpSpecular] := 0.9;
         Result.Values[wpExposure] := 1.7;
         Result.BgColor := BGRA(5, 2, 10, 255);
       end;
    7: begin { Oil Slick }
         Result.Values[wpIriAmount] := 1;
         Result.Values[wpIriPalette] := 2;
         Result.Values[wpIriFrequency] := 2.5;
         Result.Values[wpIriHeight] := 0.9;
         Result.Values[wpIriSaturation] := 1.0;
         Result.Values[wpAmplitude] := 140;
         Result.Values[wpRelief] := 3.5;
         Result.Values[wpExposure] := 1.7;
         Result.Values[wpContrast] := 1.3;
         Result.BgColor := BGRA(3, 3, 6, 255);
       end;
  end;
end;

function ClampParam(P: TWaveParam; V: Single): Single;
begin
  Result := EnsureRange(V, ParamDefs[P].MinV, ParamDefs[P].MaxV);
  if ParamDefs[P].Decimals = 0 then
    Result := Round(Result);
end;

function FindParam(const AKey: string; out P: TWaveParam): Boolean;
var
  q: TWaveParam;
begin
  for q := Low(TWaveParam) to High(TWaveParam) do
    if SameText(ParamDefs[q].Key, AKey) then
    begin
      P := q;
      Exit(True);
    end;
  Result := False;
end;

function ColorToHex(const C: TBGRAPixel): string;
begin
  Result := '#' + IntToHex(C.red, 2) + IntToHex(C.green, 2) + IntToHex(C.blue, 2);
end;

function HexToColor(const S: string; const ADefault: TBGRAPixel): TBGRAPixel;
var
  h: string;
  v: LongInt;
begin
  h := Trim(S);
  if (h <> '') and (h[1] = '#') then Delete(h, 1, 1);
  if (Length(h) <> 6) or not TryStrToInt('$' + h, v) then
    Exit(ADefault);
  Result := BGRA((v shr 16) and 255, (v shr 8) and 255, v and 255, 255);
end;

function FloatToInv(V: Single; Decimals: Integer): string;
begin
  Result := FloatToStrF(V, ffFixed, 15, Decimals, InvFS);
end;

function InvToFloat(const S: string; ADefault: Single): Single;
var
  d: Double;
begin
  if TryStrToFloat(Trim(S), d, InvFS) then Result := d else Result := ADefault;
end;

procedure SaveConfigIni(const C: TWaveConfig; const AFileName: string);
var
  ini: TMemIniFile;
  p: TWaveParam;
begin
  ini := TMemIniFile.Create(AFileName);
  try
    ini.Clear;
    ini.WriteString('Meta', 'App', APP_NAME);
    ini.WriteString('Meta', 'Version', APP_VERSION);
    ini.WriteInteger('Meta', 'RefWidth', REF_WIDTH);
    ini.WriteInteger('Meta', 'RefHeight', REF_HEIGHT);
    for p := Low(TWaveParam) to High(TWaveParam) do
      ini.WriteString('Params', ParamDefs[p].Key, FloatToInv(C.Values[p], ParamDefs[p].Decimals + 2));
    ini.WriteString('Colors', 'Background', ColorToHex(C.BgColor));
    ini.WriteString('Colors', 'Dots', ColorToHex(C.DotColor));
    ini.WriteBool('Flags', 'VSync', C.VSync);
    ini.WriteBool('Flags', 'ShowFPS', C.ShowFPS);
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

function LoadConfigIni(const AFileName: string; const ABase: TWaveConfig): TWaveConfig;
var
  ini: TMemIniFile;
  p: TWaveParam;
begin
  Result := ABase;
  if not FileExists(AFileName) then Exit;
  ini := TMemIniFile.Create(AFileName);
  try
    for p := Low(TWaveParam) to High(TWaveParam) do
      Result.Values[p] := ClampParam(p,
        InvToFloat(ini.ReadString('Params', ParamDefs[p].Key, ''), ABase.Values[p]));
    Result.BgColor := HexToColor(ini.ReadString('Colors', 'Background', ''), ABase.BgColor);
    Result.DotColor := HexToColor(ini.ReadString('Colors', 'Dots', ''), ABase.DotColor);
    Result.VSync := ini.ReadBool('Flags', 'VSync', ABase.VSync);
    Result.ShowFPS := ini.ReadBool('Flags', 'ShowFPS', ABase.ShowFPS);
  finally
    ini.Free;
  end;
end;

function JsonStr(const S: string): string;
var
  i: Integer;
begin
  Result := '"';
  for i := 1 to Length(S) do
    case S[i] of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: ;
    else
      Result := Result + S[i];
    end;
  Result := Result + '"';
end;

function ConfigToJSON(const C: TWaveConfig): string;
var
  sl: TStringList;
  p: TWaveParam;
  d: TWaveParamDef;
  sep: string;
begin
  sl := TStringList.Create;
  try
    sl.Add('{');
    sl.Add('  "name": ' + JsonStr(APP_NAME) + ',');
    sl.Add('  "version": ' + JsonStr(APP_VERSION) + ',');
    sl.Add('  "generated": ' + JsonStr(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)) + ',');
    sl.Add('  "reference": { "width": ' + IntToStr(REF_WIDTH) + ', "height": ' + IntToStr(REF_HEIGHT) +
           ', "source": ' + JsonStr(SOURCE_IMAGE) + ', "units": "reference px (scale = targetHeight / 1431)" },');
    sl.Add('  "style": { "keywords": ["dark mode","monochrome","particle wave","dotted mesh","generative"], ' +
           '"dotShape": "square", "blend": "additive", "lightModel": "lambert + blinn-phong" },');
    sl.Add('  "colors": { "background": ' + JsonStr(ColorToHex(C.BgColor)) +
           ', "dots": ' + JsonStr(ColorToHex(C.DotColor)) + ' },');
    sl.Add('  "flags": { "vsync": ' + BoolToStr(C.VSync, 'true', 'false') +
           ', "showFps": ' + BoolToStr(C.ShowFPS, 'true', 'false') + ' },');
    sl.Add('  "params": {');
    for p := Low(TWaveParam) to High(TWaveParam) do
    begin
      d := ParamDefs[p];
      if p = High(TWaveParam) then sep := '' else sep := ',';
      sl.Add('    ' + JsonStr(d.Key) + ': { "value": ' + FloatToInv(C.Values[p], d.Decimals + 2) +
             ', "default": ' + FloatToInv(d.DefV, d.Decimals + 2) +
             ', "min": ' + FloatToInv(d.MinV, d.Decimals + 2) +
             ', "max": ' + FloatToInv(d.MaxV, d.Decimals + 2) +
             ', "group": ' + JsonStr(GroupKeys[d.Group]) +
             ', "label": ' + JsonStr(d.Caption) +
             ', "description": ' + JsonStr(d.Hint) + ' }' + sep);
    end;
    sl.Add('  }');
    sl.Add('}');
    Result := sl.Text;
  finally
    sl.Free;
  end;
end;

function ConfigToPascal(const C: TWaveConfig): string;
var
  sl: TStringList;
  p: TWaveParam;
begin
  sl := TStringList.Create;
  try
    sl.Add('{ ' + APP_NAME + ' preset - generated ' + FormatDateTime('yyyy-mm-dd hh:nn', Now) + ' }');
    sl.Add('{ usage: uses uWaveTypes; ... ApplyWavePreset(Config); }');
    sl.Add('procedure ApplyWavePreset(var C: TWaveConfig);');
    sl.Add('begin');
    sl.Add('  C := DefaultConfig;');
    for p := Low(TWaveParam) to High(TWaveParam) do
      sl.Add(Format('  C.Values[%s] := %s; { %s }',
        [GetEnumName(TypeInfo(TWaveParam), Ord(p)), FloatToInv(C.Values[p], ParamDefs[p].Decimals + 2), ParamDefs[p].Caption]));
    sl.Add(Format('  C.BgColor := BGRA(%d, %d, %d);', [C.BgColor.red, C.BgColor.green, C.BgColor.blue]));
    sl.Add(Format('  C.DotColor := BGRA(%d, %d, %d);', [C.DotColor.red, C.DotColor.green, C.DotColor.blue]));
    sl.Add('  C.VSync := ' + BoolToStr(C.VSync, 'True', 'False') + ';');
    sl.Add('end;');
    Result := sl.Text;
  finally
    sl.Free;
  end;
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
