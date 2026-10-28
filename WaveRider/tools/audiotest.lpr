program audiotest;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Classes, SysUtils, Math, uSynth, uMusic, uAudio, uParams;
var
  bank: TSfxDefs;
  buf: TSampleBuf;
  i: Integer;
  t0: QWord;
  song: TSong;
  pk: Single;
begin
  bank := DefaultSfxBank;
  WriteLn('sfx count: ', Length(bank));
  t0 := GetTickCount64;
  for i := 0 to High(bank) do
  begin
    buf := RenderSfx(bank[i]);
    pk := 0; for pk in buf do ; 
    WriteLn(Format('  %-12s %6d samples (%.2fs)', [bank[i].Name, Length(buf), Length(buf) / SAMPLE_RATE]));
    if ParamStr(1) = 'wav' then WriteWav('sfx_' + bank[i].Name + '.wav', buf, 1);
  end;
  WriteLn('sfx render ms: ', GetTickCount64 - t0);
  Audio := TAudioEngine.Create;
  song := DefaultSong;
  WriteLn(Format('song "%s" length %.1f s, %d sections, %d patterns', [song.Name, SongLengthSeconds(song), Length(song.Sections), Length(song.Patterns)]));
  Audio.SetSong(song);
  Audio.SetBank(bank);
  Audio.Music.Playing := True;
  Audio.Music.SeekSection(StrToIntDef(ParamStr(2), 2));
  Audio.Music.Intensity := 0.8;
  t0 := GetTickCount64;
  buf := Audio.RenderOffline(SAMPLE_RATE * 20);
  WriteLn(Format('render 20 s of music: %d ms (realtime x%.1f)', [GetTickCount64 - t0, 20000 / Max(1, GetTickCount64 - t0)]));
  pk := 0; for i := 0 to High(buf) do pk := Max(pk, Abs(buf[i]));
  WriteLn('peak: ', pk:0:3);
  if ParamStr(1) = 'wav' then WriteWav('music_drop.wav', buf, 2);
  Audio.Free;
end.
