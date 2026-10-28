{ Dotted Wave Mesh - main window: TOpenGLControl + BGRAOpenGL, vsync paced loop }
unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, LCLType,
  OpenGLContext, BGRABitmap, BGRABitmapTypes, BGRAOpenGL,
  uWaveTypes, uWaveEngine;

type

  { TMainForm }

  TMainForm = class(TForm)
  private
    FGL: TOpenGLControl;
    FBuf: TBGLBitmap;
    FEngine: TWaveEngine;
    FPhase, FRealTime, FLastTime: Double;
    FFrames: Integer;
    FFpsClock: Double;
    FFps: Double;
    FVSyncApplied: Integer;
    FVSyncOk: Boolean;
    FMouseDown: Boolean;
    FPrevBounds: TRect;
    FConfigFile: string;
    procedure GLPaint(Sender: TObject);
    procedure GLMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GLMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GLMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure AppIdle(Sender: TObject; var Done: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure SetRipple(X, Y: Integer);
  public
    Config: TWaveConfig;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure ToggleControls;
    procedure ToggleFullScreen;
    procedure QuickExport;
    property Phase: Double read FPhase write FPhase;
    property RealTime: Double read FRealTime;
    property Fps: Double read FFps;
    property VSyncOk: Boolean read FVSyncOk;
    property Engine: TWaveEngine read FEngine;
  end;

var
  MainForm: TMainForm;

implementation

uses
  uPlatform, uControlForm;

{ TMainForm }

constructor TMainForm.Create(TheOwner: TComponent);
begin
  { No .lfm: build the UI in code }
  inherited CreateNew(TheOwner);
  Caption := APP_NAME;
  Color := clBlack;
  KeyPreview := True;
  Position := poScreenCenter;
  { keep the 736:1431 portrait ratio of the reference image }
  ClientHeight := Min(900, Screen.WorkAreaHeight - 80);
  ClientWidth := Round(ClientHeight * REF_WIDTH / REF_HEIGHT);
  OnKeyDown := @FormKeyDown;
  OnClose := @FormClose;

  FConfigFile := ExtractFilePath(Application.ExeName) + 'dottedwave.ini';
  Config := LoadConfigIni(FConfigFile, DefaultConfig);

  FEngine := TWaveEngine.Create;
  { FBuf (TBGLBitmap) is created in the first paint: it needs a current GL context }
  FVSyncApplied := -1;

  FGL := TOpenGLControl.Create(Self);
  FGL.Parent := Self;
  FGL.Align := alClient;
  FGL.AutoResizeViewport := True;
  FGL.DoubleBuffered := True;
  FGL.OnPaint := @GLPaint;
  FGL.OnMouseDown := @GLMouseDown;
  FGL.OnMouseMove := @GLMouseMove;
  FGL.OnMouseUp := @GLMouseUp;

  FLastTime := NowSeconds;
  FFpsClock := FLastTime;
  Application.AddOnIdleHandler(@AppIdle);
end;

destructor TMainForm.Destroy;
begin
  Application.RemoveOnIdleHandler(@AppIdle);
  FBuf.Free;
  FEngine.Free;
  inherited Destroy;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  try
    SaveConfigIni(Config, FConfigFile);
  except
    { read-only folder: ignore }
  end;
end;

procedure TMainForm.AppIdle(Sender: TObject; var Done: Boolean);
begin
  if (WindowState = wsMinimized) or not Visible then
  begin
    Done := True;
    Exit;
  end;
  { With vsync on, SwapBuffers blocks until the next vblank, so this loop
    is paced by the display refresh rate. }
  FGL.Invalidate;
  Done := False;
end;

procedure TMainForm.GLPaint(Sender: TObject);
var
  w, h, rw, rh: Integer;
  sc: Single;
  t, dt: Double;
  s: string;
begin
  if FVSyncApplied <> Ord(Config.VSync) then
  begin
    FVSyncOk := SetSwapInterval(Ord(Config.VSync));
    FVSyncApplied := Ord(Config.VSync);
  end;

  t := NowSeconds;
  dt := t - FLastTime;
  FLastTime := t;
  if dt > 0.1 then dt := 0.1;
  if dt < 0 then dt := 0;
  FRealTime := FRealTime + dt;
  if not Config.Paused then
    FPhase := FPhase + dt * Config.Values[wpSpeed];
  if not FMouseDown then
    FEngine.Ripple.Energy := FEngine.Ripple.Energy * Exp(-dt * 1.4);

  w := FGL.Width; h := FGL.Height;
  if (w < 2) or (h < 2) then Exit;
  sc := EnsureRange(Config.Values[wpRenderScale], 0.25, 2);
  rw := Max(2, Round(w * sc));
  rh := Max(2, Round(h * sc));
  if FBuf = nil then
    FBuf := TBGLBitmap.Create(rw, rh)
  else if (FBuf.Width <> rw) or (FBuf.Height <> rh) then
    FBuf.SetSize(rw, rh);

  FEngine.Render(FBuf, Config, FPhase, FRealTime);

  if Config.ShowFPS then
  begin
    s := Format('%.0f fps  |  %d dots  |  %.1f ms  |  %dx%d  |  vsync %s',
      [FFps, FEngine.DotCount, FEngine.RenderMs, rw, rh,
       BoolToStr(Config.VSync and FVSyncOk, 'on', 'off')]);
    FBuf.FontHeight := Max(11, Round(13 * sc));
    FBuf.FontQuality := fqSystemClearType;
    FBuf.TextOut(9, 7, s, BGRA(0, 0, 0, 200));
    FBuf.TextOut(8, 6, s, BGRA(255, 255, 255, 190));
  end;

  BGLViewPort(w, h, BGRABlack);
  if (rw = w) and (rh = h) then
    BGLCanvas.PutImage(0, 0, FBuf.Texture)
  else
    BGLCanvas.StretchPutImage(0, 0, w, h, FBuf.Texture);
  FGL.SwapBuffers;

  Inc(FFrames);
  if t - FFpsClock >= 0.5 then
  begin
    FFps := FFrames / (t - FFpsClock);
    FFrames := 0;
    FFpsClock := t;
  end;
end;

procedure TMainForm.SetRipple(X, Y: Integer);
begin
  FEngine.Ripple.X := X / Max(1, FGL.Width);
  FEngine.Ripple.Y := Y / Max(1, FGL.Height);
  FEngine.Ripple.Energy := 1;
end;

procedure TMainForm.GLMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FMouseDown := True;
    SetRipple(X, Y);
  end
  else if Button = mbRight then
    ToggleControls;
end;

procedure TMainForm.GLMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FMouseDown then SetRipple(X, Y);
end;

procedure TMainForm.GLMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then FMouseDown := False;
end;

procedure TMainForm.ToggleControls;
begin
  if ControlForm = nil then
    ControlForm := TControlForm.Create(Application);
  if ControlForm.Visible then
    ControlForm.Hide
  else
  begin
    ControlForm.Show;
    ControlForm.SyncFromConfig;
  end;
end;

procedure TMainForm.ToggleFullScreen;
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

procedure TMainForm.QuickExport;
var
  bmp: TBGRABitmap;
  eng: TWaveEngine;
  dir, fn: string;
begin
  dir := ExtractFilePath(Application.ExeName) + 'exports' + PathDelim;
  ForceDirectories(dir);
  fn := dir + 'dottedwave_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.png';
  bmp := TBGRABitmap.Create(REF_WIDTH, REF_HEIGHT);
  eng := TWaveEngine.Create;
  try
    eng.Render(bmp, Config, FPhase, FRealTime);
    bmp.SaveToFile(fn);
  finally
    eng.Free;
    bmp.Free;
  end;
  Caption := APP_NAME + '  -  saved ' + ExtractFileName(fn);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_F1, VK_TAB: ToggleControls;
    VK_SPACE: begin
        Config.Paused := not Config.Paused;
        if Assigned(ControlForm) then ControlForm.SyncFromConfig;
      end;
    VK_F11: ToggleFullScreen;
    VK_ESCAPE: if BorderStyle = bsNone then ToggleFullScreen;
    VK_V: begin
        Config.VSync := not Config.VSync;
        if Assigned(ControlForm) then ControlForm.SyncFromConfig;
      end;
    VK_F: begin
        Config.ShowFPS := not Config.ShowFPS;
        if Assigned(ControlForm) then ControlForm.SyncFromConfig;
      end;
    VK_S: if ssCtrl in Shift then QuickExport;
    VK_R: FPhase := 0;
  else
    Exit;
  end;
  Key := 0;
end;

end.
