program WaveRider;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, Math, BGRABitmap,
  uSimplexNoise, uWaveTypes, uWaveEngine, uPlatform, uParams, uSynth, uMusic, uAudio,
  uGameData, uGfx, uGame, uGameView, uGameForm, uAnime;

{$R *.res}

{ Headless screenshot (no window, no audio):
    WaveRider.exe --shot out.png [seconds] [mode] [level]
  modes: menu levels options light ready play beam watch charge grate pause over complete object
  "play" runs the autopilot simulation of [level]. }
function HeadlessShot: Boolean;
var
  fn, mode: string;
  secs: Single;
  lvl, i, steps: Integer;
  data: TGameData;
  game: TWaveGame;
  view: TGameRenderer;
  frame: TBGRABitmap;
  log: TStringList;
  t0: TDateTime;
begin
  Result := (ParamCount >= 2) and (ParamStr(1) = '--shot');
  if not Result then Exit;
  fn := ParamStr(2);
  secs := StrToFloatDef(ParamStr(3), 6);
  mode := LowerCase(ParamStr(4));
  if mode = '' then mode := 'play';
  lvl := StrToIntDef(ParamStr(5), 1);
  RandSeed := 1234;
  data := TGameData.Create(FindDataDir);
  data.LoadAll;
  game := TWaveGame.Create(data, '');
  view := TGameRenderer.Create;
  log := TStringList.Create;
  try
    game.SetField(736, 1431);
    if mode = 'menu' then game.SimScreen(scMain)
    else if mode = 'levels' then game.SimScreen(scLevels)
    else if mode = 'options' then game.SimScreen(scOptions)
    else if mode = 'ready' then game.SimScreen(scReady)
    else if mode = 'object' then game.SimObject(lvl, 0)
    else if mode = 'light' then game.SimScreen(scLight)
    else if mode = 'perf' then game.SimLevel(lvl)
    else if mode = 'watch' then game.StartShow
    else game.SimLevel(lvl);
    steps := Round(secs * 60);
    for i := 1 to steps do
    begin
      { beam test: hand the Light Beam bonus to the ship every 4 seconds }
      if (mode = 'beam') and (i mod 240 = 30) then game.SpawnNearShip(data.FindObject('Spectrum'));
      if (mode = 'diamond') and (i mod 360 = 30) then game.SpawnNearShip(data.FindObject('Diamond'));
      game.Update(1 / 60);
      if (mode = 'watch') and (i mod 300 = 0) then
        log.Add(Format('t=%4ds  %-9s level %2d  lives %d  score %6d  combo x%d',
          [i div 60, game.StateName, game.Level + 1, game.Lives, game.Score, game.Combo]));
      if (mode = 'watch') and not game.IsShow then Break;
    end;
    if mode = 'watch' then log.SaveToFile(ChangeFileExt(fn, '.log'));
    if mode = 'showctl' then
    begin
      { WATCH BOT controls without a window: 736 x 1431 frame = reference px }
      game.StartShow;
      for i := 1 to 300 do game.Update(1 / 60);
      log.Add('start: ' + game.StateName + ' show=' + BoolToStr(game.IsShow, True));
      game.Click(0.32 * game.FieldW, 1431 - 108, 736, 1431);          { PAUSE button }
      for i := 1 to 30 do game.Update(1 / 60);
      log.Add('click PAUSE: ' + game.StateName + ' show=' + BoolToStr(game.IsShow, True));
      frame := view.Render(game, 736, 1431); frame.SaveToFile(ChangeFileExt(fn, '_paused.png'));
      game.Action(gaPause);                                             { P = resume }
      for i := 1 to 120 do game.Update(1 / 60);
      log.Add('key P: ' + game.StateName + ' show=' + BoolToStr(game.IsShow, True));
      game.Action(gaPause);                                             { P / Space / right click = pause }
      log.Add('key P again: ' + game.StateName);
      game.Click(736 / 2, 0.48 * 1431 + 62 * 0, 736, 1431);             { pause menu: RESUME (mouse) }
      for i := 1 to 120 do game.Update(1 / 60);
      log.Add('click RESUME: ' + game.StateName);
      frame := view.Render(game, 736, 1431); frame.SaveToFile(ChangeFileExt(fn, '_running.png'));
      game.Click(0.68 * game.FieldW, 1431 - 108, 736, 1431);           { EXIT button }
      log.Add('click EXIT: ' + game.StateName + ' show=' + BoolToStr(game.IsShow, True));
      game.StartShow;
      for i := 1 to 200 do game.Update(1 / 60);
      game.Action(gaBack);                                              { Esc = exit }
      log.Add('key Esc: ' + game.StateName + ' show=' + BoolToStr(game.IsShow, True));
      log.SaveToFile(ChangeFileExt(fn, '.log'));
    end;
    if mode = 'play' then
    begin
      log.Add(Format('newton spawns %d  kills %d  score %d  lives %d', [game.NewtonSpawns, game.NewtonKills, game.Score, game.Lives]));
      log.SaveToFile(ChangeFileExt(fn, '.log'));
    end;
    if mode = 'perf' then
    begin
      AnimeDbg := StrToIntDef(GetEnvironmentVariable('ADBG'), 0);
      { time the full frame pipeline of an anime level at window size (463 x 900) }
      t0 := Now;
      steps := 0; lvl := 0;
      for i := 1 to 600 do
      begin
        game.Update(1 / 60);
        frame := view.Render(game, 463, 900);
        if game.AnimeVisible then Inc(steps);
        if game.AnimeShown then Inc(lvl);
      end;
      log.Add(Format('anime level frame avg %.2f ms  visible %d  shown %d of 600', [(Now - t0) * 86400000 / 600, steps, lvl]));
      log.SaveToFile(ChangeFileExt(fn, '.log'));
    end;
    if mode = 'diamond' then
    begin
      log.Add(Format('diamond catches %d  score %d', [game.DiamondCatches, game.Score]));
      log.SaveToFile(ChangeFileExt(fn, '.log'));
    end;
    if mode = 'beam' then
    begin
      log.Add(Format('prism frames %d  solved %d (%.0f%%)  kills %d',
        [game.PrismFrames, game.PrismSolvedFrames, 100 * game.PrismSolvedFrames / Max(1, game.PrismFrames), game.PrismKills]));
      log.SaveToFile(ChangeFileExt(fn, '.log'));
    end;
    if (mode = 'charge') or (mode = 'grate') then
    begin
      game.GratingPower := 120;
      game.FireDown;
      for i := 1 to 100 do game.Update(1 / 60);
      if mode = 'grate' then
      begin
        game.FireUp;
        for i := 1 to 16 do game.Update(1 / 60);
      end;
    end;
    if mode = 'pause' then game.SimScreen(scPause)
    else if mode = 'over' then game.SimScreen(scGameOver)
    else if mode = 'complete' then game.SimScreen(scComplete);
    if (mode = 'pause') or (mode = 'over') or (mode = 'complete') then
      for i := 1 to 40 do game.Update(1 / 60);
    frame := view.Render(game, 736, 1431);
    frame.SaveToFile(fn);
  finally
    log.Free;
    view.Free;
    game.Free;
    data.Free;
  end;
end;

begin
  if HeadlessShot then Exit;
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Title := 'WAVE RIDER';
  Application.Initialize;
  Application.CreateForm(TGameForm, GameForm);
  Application.Run;
end.
