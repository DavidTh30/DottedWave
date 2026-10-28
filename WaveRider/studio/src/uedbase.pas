{ TListEditor - common layout for the list based Studio editors

   +---------------------------------------------------------------+
   | toolbar: Save  Revert  Defaults            status              |
   +-----------+-----------------------+---------------------------+
   | item list | parameter panel       | right area (preview etc.) |
   | + - dup   | (generated)           |                           |
   +-----------+-----------------------+---------------------------+ }
unit uEdBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs, LCLType,
  uParams, uGameData, uParamPanel;

type

  { TListEditor }

  TListEditor = class(TForm)
  private
    procedure ListClick(Sender: TObject);
    procedure BtnAdd(Sender: TObject);
    procedure BtnDup(Sender: TObject);
    procedure BtnDel(Sender: TObject);
    procedure BtnUp(Sender: TObject);
    procedure BtnDown(Sender: TObject);
    procedure BtnSave(Sender: TObject);
    procedure BtnRevert(Sender: TObject);
    procedure BtnDefaults(Sender: TObject);
    procedure PanelChange(Sender: TObject; const AKey: string);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  protected
    FData: TGameData;
    FTop: TPanel;
    FLeft: TPanel;
    FList: TListBox;
    FListBtns: TPanel;
    FParams: TParamPanel;
    FRight: TPanel;
    FStatus: TLabel;
    FSel: Integer;
    FDirty: Boolean;
    FCanAddDelete: Boolean;
    function ItemCount: Integer; virtual; abstract;
    function ItemName(I: Integer): string; virtual; abstract;
    procedure DescribeItem(I: Integer; var B: TPBuilder); virtual; abstract;
    procedure AddItem; virtual;
    procedure DupItem(I: Integer); virtual;
    procedure DelItem(I: Integer); virtual;
    procedure SwapItems(A, B: Integer); virtual;
    procedure SaveData; virtual; abstract;
    procedure RevertData; virtual; abstract;
    procedure DefaultsData; virtual; abstract;
    procedure ItemSelected(I: Integer); virtual;
    procedure ParamChanged(const AKey: string); virtual;
    function TopButton(const ACaption: string; AOnClick: TNotifyEvent): TButton;
    procedure SetStatus(const S: string);
    procedure MarkDirty;
  public
    constructor CreateEditor(AOwner: TComponent; AData: TGameData; const ACaption: string; ACanAddDelete: Boolean = True);
    procedure RefreshList;
    procedure SelectItem(I: Integer);
  end;

implementation

{ TListEditor }

