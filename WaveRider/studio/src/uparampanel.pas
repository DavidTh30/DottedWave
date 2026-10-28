{ TParamPanel - property editor generated from a uParams descriptor list.

  float  -> label + trackbar + float spin
  int    -> label + spin
  enum   -> label + combo
  bool   -> check box
  color  -> label + color button
  string -> label + edit

  Every write goes through OnBeforeWrite / OnAfterWrite so the music editor
  can hold the audio lock while the audio thread reads the same record. }
unit uParamPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls, Spin, Dialogs,
  BGRABitmapTypes, uParams;

type
  TParamCtl = record
    Track: TTrackBar;
    FSpin: TFloatSpinEdit;
    ISpin: TSpinEdit;
    Combo: TComboBox;
    Check: TCheckBox;
    ColorBtn: TColorButton;
    Edit: TEdit;
  end;

  TParamChangeEvent = procedure(Sender: TObject; const AKey: string) of object;

  { TParamPanel }

  TParamPanel = class(TScrollBox)
  private
    FDescs: TPDescList;
    FCtl: array of TParamCtl;
    FUpdating: Boolean;
    FHost: TWinControl;
    procedure ClearControls;
    function RowPanel(AParent: TWinControl; AHeight: Integer): TPanel;
    function MakeLabel(AParent: TWinControl; const D: TPDesc): TLabel;
    procedure DoChange(AIndex: Integer);
    procedure TrackChange(Sender: TObject);
    procedure FSpinChange(Sender: TObject);
    procedure ISpinChange(Sender: TObject);
    procedure ComboChange(Sender: TObject);
    procedure CheckChange(Sender: TObject);
    procedure ColorChange(Sender: TObject);
    procedure EditChange(Sender: TObject);
  public
    OnChange: TParamChangeEvent;
    OnBeforeWrite, OnAfterWrite: TNotifyEvent;
    LabelWidth: Integer;
    constructor Create(AOwner: TComponent); override;
    procedure Build(const D: TPDescList);
    procedure RefreshValues;
    property Descs: TPDescList read FDescs;
  end;

function BgraToColor(const C: TBGRAPixel): TColor;
function ColorToBgra(C: TColor): TBGRAPixel;

implementation

function BgraToColor(const C: TBGRAPixel): TColor;
begin
  Result := RGBToColor(C.red, C.green, C.blue);
end;

function ColorToBgra(C: TColor): TBGRAPixel;
begin
  C := ColorToRGB(C);
  Result := BGRA(Red(C), Green(C), Blue(C), 255);
end;

{ TParamPanel }

constructor TParamPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;
  HorzScrollBar.Visible := False;
  VertScrollBar.Tracking := True;
  VertScrollBar.Increment := 24;
  LabelWidth := 140;
end;

procedure TParamPanel.ClearControls;
begin
  if FHost <> nil then FreeAndNil(FHost);
  FCtl := nil;
end;

function TParamPanel.RowPanel(AParent: TWinControl; AHeight: Integer): TPanel;
begin
  Result := TPanel.Create(FHost);
  Result.Parent := AParent;
  Result.BevelOuter := bvNone;
  Result.Height := AHeight;
  Result.Top := AParent.ControlCount * 1000;
  Result.Align := alTop;
  Result.BorderSpacing.Around := 1;
end;

function TParamPanel.MakeLabel(AParent: TWinControl; const D: TPDesc): TLabel;
begin
  Result := TLabel.Create(FHost);
  Result.Parent := AParent;
  Result.Left := AParent.ControlCount * 1000;
  Result.Align := alLeft;
  Result.AutoSize := False;
  Result.Width := LabelWidth;
  Result.Layout := tlCenter;
  Result.Caption := D.Caption;
  Result.Hint := D.Hint + LineEnding + '[' + D.Key + ']';
  Result.ShowHint := True;
end;

procedure TParamPanel.Build(const D: TPDescList);
var
  i: Integer;
  grp: string;
  gb: TGroupBox;
  row: TPanel;
  lbl: TLabel;
  sl: TStringList;
