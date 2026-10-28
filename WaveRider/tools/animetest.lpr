program animetest;
{$mode objfpc}{$H+}
uses Interfaces, SysUtils, BGRABitmap, BGRABitmapTypes, uAnime;
var b: TBGRABitmap; i: Integer; p: TChibiPose;
begin
  b := TBGRABitmap.Create(1600, 460, BGRA(40, 40, 52));
  for i := 1 to 4 do
  begin
    p := DefaultChibiPose(i);
    p.HandUp := 1;
    DrawChibi(b, i, (i - 1) * 400 + 200, 20, 420, p, 0.5);
  end;
  b.SaveToFile(ParamStr(1));
  b.Free;
end.
