{ TGamePreview - live simulation panel used by every Studio editor.

  Runs a private TWaveGame on the shared TGameData, so any edit in any editor
  shows up in the next frame. Toolbar: Restart, Pause, Autopilot, Invincible,
  Sound, speed (x1 / x2 / x4), mouse = play the simulation yourself. }
unit uPreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  BGRABitmap, BGRABitmapTypes, uGameData, uGame, uGameView;

type

  { TGamePreview }

  TGamePreview = class(TPanel)
  private
    FBar: TPanel;
    FBox: TPaintBox;
    FTimer: TTimer;
    FView: TGameRenderer;
    FGame: TWaveGame;
    FLast: QWord;
    FInfo: TLabel;
    FSpeed: TComboBox;
    FFit: TRect;
    FChkPause, FChkAuto, FChkInv, FChkSound: TCheckBox;
    FFrames: Integer;
    FFpsClock: QWord;
    FFps: Single;
    procedure Tick(Sender: TObject);
    procedure BoxPaint(Sender: TObject);
    procedure BoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ChkChange(Sender: TObject);
    procedure RestartClick(Sender: TObject);
    function MapToGame(X, Y: Integer; out GX, GY: Single): Boolean;
  public
    OnRestart: TNotifyEvent;     { editor restarts its own simulation mode }
    OnOverlay: TNotifyEvent;     { editor may draw on Frame after the game }
    Frame: TBGRABitmap;
    MaxRenderHeight: Integer;
    constructor Create(AOwner: TComponent; AData: TGameData); reintroduce;
    destructor Destroy; override;
    function AddButton(const ACaption: string; AOnClick: TNotifyEvent): TButton;
    procedure SetSound(AOn: Boolean);
    property Game: TWaveGame read FGame;
    property Box: TPaintBox read FBox;
    property Bar: TPanel read FBar;
  end;

implementation

uses
  uAudio;

{ TGamePreview }

constructor TGamePreview.Create(AOwner: TComponent; AData: TGameData);

  function Chk(const ACaption: string; AChecked: Boolean): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := FBar;
    Result.Caption := ACaption;
    Result.Checked := AChecked;
    Result.Left := FBar.ControlCount * 1000;
    Result.Align := alLeft;
    Result.BorderSpacing.Right := 6;
    Result.OnChange := @ChkChange;
  end;

var
  b: TButton;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clBlack;
  MaxRenderHeight := 820;
  FGame := TWaveGame.Create(AData, '');
  FGame.SoundOn := False;
  FView := TGameRenderer.Create;

  FBar := TPanel.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alTop;
  FBar.Height := 30;
  FBar.BevelOuter := bvNone;
  FBar.Color := clBtnFace;
  FBar.BorderSpacing.Bottom := 2;

  b := TButton.Create(Self);
  b.Parent := FBar;
  b.Caption := 'Restart';
  b.Width := 64;
  b.Left := 0;
  b.Align := alLeft;
  b.OnClick := @RestartClick;
  FChkPause := Chk('Pause', False);
  FChkAuto := Chk('Autopilot', True);
  FChkInv := Chk('Invincible', True);
  FChkSound := Chk('Sound', False);
  FSpeed := TComboBox.Create(Self);
  FSpeed.Parent := FBar;
  FSpeed.Style := csDropDownList;
  FSpeed.Items.CommaText := 'x0.5,x1,x2,x4';
  FSpeed.ItemIndex := 1;
  FSpeed.Width := 58;
  FSpeed.Left := FBar.ControlCount * 1000;
  FSpeed.Align := alLeft;

  FInfo := TLabel.Create(Self);
  FInfo.Parent := Self;
  FInfo.Align := alBottom;
  FInfo.Font.Color := clSilver;
  FInfo.Caption := '';
  FInfo.BorderSpacing.Around := 2;

  FBox := TPaintBox.Create(Self);
  FBox.Parent := Self;
  FBox.Align := alClient;
  FBox.OnPaint := @BoxPaint;
  FBox.OnMouseMove := @BoxMouseMove;
  FBox.OnMouseDown := @BoxMouseDown;
  FBox.OnMouseUp := @BoxMouseUp;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 15;
  FTimer.OnTimer := @Tick;
  FLast := GetTickCount64;
  FFpsClock := FLast;
end;

destructor TGamePreview.Destroy;
begin
  FTimer.Enabled := False;
  FView.Free;
  FGame.Free;
  inherited Destroy;
end;

