{ Light FX editor: the four optics (Dispersion Prism, Newton's Prisms,
  Diffraction Grating, Diamond). Glass, dispersion, bands, glow, grating
  orders ... with live simulation of the Light lab screen, or of the beam
  bonus in play, and "Use as beam" to pick the optic the game uses. }
unit uEdLight;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  uParams, uLightFx, uGameData, uGame, uEdBase, uPreview;

type

  { TLightEditor }

  TLightEditor = class(TListEditor)
  private
    FPreview: TGamePreview;
    FMode: TComboBox;
    FTimer: TTimer;
    FDemoCharge: Single;
    FDiaTick: Integer;
    procedure TimerTick(Sender: TObject);
    procedure RestartSim(Sender: TObject);
    procedure ModeChange(Sender: TObject);
    procedure UseBeamClick(Sender: TObject);
  protected
    function ItemCount: Integer; override;
    function ItemName(I: Integer): string; override;
    procedure DescribeItem(I: Integer; var B: TPBuilder); override;
    procedure SaveData; override;
    procedure RevertData; override;
    procedure DefaultsData; override;
    procedure ItemSelected(I: Integer); override;
  public
    constructor Create(AOwner: TComponent; AData: TGameData); reintroduce;
  end;

implementation

{ TLightEditor }

constructor TLightEditor.Create(AOwner: TComponent; AData: TGameData);
begin
  inherited CreateEditor(AOwner, AData, 'Light FX', False);
  FPreview := TGamePreview.Create(Self, AData);
  FPreview.Parent := FRight;
  FPreview.Align := alClient;
  FPreview.OnRestart := @RestartSim;
  FMode := TComboBox.Create(Self);
  FMode.Parent := FPreview.Bar;
  FMode.Style := csDropDownList;
  FMode.Items.CommaText := '"Light lab screen","Beam bonus / prism sentinel","Grating weapon (auto fire)","Diamond light bonus"';
  FMode.ItemIndex := 0;
  FMode.Width := 190;
  FMode.Left := 5000;
  FMode.Align := alLeft;
  FMode.OnChange := @ModeChange;
  FPreview.AddButton('Use as beam', @UseBeamClick);
  FDemoCharge := 3;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 2200;
  FTimer.OnTimer := @TimerTick;
  RefreshList;
  SelectItem(0);
end;

function TLightEditor.ItemCount: Integer;
begin
  Result := 4;
end;

function TLightEditor.ItemName(I: Integer): string;
begin
  Result := EnumName(LIGHT_KINDS, I);
end;

procedure TLightEditor.DescribeItem(I: Integer; var B: TPBuilder);
begin
  DescribeLightDef(B, FData.Light[I]);
end;

procedure TLightEditor.SaveData;
begin
  FData.SaveLight;
end;

procedure TLightEditor.RevertData;
var
  i: Integer;
begin
  for i := 0 to 3 do FData.Light[i] := DefaultLightDef(i);
  FData.LoadLight;
end;

procedure TLightEditor.DefaultsData;
var
  i: Integer;
begin
  for i := 0 to 3 do FData.Light[i] := DefaultLightDef(i);
end;

procedure TLightEditor.RestartSim(Sender: TObject);
var
  g: TWaveGame;
  lvl: Integer;
begin
  if FSel < 0 then Exit;
  g := FPreview.Game;
  g.LightMode := FSel;
  case FMode.ItemIndex of
    1:
      begin
        g.LightLabFocus := -1;
        g.SimLevel(1);
        g.SpawnNearShip(FData.FindObject('Spectrum'));
      end;
    2:
      begin
        g.LightLabFocus := -1;
        lvl := 0;
        while (lvl < High(FData.Levels)) and not SameText(FData.Levels[lvl].Name, 'Holo Rush') do Inc(lvl);
        g.SimLevel(lvl);
        g.DebugFire(25);
      end;
    3:
      begin
        g.LightLabFocus := -1;
        g.SimLevel(1);
        g.SpawnNearShip(FData.FindObject('Diamond'));
      end;
  else
    g.LightLabFocus := FSel;
    g.SimScreen(scLight);
  end;
end;

procedure TLightEditor.TimerTick(Sender: TObject);
begin
  { beam mode: keep handing the Light Beam bonus to the ship }
  if (FMode.ItemIndex = 1) and (FPreview.Game.State = gsPlaying) then
    FPreview.Game.SpawnNearShip(FData.FindObject('Spectrum'));
  if (FMode.ItemIndex = 3) and (FPreview.Game.State = gsPlaying) then
  begin
    Inc(FDiaTick);
    if FDiaTick mod 3 = 0 then FPreview.Game.SpawnNearShip(FData.FindObject('Diamond'));
  end;
  { grating mode: fire a fully charged shot (charge grows each time to show the scaling) }
  if (FMode.ItemIndex = 2) and (FPreview.Game.State = gsPlaying) then
  begin
    FDemoCharge := FDemoCharge * 1.8;
    if FDemoCharge > 160 then FDemoCharge := 3;
    FPreview.Game.DebugFire(FDemoCharge);
    SetStatus(Format('Grating shot with charge %.0f', [FDemoCharge]));
  end;
end;

procedure TLightEditor.ItemSelected(I: Integer);
begin
  RestartSim(nil);
end;

procedure TLightEditor.ModeChange(Sender: TObject);
begin
  RestartSim(nil);
end;

procedure TLightEditor.UseBeamClick(Sender: TObject);
begin
  if FSel < 0 then Exit;
  FPreview.Game.LightMode := FSel;
  SetStatus('The preview beam now uses ' + ItemName(FSel) +
    '  (players choose theirs in the game: LIGHT LAB or OPTIONS > BEAM LIGHT)');
end;

end.