constructor TListEditor.CreateEditor(AOwner: TComponent; AData: TGameData; const ACaption: string;
  ACanAddDelete: Boolean);

  function SmallBtn(const ACaption: string; AOnClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := FListBtns;
    Result.Caption := ACaption;
    Result.Width := 36;
    Result.Left := FListBtns.ControlCount * 100;
    Result.Align := alLeft;
    Result.OnClick := AOnClick;
    Result.BorderSpacing.Right := 2;
  end;

var
  split: TSplitter;
begin
  inherited CreateNew(AOwner);
  FData := AData;
  FCanAddDelete := ACanAddDelete;
  Caption := 'WaveRider Studio - ' + ACaption;
  Width := Min(1500, Screen.WorkAreaWidth - 40);
  Height := Min(960, Screen.WorkAreaHeight - 40);
  Position := poScreenCenter;
  KeyPreview := True;
  OnCloseQuery := @FormCloseQuery;

  FTop := TPanel.Create(Self);
  FTop.Parent := Self;
  FTop.Align := alTop;
  FTop.Height := 34;
  FTop.BevelOuter := bvNone;
  FTop.BorderSpacing.Around := 3;
  TopButton('Save', @BtnSave).Font.Style := [fsBold];
  TopButton('Revert', @BtnRevert);
  TopButton('Defaults', @BtnDefaults);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := FTop;
  FStatus.Align := alClient;
  FStatus.Layout := tlCenter;
  FStatus.Alignment := taRightJustify;
  FStatus.BorderSpacing.Right := 8;
  FStatus.Caption := FData.DataDir;

  FLeft := TPanel.Create(Self);
  FLeft.Parent := Self;
  FLeft.Align := alLeft;
  FLeft.Width := 210;
  FLeft.BevelOuter := bvNone;
  FListBtns := TPanel.Create(Self);
  FListBtns.Parent := FLeft;
  FListBtns.Align := alBottom;
  FListBtns.Height := 28;
  FListBtns.BevelOuter := bvNone;
  if FCanAddDelete then
  begin
    SmallBtn('+', @BtnAdd).Hint := 'Add';
    SmallBtn('Dup', @BtnDup).Hint := 'Duplicate';
    SmallBtn('-', @BtnDel).Hint := 'Delete';
    SmallBtn('Up', @BtnUp);
    SmallBtn('Dn', @BtnDown);
  end;
  FList := TListBox.Create(Self);
  FList.Parent := FLeft;
  FList.Align := alClient;
  FList.OnClick := @ListClick;

  split := TSplitter.Create(Self);
  split.Parent := Self;
  split.Left := 300;
  split.Align := alLeft;

  FParams := TParamPanel.Create(Self);
  FParams.Parent := Self;
  FParams.Align := alLeft;
  FParams.Width := 470;
  FParams.Left := 400;
  FParams.OnChange := @PanelChange;

  split := TSplitter.Create(Self);
  split.Parent := Self;
  split.Left := 900;
  split.Align := alLeft;

  FRight := TPanel.Create(Self);
  FRight.Parent := Self;
  FRight.Align := alClient;
  FRight.BevelOuter := bvNone;
  FSel := -1;
end;

function TListEditor.TopButton(const ACaption: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FTop;
  Result.Caption := ACaption;
  Result.AutoSize := True;
  Result.Left := FTop.ControlCount * 1000;
  Result.Align := alLeft;
  Result.BorderSpacing.Right := 4;
  Result.OnClick := AOnClick;
end;

procedure TListEditor.SetStatus(const S: string);
begin
  FStatus.Caption := S;
end;

procedure TListEditor.MarkDirty;
begin
  FDirty := True;
  if Pos('*', Caption) = 0 then Caption := Caption + ' *';
end;

procedure TListEditor.RefreshList;
var
  i, keep: Integer;
begin
  keep := FList.ItemIndex;
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for i := 0 to ItemCount - 1 do
      FList.Items.Add(ItemName(i));
  finally
    FList.Items.EndUpdate;
  end;
  if (keep >= 0) and (keep < FList.Count) then FList.ItemIndex := keep;
end;

procedure TListEditor.SelectItem(I: Integer);
var
  b: TPBuilder;
begin
  if ItemCount = 0 then
  begin
    FSel := -1;
    b.Clear;
    FParams.Build(b.List);
    Exit;
  end;
  I := EnsureRange(I, 0, ItemCount - 1);
  FSel := I;
  FList.ItemIndex := I;
  b.Clear;
  DescribeItem(I, b);
  FParams.Build(b.List);
  ItemSelected(I);
end;

procedure TListEditor.ItemSelected(I: Integer);
begin
end;

procedure TListEditor.ParamChanged(const AKey: string);
begin
end;

procedure TListEditor.ListClick(Sender: TObject);
begin
  if FList.ItemIndex <> FSel then SelectItem(FList.ItemIndex);
end;

procedure TListEditor.PanelChange(Sender: TObject; const AKey: string);
begin
  MarkDirty;
  if (FSel >= 0) and (FSel < FList.Count) and (FList.Items[FSel] <> ItemName(FSel)) then
    FList.Items[FSel] := ItemName(FSel);
  ParamChanged(AKey);
end;

procedure TListEditor.AddItem;
begin
end;

procedure TListEditor.DupItem(I: Integer);
begin
end;

procedure TListEditor.DelItem(I: Integer);
begin
end;

procedure TListEditor.SwapItems(A, B: Integer);
begin
end;

procedure TListEditor.BtnAdd(Sender: TObject);
begin
  AddItem;
  MarkDirty;
  RefreshList;
  SelectItem(ItemCount - 1);
end;

procedure TListEditor.BtnDup(Sender: TObject);
begin
  if FSel < 0 then Exit;
  DupItem(FSel);
  MarkDirty;
  RefreshList;
  SelectItem(FSel + 1);
end;

procedure TListEditor.BtnDel(Sender: TObject);
begin
  if (FSel < 0) or (ItemCount <= 1) then Exit;
  if MessageDlg('Delete "' + ItemName(FSel) + '"?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DelItem(FSel);
  MarkDirty;
  RefreshList;
  SelectItem(Min(FSel, ItemCount - 1));
end;

procedure TListEditor.BtnUp(Sender: TObject);
begin
  if FSel <= 0 then Exit;
  SwapItems(FSel, FSel - 1);
  MarkDirty;
  RefreshList;
  SelectItem(FSel - 1);
end;

procedure TListEditor.BtnDown(Sender: TObject);
begin
  if (FSel < 0) or (FSel >= ItemCount - 1) then Exit;
  SwapItems(FSel, FSel + 1);
  MarkDirty;
  RefreshList;
  SelectItem(FSel + 1);
end;

procedure TListEditor.BtnSave(Sender: TObject);
begin
  try
    SaveData;
    FDirty := False;
    Caption := StringReplace(Caption, ' *', '', []);
    SetStatus('Saved  ' + FormatDateTime('hh:nn:ss', Now) + '  ->  ' + FData.DataDir);
  except
    on E: Exception do MessageDlg('Save failed: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TListEditor.BtnRevert(Sender: TObject);
begin
  if MessageDlg('Reload from disk and lose unsaved changes?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  RevertData;
  FDirty := False;
  Caption := StringReplace(Caption, ' *', '', []);
  RefreshList;
  SelectItem(Max(0, FSel));
  SetStatus('Reverted from disk');
end;

procedure TListEditor.BtnDefaults(Sender: TObject);
begin
  if MessageDlg('Replace everything in this editor with the built-in defaults?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DefaultsData;
  MarkDirty;
  RefreshList;
  SelectItem(0);
  SetStatus('Defaults loaded (not saved yet)');
end;

procedure TListEditor.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not FDirty then Exit;
  case MessageDlg('Save changes before closing?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: BtnSave(nil);
    mrCancel: CanClose := False;
  end;
end;

end.
