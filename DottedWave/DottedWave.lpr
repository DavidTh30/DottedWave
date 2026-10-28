program DottedWave;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, BGRABitmap,
  uSimplexNoise, uWaveTypes, uWaveEngine, uPlatform, uMainForm, uControlForm;

{$R *.res}

{ Headless export:
    DottedWave.exe --export out.png [width height phase] [--config file.ini]
    DottedWave.exe --spec spec.json [--config file.ini]
    DottedWave.exe --pascal preset.inc [--config file.ini]
    --preset N  start from preset N (0..7) instead of defaults }

procedure SaveText(const AFileName, AText: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := AText;
    sl.SaveToFile(AFileName);
  finally
    sl.Free;
  end;
end;

function HeadlessExport: Boolean;
var
  i, w, h: Integer;
  fn, ini, spec, pas: string;
  preset: Integer;
  phase: Double;
  cfg: TWaveConfig;
  bmp: TBGRABitmap;
  eng: TWaveEngine;
begin
  Result := False;
  fn := ''; ini := ''; spec := ''; pas := ''; preset := -1;
  w := REF_WIDTH; h := REF_HEIGHT; phase := 0;
  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '--export' then
    begin
      Inc(i); fn := ParamStr(i);
      if (i + 2 <= ParamCount) and (StrToIntDef(ParamStr(i + 1), -1) > 0) then
      begin
        w := StrToInt(ParamStr(i + 1)); h := StrToInt(ParamStr(i + 2)); Inc(i, 2);
        if (i + 1 <= ParamCount) and (Copy(ParamStr(i + 1), 1, 2) <> '--') then
        begin
          phase := InvToFloat(ParamStr(i + 1), 0); Inc(i);
        end;
      end;
    end
    else if ParamStr(i) = '--spec' then
    begin
      Inc(i); spec := ParamStr(i);
    end
    else if ParamStr(i) = '--pascal' then
    begin
      Inc(i); pas := ParamStr(i);
    end
    else if ParamStr(i) = '--preset' then
    begin
      Inc(i); preset := StrToIntDef(ParamStr(i), 0);
    end
    else if ParamStr(i) = '--config' then
    begin
      Inc(i); ini := ParamStr(i);
    end;
    Inc(i);
  end;
  if (fn = '') and (spec = '') and (pas = '') then Exit;
  Result := True;
  if preset >= 0 then cfg := PresetConfig(preset) else cfg := DefaultConfig;
  cfg := LoadConfigIni(ini, cfg);
  if spec <> '' then SaveText(spec, ConfigToJSON(cfg));
  if pas <> '' then SaveText(pas, ConfigToPascal(cfg));
  if fn = '' then Exit;
  bmp := TBGRABitmap.Create(w, h);
  eng := TWaveEngine.Create;
  try
    eng.Render(bmp, cfg, phase, 0);
    bmp.SaveToFile(fn);
  finally
    eng.Free;
    bmp.Free;
  end;
end;

begin
  if HeadlessExport then Exit;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Title := 'Dotted Wave Mesh';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