begin
  DisableAutoSizing;
  try
    ClearControls;
    FDescs := Copy(D);
    SetLength(FCtl, Length(FDescs));
    FHost := TPanel.Create(Self);
    TPanel(FHost).BevelOuter := bvNone;
    FHost.Parent := Self;
    FHost.Align := alTop;
    FHost.AutoSize := True;
    gb := nil;
    grp := #0;
    FUpdating := True;
    for i := 0 to High(FDescs) do
    begin
      FCtl[i] := Default(TParamCtl);
      if (gb = nil) or (FDescs[i].Group <> grp) then
      begin
        grp := FDescs[i].Group;
        gb := TGroupBox.Create(FHost);
        gb.Parent := FHost;
        gb.Caption := grp;
        gb.Top := FHost.ControlCount * 100000;
        gb.Align := alTop;
        gb.AutoSize := True;
        gb.BorderSpacing.Around := 3;
      end;
      case FDescs[i].Kind of
        pkFloat:
          begin
            row := RowPanel(gb, 24);
            lbl := MakeLabel(row, FDescs[i]);
            FCtl[i].FSpin := TFloatSpinEdit.Create(FHost);
            with FCtl[i].FSpin do
            begin
              Parent := row; Align := alRight; Width := 82;
              DecimalPlaces := Max(0, FDescs[i].Decimals);
              MinValue := FDescs[i].MinV; MaxValue := FDescs[i].MaxV;
              Increment := Power(10, -Max(0, FDescs[i].Decimals));
              Value := PSingle(FDescs[i].P)^;
              Tag := i; OnChange := @FSpinChange; Hint := lbl.Hint; ShowHint := True;
            end;
            FCtl[i].Track := TTrackBar.Create(FHost);
            with FCtl[i].Track do
            begin
              Parent := row; Align := alClient; Min := 0; Max := 1000; TickStyle := tsNone; PageSize := 50;
              Position := Round((PSingle(FDescs[i].P)^ - FDescs[i].MinV) / Math.Max(1e-9, FDescs[i].MaxV - FDescs[i].MinV) * 1000);
              Tag := i; OnChange := @TrackChange; Hint := lbl.Hint; ShowHint := True;
            end;
          end;
        pkInt:
          begin
            row := RowPanel(gb, 24);
            lbl := MakeLabel(row, FDescs[i]);
            FCtl[i].ISpin := TSpinEdit.Create(FHost);
            with FCtl[i].ISpin do
            begin
              Parent := row; Left := row.ControlCount * 1000; Align := alLeft; Width := 100;
              MinValue := Round(FDescs[i].MinV); MaxValue := Round(FDescs[i].MaxV);
              Value := PInteger(FDescs[i].P)^;
              Tag := i; OnChange := @ISpinChange; Hint := lbl.Hint; ShowHint := True;
            end;
          end;
        pkEnum:
          begin
            row := RowPanel(gb, 26);
            lbl := MakeLabel(row, FDescs[i]);
            FCtl[i].Combo := TComboBox.Create(FHost);
            with FCtl[i].Combo do
            begin
              Parent := row; Align := alClient; Style := csDropDownList;
              sl := TStringList.Create;
              try
                sl.Delimiter := '|'; sl.StrictDelimiter := True; sl.DelimitedText := FDescs[i].Items;
                Items.Assign(sl);
              finally
                sl.Free;
              end;
              ItemIndex := PInteger(FDescs[i].P)^;
              Tag := i; OnChange := @ComboChange; Hint := lbl.Hint; ShowHint := True;
            end;
          end;
        pkBool:
          begin
            row := RowPanel(gb, 22);
            FCtl[i].Check := TCheckBox.Create(FHost);
            with FCtl[i].Check do
            begin
              Parent := row; Align := alLeft; BorderSpacing.Left := LabelWidth;
              Caption := FDescs[i].Caption; Checked := PBoolean(FDescs[i].P)^;
              Tag := i; OnChange := @CheckChange; Hint := FDescs[i].Hint; ShowHint := True;
            end;
          end;
        pkColor:
          begin
            row := RowPanel(gb, 26);
            lbl := MakeLabel(row, FDescs[i]);
            FCtl[i].ColorBtn := TColorButton.Create(FHost);
            with FCtl[i].ColorBtn do
            begin
              Parent := row; Left := row.ControlCount * 1000; Align := alLeft; Width := 90;
              ButtonColor := BgraToColor(PBGRAPixel(FDescs[i].P)^);
              Tag := i; OnColorChanged := @ColorChange; Hint := lbl.Hint; ShowHint := True;
            end;
          end;
        pkString:
          begin
            row := RowPanel(gb, 26);
            lbl := MakeLabel(row, FDescs[i]);
            FCtl[i].Edit := TEdit.Create(FHost);
            with FCtl[i].Edit do
            begin
              Parent := row; Align := alClient;
              Text := PString(FDescs[i].P)^;
              Tag := i; OnChange := @EditChange; Hint := lbl.Hint; ShowHint := True;
            end;
          end;
      end;
    end;
  finally
    FUpdating := False;
    EnableAutoSizing;
  end;
