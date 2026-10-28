{ Screen / menu effects editor: every game screen (main menu, level select,
  options, pause, game over, level clear, HUD, ready countdown) with a live
  simulation of that screen. }
unit uEdScreens;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  uParams, uGameData, uEdBase, uPreview;

type

  { TScreenEditor }

  TScreenEditor = class(TListEditor)
  private
    FPreview: TGamePreview;
    procedure RestartSim(Sender: TObject);
    procedure CopyStyleClick(Sender: TObject);
    procedure ResetOneClick(Sender: TObject);
  protected
    function ItemCount: Integer; override;
    function ItemName(I: Integer): string; override;
    procedure DescribeItem(I: Integer; var B: TPBuilder); override;
    procedure SaveData; override;
    procedure RevertData; override;
    procedure DefaultsData; override;
    procedure ItemSelected(I: Integer); override;
    procedure ParamChanged(const AKey: string); override;
  public
    constructor Create(AOwner: TComponent; AData: TGameData); reintroduce;
  end;

implementation

{ TScreenEditor }

constructor TScreenEditor.Create(AOwner: TComponent; AData: TGameData);
begin
  inherited CreateEditor(AOwner, AData, 'Menu & Screen FX', False);
  TopButton('Reset this screen', @ResetOneClick);
  TopButton('Copy title style to all screens', @CopyStyleClick);
  FPreview := TGamePreview.Create(Self, AData);
  FPreview.Parent := FRight;
  FPreview.Align := alClient;
  FPreview.OnRestart := @RestartSim;
  RefreshList;
  SelectItem(0);
end;

function TScreenEditor.ItemCount: Integer;
begin
  Result := Ord(High(TScreenId)) + 1;
end;

function TScreenEditor.ItemName(I: Integer): string;
begin
  Result := SCREEN_NAMES[TScreenId(I)];
end;

procedure TScreenEditor.DescribeItem(I: Integer; var B: TPBuilder);
begin
  DescribeScreen(B, FData.Screens[TScreenId(I)]);
end;

procedure TScreenEditor.SaveData;
begin
  FData.SaveScreens;
end;

procedure TScreenEditor.RevertData;
var
  s: TScreenId;
begin
  for s := Low(TScreenId) to High(TScreenId) do FData.Screens[s] := DefaultScreen(s);
  FData.LoadScreens;
  FPreview.Game.DataChanged;
end;

procedure TScreenEditor.DefaultsData;
var
  s: TScreenId;
begin
  for s := Low(TScreenId) to High(TScreenId) do FData.Screens[s] := DefaultScreen(s);
  FPreview.Game.DataChanged;
end;

procedure TScreenEditor.RestartSim(Sender: TObject);
begin
  if FSel >= 0 then FPreview.Game.SimScreen(TScreenId(FSel));
end;

procedure TScreenEditor.ItemSelected(I: Integer);
begin
  FPreview.Game.SimScreen(TScreenId(I));
end;

procedure TScreenEditor.ParamChanged(const AKey: string);
begin
  { dotted text layouts are cached by text / size / spacing: drop them }
  FPreview.Game.DataChanged;
end;

procedure TScreenEditor.ResetOneClick(Sender: TObject);
begin
  if FSel < 0 then Exit;
  FData.Screens[TScreenId(FSel)] := DefaultScreen(TScreenId(FSel));
  FParams.RefreshValues;
  FPreview.Game.DataChanged;
  MarkDirty;
end;

procedure TScreenEditor.CopyStyleClick(Sender: TObject);
var
  s: TScreenId;
  src: TScreenFx;
begin
  if FSel < 0 then Exit;
  if MessageDlg('Copy the dotted title style (dots, wave, shimmer, palette, glow, menu colors) of "' +
    ItemName(FSel) + '" to every screen?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  src := FData.Screens[TScreenId(FSel)];
  for s := Low(TScreenId) to High(TScreenId) do
  begin
    FData.Screens[s].DotSpacing := src.DotSpacing;
    FData.Screens[s].DotSize := src.DotSize;
    FData.Screens[s].DotRound := src.DotRound;
    FData.Screens[s].DotWave := src.DotWave;
    FData.Screens[s].DotWaveFreq := src.DotWaveFreq;
    FData.Screens[s].DotWaveSpeed := src.DotWaveSpeed;
    FData.Screens[s].Shimmer := src.Shimmer;
    FData.Screens[s].ShimmerSpeed := src.ShimmerSpeed;
    FData.Screens[s].Palette := src.Palette;
    FData.Screens[s].Saturation := src.Saturation;
    FData.Screens[s].HueSpeed := src.HueSpeed;
    FData.Screens[s].HueScale := src.HueScale;
    FData.Screens[s].Glow := src.Glow;
    FData.Screens[s].MenuColor := src.MenuColor;
    FData.Screens[s].MenuSelMode := src.MenuSelMode;
    FData.Screens[s].MenuGlow := src.MenuGlow;
    FData.Screens[s].TextColor := src.TextColor;
  end;
  FPreview.Game.DataChanged;
  MarkDirty;
  SetStatus('Style copied to all screens');
end;

end.
