{ Generic parameter descriptors.

  A descriptor points at a field of a record (float, int, enum, bool, color,
  string) and carries its metadata (caption, range, hint, group). The same
  descriptor list drives:
    - INI load / save (uParams)
    - the editor property panels (uParamPanel)
  so adding a field to a data record only needs one Add* line. }
unit uParams;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, Math, IniFiles, BGRABitmapTypes;

type
  TPKind = (pkFloat, pkInt, pkEnum, pkBool, pkColor, pkString);

  TPDesc = record
    Key, Caption, Hint, Group: string;
    Kind: TPKind;
    MinV, MaxV: Single;
    Decimals: Integer;
    Items: string;          { pkEnum: names separated by '|' }
    P: Pointer;             { PSingle / PInteger / PBoolean / PBGRAPixel / PString }
  end;

  TPDescList = array of TPDesc;

  { TPBuilder - fluent helper to build descriptor lists }

  TPBuilder = record
    List: TPDescList;
    Group: string;
    procedure Clear;
    procedure G(const AGroup: string);
    procedure F(const AKey, ACaption: string; P: PSingle; AMin, AMax: Single; ADec: Integer; const AHint: string = '');
    procedure I(const AKey, ACaption: string; P: PInteger; AMin, AMax: Integer; const AHint: string = '');
    procedure E(const AKey, ACaption: string; P: PInteger; const AItems: string; const AHint: string = '');
    procedure B(const AKey, ACaption: string; P: PBoolean; const AHint: string = '');
    procedure C(const AKey, ACaption: string; P: PBGRAPixel; const AHint: string = '');
    procedure S(const AKey, ACaption: string; P: PString; const AHint: string = '');
  end;

function FloatToInv(V: Single; Decimals: Integer = 4): string;
function InvToFloat(const S: string; ADefault: Single): Single;
function ColorToHex(const C: TBGRAPixel): string;
function HexToColor(const S: string; const ADefault: TBGRAPixel): TBGRAPixel;
function EnumName(const AItems: string; AIndex: Integer): string;
function EnumIndex(const AItems, AName: string; ADefault: Integer): Integer;
function EnumCount(const AItems: string): Integer;

procedure WriteDescs(Ini: TCustomIniFile; const ASection: string; const L: TPDescList);
procedure ReadDescs(Ini: TCustomIniFile; const ASection: string; const L: TPDescList);
function DescValueText(const D: TPDesc): string;

implementation

var
  InvFS: TFormatSettings;

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

function ColorToHex(const C: TBGRAPixel): string;
begin
  Result := '#' + IntToHex(C.red, 2) + IntToHex(C.green, 2) + IntToHex(C.blue, 2);
  if C.alpha <> 255 then Result := Result + IntToHex(C.alpha, 2);
end;

function HexToColor(const S: string; const ADefault: TBGRAPixel): TBGRAPixel;
var
  h: string;
  v: LongInt;
begin
  h := Trim(S);
  if (h <> '') and (h[1] = '#') then Delete(h, 1, 1);
  if (Length(h) = 6) and TryStrToInt('$' + h, v) then
    Exit(BGRA((v shr 16) and 255, (v shr 8) and 255, v and 255, 255));
  if (Length(h) = 8) and TryStrToInt('$' + Copy(h, 1, 6), v) then
  begin
    Result := BGRA((v shr 16) and 255, (v shr 8) and 255, v and 255, 255);
    if TryStrToInt('$' + Copy(h, 7, 2), v) then Result.alpha := v;
    Exit;
  end;
  Result := ADefault;
end;

function EnumName(const AItems: string; AIndex: Integer): string;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Delimiter := '|';
    sl.StrictDelimiter := True;
    sl.DelimitedText := AItems;
    if (AIndex >= 0) and (AIndex < sl.Count) then Result := sl[AIndex] else Result := IntToStr(AIndex);
  finally
    sl.Free;
  end;
end;

function EnumIndex(const AItems, AName: string; ADefault: Integer): Integer;
var
  sl: TStringList;
  i: Integer;
begin
  Result := ADefault;
  sl := TStringList.Create;
  try
    sl.Delimiter := '|';
    sl.StrictDelimiter := True;
    sl.DelimitedText := AItems;
    for i := 0 to sl.Count - 1 do
      if SameText(sl[i], Trim(AName)) then Exit(i);
    if TryStrToInt(Trim(AName), i) and (i >= 0) and (i < sl.Count) then Result := i;
  finally
    sl.Free;
  end;
