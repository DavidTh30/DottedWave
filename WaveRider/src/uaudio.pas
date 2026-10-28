{ WaveRider audio engine: waveOut streaming (no external DLL), mixer, SFX bank.

  Audio thread  ->  Mix(frames)
                      music  (TSongPlayer, real-time synth)
                    + sfx    (pre-rendered sample voices, pitch / pan / volume)
                    -> master soft-clip limiter -> int16 stereo -> waveOut

  The game / editors talk to it with cheap calls (PlaySfx, Music.Intensity := ...).
  Structural edits of the song or SFX bank must be wrapped in Lock / Unlock. }
unit uAudio;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, SyncObjs, uSynth, uMusic;

const
  MAX_SFX_VOICES = 24;

type
  TSfxVoice = record
    Buf: Integer;          { index in bank, -1 = free }
    Pos: Double;
    Rate: Single;
    Vol, PanL, PanR: Single;
  end;

  TAudioEngine = class;

  { TAudioThread }

  TAudioThread = class(TThread)
  private
    FOwner: TAudioEngine;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TAudioEngine);
  end;

  { TAudioEngine }

  TAudioEngine = class
  private
    FLock: SyncObjs.TCriticalSection;
    FThread: TAudioThread;
    FDeviceOk: Boolean;
    FBank: TSfxDefs;
    FBufs: array of TSampleBuf;
    FVoices: array[0..MAX_SFX_VOICES - 1] of TSfxVoice;
    FMix: array of Single;
    FPeak: Single;
    FSong: TSong;
    procedure MixInto(Dst: PSmallInt; Frames: Integer);
  public
    Music: TSongPlayer;
    MasterVolume, MusicVolume, SfxVolume: Single;
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;          { opens the device; False = silent mode }
    procedure Stop;
    procedure Lock;
    procedure Unlock;
    { SFX }
    procedure SetBank(const ABank: TSfxDefs);
    procedure RebuildSfx(AIndex: Integer);
    { editor: replace / append one definition and re-render only that sound }
    procedure UpdateSfx(AIndex: Integer; const ADef: TSfxDef);
    procedure PlaySfx(const AName: string; AVol: Single = 1; APan: Single = 0; APitch: Single = 1);
    procedure PlaySfxIndex(AIndex: Integer; AVol: Single = 1; APan: Single = 0; APitch: Single = 1);
    procedure StopAllSfx;
    function SfxLength(AIndex: Integer): Integer;
    function SfxSamples(AIndex: Integer): TSampleBuf;
    { music }
    procedure SetSong(const ASong: TSong);
    function SongPtr: PSong;
    { offline render (export WAV): stereo interleaved }
    function RenderOffline(Frames: Integer): TSampleBuf;
    property DeviceOk: Boolean read FDeviceOk;
    property Peak: Single read FPeak;
    property Bank: TSfxDefs read FBank;
  end;

var
  Audio: TAudioEngine = nil;

implementation

{$IFDEF WINDOWS}
uses
  Windows, MMSystem;
{$ENDIF}

const
  BUF_FRAMES = 768;
  NUM_BUFS = 4;

{ TAudioThread }

constructor TAudioThread.Create(AOwner: TAudioEngine);
begin
  FOwner := AOwner;
  inherited Create(False);
end;

procedure TAudioThread.Execute;
{$IFDEF WINDOWS}
var
  wfx: TWAVEFORMATEX;
  hwo: HWAVEOUT;
  ev: THandle;
  hdr: array[0..NUM_BUFS - 1] of TWAVEHDR;
  data: array[0..NUM_BUFS - 1] of array of SmallInt;
  i: Integer;
