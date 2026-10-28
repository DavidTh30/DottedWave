program contact;
{ Contact sheet: contact <out.png> <cols> <thumb width> <file1.png> <file2.png> ...
  Lays the images out in a grid with their file names underneath (docs/img/overview_*.png). }
{$mode objfpc}{$H+}
uses Interfaces, Classes, SysUtils, Graphics, BGRABitmap, BGRABitmapTypes;
var
  sheet, img, th: TBGRABitmap;
  cols, tw, th_h, n, i, x, y: Integer;
const
  PAD = 12; LABEL_H = 26;
begin
  cols := StrToInt(ParamStr(2));
  tw := StrToInt(ParamStr(3));
  n := ParamCount - 3;
  th_h := Round(tw * 1431 / 736);
  sheet := TBGRABitmap.Create(cols * (tw + PAD) + PAD, ((n + cols - 1) div cols) * (th_h + LABEL_H + PAD) + PAD, BGRA(24, 24, 30));
  sheet.FontName := 'Segoe UI';
  sheet.FontHeight := 16;
  sheet.FontQuality := fqFineAntialiasing;
  for i := 0 to n - 1 do
  begin
    img := TBGRABitmap.Create(ParamStr(i + 4));
    th := img.Resample(tw, Round(tw * img.Height / img.Width), rmFineResample) as TBGRABitmap;
    x := PAD + (i mod cols) * (tw + PAD);
    y := PAD + (i div cols) * (th_h + LABEL_H + PAD);
    sheet.PutImage(x, y, th, dmSet);
    sheet.TextOut(x, y + th_h + 3, ChangeFileExt(ExtractFileName(ParamStr(i + 4)), ''), BGRA(220, 220, 230));
    th.Free;
    img.Free;
  end;
  sheet.SaveToFile(ParamStr(1));
  sheet.Free;
end.