end;

procedure TParamPanel.RefreshValues;
var
  i: Integer;
begin
  FUpdating := True;
  try
    for i := 0 to High(FDescs) do
      case FDescs[i].Kind of
        pkFloat:
          begin
            FCtl[i].FSpin.Value := PSingle(FDescs[i].P)^;
            FCtl[i].Track.Position := Round((PSingle(FDescs[i].P)^ - FDescs[i].MinV) /
              Math.Max(1e-9, FDescs[i].MaxV - FDescs[i].MinV) * 1000);
          end;
        pkInt: FCtl[i].ISpin.Value := PInteger(FDescs[i].P)^;
        pkEnum: FCtl[i].Combo.ItemIndex := PInteger(FDescs[i].P)^;
        pkBool: FCtl[i].Check.Checked := PBoolean(FDescs[i].P)^;
        pkColor: FCtl[i].ColorBtn.ButtonColor := BgraToColor(PBGRAPixel(FDescs[i].P)^);
        pkString: if FCtl[i].Edit.Text <> PString(FDescs[i].P)^ then FCtl[i].Edit.Text := PString(FDescs[i].P)^;
      end;
  finally
    FUpdating := False;
  end;
end;

procedure TParamPanel.DoChange(AIndex: Integer);
begin
  if Assigned(OnChange) then OnChange(Self, FDescs[AIndex].Key);
end;

procedure TParamPanel.TrackChange(Sender: TObject);
var
  i: Integer;
  v: Single;
begin
  if FUpdating then Exit;
  i := TTrackBar(Sender).Tag;
  v := FDescs[i].MinV + TTrackBar(Sender).Position / 1000 * (FDescs[i].MaxV - FDescs[i].MinV);
  v := RoundTo(v, -Max(0, FDescs[i].Decimals));
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PSingle(FDescs[i].P)^ := v;
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  FUpdating := True;
  try
    FCtl[i].FSpin.Value := v;
  finally
    FUpdating := False;
  end;
  DoChange(i);
end;

procedure TParamPanel.FSpinChange(Sender: TObject);
var
  i: Integer;
  v: Single;
begin
  if FUpdating then Exit;
  i := TFloatSpinEdit(Sender).Tag;
  v := EnsureRange(TFloatSpinEdit(Sender).Value, FDescs[i].MinV, FDescs[i].MaxV);
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PSingle(FDescs[i].P)^ := v;
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  FUpdating := True;
  try
    FCtl[i].Track.Position := Round((v - FDescs[i].MinV) / Math.Max(1e-9, FDescs[i].MaxV - FDescs[i].MinV) * 1000);
  finally
    FUpdating := False;
  end;
  DoChange(i);
end;

procedure TParamPanel.ISpinChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating then Exit;
  i := TSpinEdit(Sender).Tag;
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PInteger(FDescs[i].P)^ := EnsureRange(TSpinEdit(Sender).Value, Round(FDescs[i].MinV), Round(FDescs[i].MaxV));
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  DoChange(i);
end;

procedure TParamPanel.ComboChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating then Exit;
  i := TComboBox(Sender).Tag;
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PInteger(FDescs[i].P)^ := Max(0, TComboBox(Sender).ItemIndex);
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  DoChange(i);
end;

procedure TParamPanel.CheckChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating then Exit;
  i := TCheckBox(Sender).Tag;
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PBoolean(FDescs[i].P)^ := TCheckBox(Sender).Checked;
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  DoChange(i);
end;

procedure TParamPanel.ColorChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating then Exit;
  i := TColorButton(Sender).Tag;
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PBGRAPixel(FDescs[i].P)^ := ColorToBgra(TColorButton(Sender).ButtonColor);
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  DoChange(i);
end;

procedure TParamPanel.EditChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating then Exit;
  i := TEdit(Sender).Tag;
  if Assigned(OnBeforeWrite) then OnBeforeWrite(Self);
  PString(FDescs[i].P)^ := TEdit(Sender).Text;
  if Assigned(OnAfterWrite) then OnAfterWrite(Self);
  DoChange(i);
end;

end.