begin
  ev := CreateEvent(nil, False, False, nil);
  wfx := Default(TWAVEFORMATEX);
  wfx.wFormatTag := WAVE_FORMAT_PCM;
  wfx.nChannels := 2;
  wfx.nSamplesPerSec := SAMPLE_RATE;
  wfx.wBitsPerSample := 16;
  wfx.nBlockAlign := 4;
  wfx.nAvgBytesPerSec := SAMPLE_RATE * 4;
  if waveOutOpen(@hwo, WAVE_MAPPER, @wfx, DWORD_PTR(ev), 0, CALLBACK_EVENT) <> MMSYSERR_NOERROR then
  begin
    FOwner.FDeviceOk := False;
    CloseHandle(ev);
    Exit;
  end;
  FOwner.FDeviceOk := True;
  for i := 0 to NUM_BUFS - 1 do
  begin
    SetLength(data[i], BUF_FRAMES * 2);
    hdr[i] := Default(TWAVEHDR);
    hdr[i].lpData := PChar(@data[i][0]);
    hdr[i].dwBufferLength := BUF_FRAMES * 4;
    waveOutPrepareHeader(hwo, @hdr[i], SizeOf(TWAVEHDR));
    FOwner.MixInto(@data[i][0], BUF_FRAMES);
    waveOutWrite(hwo, @hdr[i], SizeOf(TWAVEHDR));
  end;
  while not Terminated do
  begin
    WaitForSingleObject(ev, 50);
    for i := 0 to NUM_BUFS - 1 do
      if (hdr[i].dwFlags and WHDR_DONE) <> 0 then
      begin
        FOwner.MixInto(@data[i][0], BUF_FRAMES);
        hdr[i].dwFlags := hdr[i].dwFlags and not WHDR_DONE;
        waveOutWrite(hwo, @hdr[i], SizeOf(TWAVEHDR));
      end;
  end;
  waveOutReset(hwo);
  for i := 0 to NUM_BUFS - 1 do
    waveOutUnprepareHeader(hwo, @hdr[i], SizeOf(TWAVEHDR));
  waveOutClose(hwo);
  CloseHandle(ev);
end;
{$ELSE}
begin
  FOwner.FDeviceOk := False;
end;
{$ENDIF}

{ TAudioEngine }

constructor TAudioEngine.Create;
var
  i: Integer;
begin
  inherited Create;
  FLock := SyncObjs.TCriticalSection.Create;
  Music := TSongPlayer.Create;
  MasterVolume := 0.9;
  MusicVolume := 0.8;
  SfxVolume := 0.9;
  for i := 0 to MAX_SFX_VOICES - 1 do FVoices[i].Buf := -1;
  FSong := DefaultSong;
  Music.Song := @FSong;
end;

destructor TAudioEngine.Destroy;
begin
  Stop;
  Music.Free;
  FLock.Free;
  inherited Destroy;
end;

function TAudioEngine.Start: Boolean;
var
  t0: QWord;
begin
  if FThread = nil then
  begin
    FThread := TAudioThread.Create(Self);
    { wait (briefly) for the device open result }
    t0 := GetTickCount64;
    while (not FDeviceOk) and (not FThread.Finished) and (GetTickCount64 - t0 < 500) do
      Sleep(5);
  end;
  Result := FDeviceOk;
end;

procedure TAudioEngine.Stop;
begin
  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

procedure TAudioEngine.Lock;
begin
  FLock.Enter;
end;

procedure TAudioEngine.Unlock;
begin
  FLock.Leave;
end;

procedure TAudioEngine.SetBank(const ABank: TSfxDefs);
var
  i: Integer;
  bufs: array of TSampleBuf;
begin
  SetLength(bufs, Length(ABank));
  for i := 0 to High(ABank) do
    bufs[i] := RenderSfx(ABank[i]);
  Lock;
  try
    StopAllSfx;
    FBank := Copy(ABank);
    FBufs := bufs;
  finally
    Unlock;
  end;
end;

procedure TAudioEngine.RebuildSfx(AIndex: Integer);
var
  b: TSampleBuf;
  i: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FBank)) then Exit;
  b := RenderSfx(FBank[AIndex]);
  Lock;
  try
    for i := 0 to MAX_SFX_VOICES - 1 do
      if FVoices[i].Buf = AIndex then FVoices[i].Buf := -1;
    FBufs[AIndex] := b;
  finally
    Unlock;
  end;
end;

procedure TAudioEngine.UpdateSfx(AIndex: Integer; const ADef: TSfxDef);
var
  b: TSampleBuf;
  i: Integer;
begin
  b := RenderSfx(ADef);
  Lock;
  try
    if AIndex > High(FBank) then
    begin
      AIndex := Length(FBank);
      SetLength(FBank, AIndex + 1);
      SetLength(FBufs, AIndex + 1);
    end;
    for i := 0 to MAX_SFX_VOICES - 1 do
      if FVoices[i].Buf = AIndex then FVoices[i].Buf := -1;
    FBank[AIndex] := ADef;
    FBufs[AIndex] := b;
  finally
    Unlock;
  end;
end;

procedure TAudioEngine.PlaySfxIndex(AIndex: Integer; AVol, APan, APitch: Single);
var
  i, best: Integer;
  bestPos: Double;
