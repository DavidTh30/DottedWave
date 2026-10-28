{ WAVE RIDER - game window: TOpenGLControl + BGRAOpenGL, vsync paced loop,
  audio engine, data folder (shared with WaveRider Studio) }
unit uGameForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, LCLType,
  OpenGLContext, BGRABitmap, BGRABitmapTypes, BGRAOpenGL,
  uWaveTypes, uGameData, uGame, uGameView, uAudio;

type

  { TGameForm }

  TGameForm = class(TForm)
  private
    FGL: TOpenGLControl;
    FBuf: TBGLBitmap;
    FView: TGameRenderer;
    FData: TGameData;
    FGame: TWaveGame;
    FLastTime: Double;
    FVSyncSet: Boolean;
    FPrevBounds: TRect;
    FFrames: Integer;
    FFpsClock, FFps: Double;
    FShowFps: Boolean;
    procedure GLPaint(Sender: TObject);
    procedure GLMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GLMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GLMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure AppIdle(Sender: TObject; var Done: Boolean);
    procedure AppDeactivate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetKey(Key: Word; ADown: Boolean);
    procedure ToggleFullScreen;
    procedure ReloadData;
    procedure UpdateCursor;
    function RenderScale: Single;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  GameForm: TGameForm;

implementation

uses
  uPlatform;

{ TGameForm }

constructor TGameForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner);
  Caption := 'WAVE RIDER';
  Color := clBlack;
  KeyPreview := True;
  Position := poScreenCenter;
  ClientHeight := Min(900, Screen.WorkAreaHeight - 80);
  ClientWidth := Round(ClientHeight * REF_WIDTH / REF_HEIGHT);
  OnKeyDown := @FormKeyDown;
  OnKeyUp := @FormKeyUp;

  Randomize;
  FData := TGameData.Create(FindDataDir);
  if not FileExists(FData.LevelsFile) then
  begin
    try
      FData.SaveAll;            { first run: write the defaults so Studio can edit them }
    except
    end;
  end;
  FData.LoadAll;

  Audio := TAudioEngine.Create;
  Audio.SetBank(FData.Sfx);
  Audio.SetSong(FData.Song);
  Audio.Music.Playing := True;
  Audio.Start;

  FGame := TWaveGame.Create(FData, ExtractFilePath(Application.ExeName) + 'waverider.ini');
  FView := TGameRenderer.Create;

  FGL := TOpenGLControl.Create(Self);
  FGL.Parent := Self;
  FGL.Align := alClient;
  FGL.AutoResizeViewport := True;
  FGL.DoubleBuffered := True;
  FGL.Cursor := crNone;
  FGL.OnPaint := @GLPaint;
  FGL.OnMouseMove := @GLMouseMove;
  FGL.OnMouseDown := @GLMouseDown;
  FGL.OnMouseUp := @GLMouseUp;

  FLastTime := NowSeconds;
  FFpsClock := FLastTime;
  { --demo N: autopilot simulation of level N with the fps overlay (no input needed) }
  if (ParamCount >= 2) and (ParamStr(1) = '--demo') then
  begin
    FShowFps := True;
    FGame.SimLevel(StrToIntDef(ParamStr(2), 0));
  end;
  Application.AddOnIdleHandler(@AppIdle);
  Application.AddOnDeactivateHandler(@AppDeactivate);
end;

destructor TGameForm.Destroy;
begin
  Application.RemoveOnIdleHandler(@AppIdle);
  Application.RemoveOnDeactivateHandler(@AppDeactivate);
  if Audio <> nil then Audio.Stop;
  FBuf.Free;
  FView.Free;
  FGame.Free;
  FreeAndNil(Audio);
  FData.Free;
  inherited Destroy;
end;

procedure TGameForm.ReloadData;
begin
  FData.LoadAll;
  FGame.DataChanged;
  Audio.SetBank(FData.Sfx);
  Audio.SetSong(FData.Song);
  Audio.Music.Playing := True;
  FGame.GoMenu;
end;

function TGameForm.RenderScale: Single;
begin
  Result := Min(1, Sqrt(520000 / Max(1, FGL.Width * FGL.Height)));
end;

procedure TGameForm.AppIdle(Sender: TObject; var Done: Boolean);
begin
  if WindowState = wsMinimized then
  begin
    Done := True;
    Exit;
  end;
  FGL.Invalidate;
  Done := False;
end;

procedure TGameForm.AppDeactivate(Sender: TObject);
begin
  { the bot show keeps running when the window loses focus }
  if (FGame.State = gsPlaying) and not FGame.IsShow then FGame.Action(gaPause);
end;

procedure TGameForm.GLPaint(Sender: TObject);
var
  w, h, rw, rh, m, sx, sy: Integer;
  t, dt: Double;
  frame: TBGRABitmap;