function TGamePreview.AddButton(const ACaption: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FBar;
  Result.Caption := ACaption;
  Result.AutoSize := True;
  Result.Left := FBar.ControlCount * 1000;
  Result.Align := alLeft;
  Result.BorderSpacing.Left := 4;
  Result.OnClick := AOnClick;
end;

procedure TGamePreview.SetSound(AOn: Boolean);
begin
  FChkSound.Checked := AOn;
  FGame.SoundOn := AOn and (Audio <> nil);
end;

procedure TGamePreview.ChkChange(Sender: TObject);
begin
  FGame.Autopilot := FChkAuto.Checked;
  FGame.Invincible := FChkInv.Checked;
  FGame.SoundOn := FChkSound.Checked and (Audio <> nil);
  if not FChkAuto.Checked then FGame.UseMouse := True;
end;

procedure TGamePreview.RestartClick(Sender: TObject);
begin
  if Assigned(OnRestart) then OnRestart(Self);
  ChkChange(nil);
end;

procedure TGamePreview.Tick(Sender: TObject);
var
  now: QWord;
  dt: Single;
  steps, i: Integer;
  h, w: Integer;
begin
  if not IsVisible then Exit;
  now := GetTickCount64;
  dt := EnsureRange((now - FLast) / 1000, 0, 0.05);
  FLast := now;
  if not FChkPause.Checked then
  begin
    case FSpeed.ItemIndex of
      0: begin steps := 1; dt := dt * 0.5; end;
      2: steps := 2;
      3: steps := 4;
    else
      steps := 1;
    end;
    for i := 1 to steps do FGame.Update(dt);
  end
  else
    FGame.TickTime(dt);
  FGame.Autopilot := FChkAuto.Checked;
  FGame.Invincible := FChkInv.Checked;

  { fit portrait 736:1431 inside the paint box }
  h := Max(16, FBox.Height);
  w := Round(h * 736 / 1431);
  if w > FBox.Width then
  begin
    w := Max(16, FBox.Width);
    h := Round(w * 1431 / 736);
  end;
  FFit := Rect((FBox.Width - w) div 2, (FBox.Height - h) div 2, (FBox.Width - w) div 2 + w, (FBox.Height - h) div 2 + h);
  if h > MaxRenderHeight then
  begin
    w := Round(w * MaxRenderHeight / h);
    h := MaxRenderHeight;
  end;
  Frame := FView.Render(FGame, w, h);
  if Assigned(OnOverlay) then OnOverlay(Self);
  FBox.Invalidate;

  Inc(FFrames);
  if now - FFpsClock >= 500 then
  begin
    FFps := FFrames * 1000 / (now - FFpsClock);
    FFrames := 0;
    FFpsClock := now;
    FInfo.Caption := Format(' %s   %.0f fps   %.1f ms   score %d   x%d   lives %d   t %.1fs   objects %d',
      [FGame.StateName, FFps, FView.Engine.RenderMs, FGame.Score, FGame.Combo, FGame.Lives, FGame.PlayTime,
       FGame.EntityCount]);
  end;
end;

procedure TGamePreview.BoxPaint(Sender: TObject);
begin
  FBox.Canvas.Brush.Color := clBlack;
  FBox.Canvas.FillRect(0, 0, FBox.Width, FBox.Height);
  if Frame <> nil then
    Frame.Draw(FBox.Canvas, FFit, True);
end;

function TGamePreview.MapToGame(X, Y: Integer; out GX, GY: Single): Boolean;
begin
  Result := (FFit.Width > 0) and (FFit.Height > 0);
  GX := (X - FFit.Left) / Max(1, FFit.Width);
  GY := (Y - FFit.Top) / Max(1, FFit.Height);
end;

procedure TGamePreview.BoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  gx, gy: Single;
begin
  if not MapToGame(X, Y, gx, gy) then Exit;
  if FChkAuto.Checked and (FGame.State = gsPlaying) then Exit;
  FGame.MouseAt(X - FFit.Left, Y - FFit.Top, Max(1, FFit.Width), Max(1, FFit.Height));
end;

procedure TGamePreview.BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  gx, gy: Single;
begin
  if not MapToGame(X, Y, gx, gy) then Exit;
  if Button = mbLeft then FGame.Click(X - FFit.Left, Y - FFit.Top, Max(1, FFit.Width), Max(1, FFit.Height))
  else FGame.Action(gaBack);
end;

procedure TGamePreview.BoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then FGame.FireUp;
end;

end.