begin
  if (AIndex < 0) or (AIndex > High(FBufs)) then Exit;
  Lock;
  try
    best := -1;
    bestPos := -1;
    for i := 0 to MAX_SFX_VOICES - 1 do
    begin
      if FVoices[i].Buf < 0 then begin best := i; Break; end;
      if FVoices[i].Pos > bestPos then begin bestPos := FVoices[i].Pos; best := i; end;
    end;
    APan := EnsureRange(APan, -1, 1);
    with FVoices[best] do
    begin
      Buf := AIndex;
      Pos := 0;
      Rate := EnsureRange(APitch, 0.25, 4);
      Vol := AVol;
      PanL := Sqrt(0.5 * (1 - APan));
      PanR := Sqrt(0.5 * (1 + APan));
    end;
  finally
    Unlock;
  end;
end;

procedure TAudioEngine.PlaySfx(const AName: string; AVol, APan, APitch: Single);
begin
  PlaySfxIndex(FindSfx(FBank, AName), AVol, APan, APitch);
end;

procedure TAudioEngine.StopAllSfx;
var
  i: Integer;
begin
  for i := 0 to MAX_SFX_VOICES - 1 do FVoices[i].Buf := -1;
end;

function TAudioEngine.SfxLength(AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex > High(FBufs)) then Exit(0);
  Result := Length(FBufs[AIndex]);
end;

function TAudioEngine.SfxSamples(AIndex: Integer): TSampleBuf;
begin
  if (AIndex < 0) or (AIndex > High(FBufs)) then Exit(nil);
  Result := FBufs[AIndex];
end;

procedure TAudioEngine.SetSong(const ASong: TSong);
begin
  Lock;
  try
    FSong := ASong;
    Music.Song := @FSong;
    Music.Reset;
  finally
    Unlock;
  end;
end;

function TAudioEngine.SongPtr: PSong;
begin
  Result := @FSong;
end;

procedure TAudioEngine.MixInto(Dst: PSmallInt; Frames: Integer);
var
  i, v, idx, n: Integer;
  s, l, r, mv, sv, pk: Single;
  buf: TSampleBuf;
begin
  if Length(FMix) < Frames * 2 then SetLength(FMix, Frames * 2);
  FillChar(FMix[0], Frames * 2 * SizeOf(Single), 0);
  FLock.Enter;
  try
    { music }
    Music.Volume := MusicVolume;
    Music.Render(@FMix[0], Frames);
    { sfx }
    sv := SfxVolume;
    for v := 0 to MAX_SFX_VOICES - 1 do
    begin
      if FVoices[v].Buf < 0 then Continue;
      buf := FBufs[FVoices[v].Buf];
      n := Length(buf);
      for i := 0 to Frames - 1 do
      begin
        idx := Trunc(FVoices[v].Pos);
        if idx >= n - 1 then
        begin
          FVoices[v].Buf := -1;
          Break;
        end;
        s := buf[idx] + (buf[idx + 1] - buf[idx]) * (FVoices[v].Pos - idx);
        s := s * FVoices[v].Vol * sv;
        FMix[i * 2] := FMix[i * 2] + s * FVoices[v].PanL;
        FMix[i * 2 + 1] := FMix[i * 2 + 1] + s * FVoices[v].PanR;
        FVoices[v].Pos := FVoices[v].Pos + FVoices[v].Rate;
      end;
    end;
  finally
    FLock.Leave;
  end;
  { master: soft clip limiter }
  mv := MasterVolume;
  pk := 0;
  for i := 0 to Frames * 2 - 1 do
  begin
    l := FMix[i] * mv;
    if Abs(l) > pk then pk := Abs(l);
    r := Tanh(l * 1.1) * 0.95;
    if Dst <> nil then
    begin
      Dst^ := Round(r * 32000);
      Inc(Dst);
    end
    else
      FMix[i] := r;
  end;
  FPeak := pk;
end;

function TAudioEngine.RenderOffline(Frames: Integer): TSampleBuf;
var
  done, chunk: Integer;
begin
  SetLength(Result, Frames * 2);
  done := 0;
  while done < Frames do
  begin
    chunk := Min(1024, Frames - done);
    MixInto(nil, chunk);
    Move(FMix[0], Result[done * 2], chunk * 2 * SizeOf(Single));
    Inc(done, chunk);
  end;
end;

end.