end;

function EnumCount(const AItems: string): Integer;
var
  i: Integer;
begin
  if AItems = '' then Exit(0);
  Result := 1;
  for i := 1 to Length(AItems) do
    if AItems[i] = '|' then Inc(Result);
end;

{ TPBuilder }

procedure TPBuilder.Clear;
begin
  List := nil;
  Group := '';
end;

procedure TPBuilder.G(const AGroup: string);
begin
  Group := AGroup;
end;

procedure AddDesc(var L: TPDescList; const D: TPDesc);
begin
  SetLength(L, Length(L) + 1);
  L[High(L)] := D;
end;

procedure TPBuilder.F(const AKey, ACaption: string; P: PSingle; AMin, AMax: Single; ADec: Integer; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkFloat; d.MinV := AMin; d.MaxV := AMax; d.Decimals := ADec; d.P := P;
  AddDesc(List, d);
end;

procedure TPBuilder.I(const AKey, ACaption: string; P: PInteger; AMin, AMax: Integer; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkInt; d.MinV := AMin; d.MaxV := AMax; d.P := P;
  AddDesc(List, d);
end;

procedure TPBuilder.E(const AKey, ACaption: string; P: PInteger; const AItems: string; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkEnum; d.Items := AItems; d.MinV := 0; d.MaxV := EnumCount(AItems) - 1; d.P := P;
  AddDesc(List, d);
end;

procedure TPBuilder.B(const AKey, ACaption: string; P: PBoolean; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkBool; d.P := P;
  AddDesc(List, d);
end;

procedure TPBuilder.C(const AKey, ACaption: string; P: PBGRAPixel; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkColor; d.P := P;
  AddDesc(List, d);
end;

procedure TPBuilder.S(const AKey, ACaption: string; P: PString; const AHint: string);
var
  d: TPDesc;
begin
  d := Default(TPDesc);
  d.Key := AKey; d.Caption := ACaption; d.Hint := AHint; d.Group := Group;
  d.Kind := pkString; d.P := P;
  AddDesc(List, d);
end;

function DescValueText(const D: TPDesc): string;
begin
  case D.Kind of
    pkFloat: Result := FloatToInv(PSingle(D.P)^, Max(D.Decimals, 0) + 2);
    pkInt: Result := IntToStr(PInteger(D.P)^);
    pkEnum: Result := EnumName(D.Items, PInteger(D.P)^);
    pkBool: Result := BoolToStr(PBoolean(D.P)^, '1', '0');
    pkColor: Result := ColorToHex(PBGRAPixel(D.P)^);
    pkString: Result := PString(D.P)^;
  else
    Result := '';
  end;
end;

procedure WriteDescs(Ini: TCustomIniFile; const ASection: string; const L: TPDescList);
var
  i: Integer;
begin
  for i := 0 to High(L) do
    Ini.WriteString(ASection, L[i].Key, DescValueText(L[i]));
end;

procedure ReadDescs(Ini: TCustomIniFile; const ASection: string; const L: TPDescList);
var
  i: Integer;
  s: string;
begin
  for i := 0 to High(L) do
  begin
    if not Ini.ValueExists(ASection, L[i].Key) then Continue;
    s := Ini.ReadString(ASection, L[i].Key, '');
    case L[i].Kind of
      pkFloat: PSingle(L[i].P)^ := EnsureRange(InvToFloat(s, PSingle(L[i].P)^), L[i].MinV, L[i].MaxV);
      pkInt: PInteger(L[i].P)^ := EnsureRange(StrToIntDef(s, PInteger(L[i].P)^), Round(L[i].MinV), Round(L[i].MaxV));
      pkEnum: PInteger(L[i].P)^ := EnumIndex(L[i].Items, s, PInteger(L[i].P)^);
      pkBool: PBoolean(L[i].P)^ := (s = '1') or SameText(s, 'true');
      pkColor: PBGRAPixel(L[i].P)^ := HexToColor(s, PBGRAPixel(L[i].P)^);
      pkString: PString(L[i].P)^ := s;
    end;
  end;
end;

initialization
  InvFS := DefaultFormatSettings;
  InvFS.DecimalSeparator := '.';
  InvFS.ThousandSeparator := #0;

end.
