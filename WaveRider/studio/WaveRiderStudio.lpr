program WaveRiderStudio;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SysUtils,
  uSimplexNoise, uWaveTypes, uWaveEngine, uPlatform, uParams, uSynth, uMusic, uAudio,
  uGameData, uGfx, uGame, uGameView,
  uParamPanel, uPreview, uEdBase, uEdScreens, uEdSound, uEdMusic, uEdLevels, uEdObjects, uEdLight, uStudioMain;

{$R *.res}

{ WaveRiderStudio.exe [--open=screens|sound|music|levels|objects|light] }
procedure OpenFromCommandLine;
var
  i: Integer;
  s: string;
begin
  for i := 1 to ParamCount do
  begin
    s := LowerCase(ParamStr(i));
    if Pos('--open=', s) = 1 then
    begin
      Delete(s, 1, 7);
      if s = 'screens' then StudioForm.PendingOpen := 0
      else if s = 'sound' then StudioForm.PendingOpen := 1
      else if s = 'music' then StudioForm.PendingOpen := 2
      else if s = 'levels' then StudioForm.PendingOpen := 3
      else if s = 'objects' then StudioForm.PendingOpen := 4
      else if s = 'light' then StudioForm.PendingOpen := 5;
    end;
  end;
end;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Title := 'WaveRider Studio';
  Application.Initialize;
  Application.CreateForm(TStudioForm, StudioForm);
  OpenFromCommandLine;
  Application.Run;
end.