begin
  if not FVSyncSet then
  begin
    SetSwapInterval(1);
    FVSyncSet := True;
  end;
  t := NowSeconds;
  dt := EnsureRange(t - FLastTime, 0, 0.05);
  FLastTime := t;

  w := FGL.Width; h := FGL.Height;
  if (w < 2) or (h < 2) then Exit;
  rw := Max(8, Round(w * RenderScale));
  rh := Max(8, Round(h * RenderScale));

  FGame.SetField(rw, rh);
  FGame.Update(dt);
  if FGame.RequestQuit then
  begin
    FGame.RequestQuit := False;
    Close;
    Exit;
  end;
  if FGame.RequestFullscreen then
  begin
    FGame.RequestFullscreen := False;
    if FGame.Fullscreen <> (BorderStyle = bsNone) then ToggleFullScreen;
  end;

  UpdateCursor;
  frame := FView.Render(FGame, rw, rh);
  if FShowFps then
  begin
    frame.FontName := 'Consolas';
    frame.FontHeight := 12;
    frame.FontStyle := [];
    frame.TextOut(6, rh - 18, Format('%.0f fps  %.1f ms  %dx%d  %s  audio:%s',
      [FFps, FView.Engine.RenderMs, rw, rh, FGame.StateName, BoolToStr(Audio.DeviceOk, 'on', 'off')]),
      BGRA(255, 255, 255, 160));
  end;

  if FBuf = nil then FBuf := TBGLBitmap.Create(rw, rh)
  else if (FBuf.Width <> rw) or (FBuf.Height <> rh) then FBuf.SetSize(rw, rh);
  FBuf.PutImage(0, 0, frame, dmSet);

  BGLViewPort(w, h, BGRABlack);
  m := Round(FGame.Shake * 14);
  sx := 0; sy := 0;
  if m > 0 then
  begin
    sx := Random(2 * m + 1) - m;
    sy := Random(2 * m + 1) - m;
  end;
  if FGame.PixelSize > 0 then FBuf.Texture.ResampleFilter := orfBox
  else FBuf.Texture.ResampleFilter := orfLinear;
  BGLCanvas.StretchPutImage(sx - m, sy - m, w + 2 * m, h + 2 * m, FBuf.Texture);
  FGL.SwapBuffers;

  Inc(FFrames);
  if t - FFpsClock >= 0.5 then
  begin
    FFps := FFrames / (t - FFpsClock);
    FFrames := 0;
    FFpsClock := t;
  end;
end;

procedure TGameForm.GLMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  FGame.MouseAt(X, Y, Max(1, FGL.Width), Max(1, FGL.Height));
  UpdateCursor;
end;

procedure TGameForm.UpdateCursor;
var
  c: TCursor;
begin
  case FGame.CursorKind of
    0: c := crNone;
    2: c := crHandPoint;
  else
    c := crDefault;
  end;
  if FGL.Cursor <> c then FGL.Cursor := c;
end;

procedure TGameForm.GLMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    FGame.Click(X, Y, Max(1, FGL.Width), Max(1, FGL.Height))
  else if Button = mbRight then
  begin
    if FGame.IsShow then FGame.Action(gaPause) else FGame.Action(gaBack);
  end;
end;

procedure TGameForm.GLMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then FGame.FireUp;
end;

procedure TGameForm.SetKey(Key: Word; ADown: Boolean);
begin
  case Key of
    VK_LEFT, VK_A: FGame.KeyLeft := ADown;
    VK_RIGHT, VK_D: FGame.KeyRight := ADown;
    VK_UP, VK_W: FGame.KeyUp := ADown;
    VK_DOWN, VK_S: FGame.KeyDown := ADown;
  end;
end;

procedure TGameForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  SetKey(Key, True);
  case Key of
    VK_UP, VK_W: FGame.Action(gaUp);
    VK_DOWN, VK_S: FGame.Action(gaDown);
    VK_LEFT, VK_A: FGame.Action(gaLeft);
    VK_RIGHT, VK_D: FGame.Action(gaRight);
    VK_SPACE:
      if FGame.IsShow then FGame.Action(gaPause)
      else if FGame.State = gsPlaying then FGame.FireDown
      else FGame.Action(gaConfirm);
    VK_RETURN: FGame.Action(gaConfirm);
    VK_ESCAPE, VK_BACK: FGame.Action(gaBack);
    VK_P: FGame.Action(gaPause);
    VK_F11:
      begin
        FGame.Fullscreen := not FGame.Fullscreen;
        ToggleFullScreen;
      end;
    VK_F3: FShowFps := not FShowFps;
    VK_F5: ReloadData;
  end;
end;

procedure TGameForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  SetKey(Key, False);
  if Key = VK_SPACE then FGame.FireUp;
end;

procedure TGameForm.ToggleFullScreen;
begin
  if BorderStyle <> bsNone then
  begin
    FPrevBounds := BoundsRect;
    BorderStyle := bsNone;
    BoundsRect := Monitor.BoundsRect;
  end
  else
  begin
    BorderStyle := bsSizeable;
    BoundsRect := FPrevBounds;
  end;
end;

end.
