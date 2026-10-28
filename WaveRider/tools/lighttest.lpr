program lighttest;
{$mode objfpc}{$H+}
uses
  Interfaces, Classes, SysUtils, Math, BGRABitmap, BGRABitmapTypes, uLightFx;
var
  bmp: TBGRABitmap;
  layer: TLightLayer;
  scene: TLightScene;
  k, i: Integer;
  d: TLightDef;
  t0: QWord;
begin
  bmp := TBGRABitmap.Create(600, 1100, BGRA(14, 14, 16));
  layer := TLightLayer.Create;
  scene := TLightScene.Create;
  layer.Start(bmp.Width, bmp.Height);
  t0 := GetTickCount64;
  for k := 0 to 3 do
  begin
    d := DefaultLightDef(k);
    BuildKindScene(scene, k, d, 330, 150 + k * 270, 100, 1.3);
    scene.DrawGlass(bmp, 1, 1, 1.3);
    layer.SetClip(0, 20 + k * 270, 600, 20 + k * 270 + 255);
    scene.DrawLight(layer, 1, 1);
    WriteLn(Format('%-20s segs %d', [d.Name, scene.SegCount]));
  end;
  layer.Composite(bmp);
  WriteLn('ms ', GetTickCount64 - t0);
  bmp.FontHeight := 18;
  for k := 0 to 3 do
    bmp.TextOut(300, 240 + k * 270, DefaultLightDef(k).Name, BGRA(220, 220, 230), taCenter);
  bmp.SaveToFile(ParamStr(1));
  scene.Free; layer.Free; bmp.Free;
end.
