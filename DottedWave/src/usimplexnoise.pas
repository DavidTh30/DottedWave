{ 3D Simplex noise (Stefan Gustavson, public domain) with seedable permutation }
unit uSimplexNoise;

{$mode objfpc}{$H+}

interface

procedure NoiseSeed(ASeed: LongWord);
{ Returns value in approx. range [-1, 1] }
function Simplex3(xin, yin, zin: Single): Single;

implementation

const
  Grad3: array[0..11, 0..2] of ShortInt = (
    (1, 1, 0), (-1, 1, 0), (1, -1, 0), (-1, -1, 0),
    (1, 0, 1), (-1, 0, 1), (1, 0, -1), (-1, 0, -1),
    (0, 1, 1), (0, -1, 1), (0, 1, -1), (0, -1, -1));
  F3 = 1.0 / 3.0;
  G3 = 1.0 / 6.0;

var
  Perm: array[0..511] of Byte;
  PermMod12: array[0..511] of Byte;

procedure NoiseSeed(ASeed: LongWord);
var
  i, j: Integer;
  t: Byte;
  p: array[0..255] of Byte;
  s: LongWord;
begin
  for i := 0 to 255 do
    p[i] := i;
  s := ASeed xor $9E3779B9;
  if s = 0 then s := 1;
  for i := 255 downto 1 do
  begin
    { xorshift32 }
    s := s xor (s shl 13);
    s := s xor (s shr 17);
    s := s xor (s shl 5);
    j := s mod LongWord(i + 1);
    t := p[i]; p[i] := p[j]; p[j] := t;
  end;
  for i := 0 to 511 do
  begin
    Perm[i] := p[i and 255];
    PermMod12[i] := Perm[i] mod 12;
  end;
end;

function FastFloor(x: Single): Integer; inline;
begin
  Result := Trunc(x);
  if x < Result then Dec(Result);
end;

function Simplex3(xin, yin, zin: Single): Single;
var
  n0, n1, n2, n3, s, t: Single;
  x0, y0, z0, x1, y1, z1, x2, y2, z2, x3, y3, z3: Single;
  t0, t1, t2, t3: Single;
  i, j, k, i1, j1, k1, i2, j2, k2, ii, jj, kk: Integer;
  gi0, gi1, gi2, gi3: Integer;
begin
  s := (xin + yin + zin) * F3;
  i := FastFloor(xin + s);
  j := FastFloor(yin + s);
  k := FastFloor(zin + s);
  t := (i + j + k) * G3;
  x0 := xin - (i - t);
  y0 := yin - (j - t);
  z0 := zin - (k - t);

  if x0 >= y0 then
  begin
    if y0 >= z0 then begin i1 := 1; j1 := 0; k1 := 0; i2 := 1; j2 := 1; k2 := 0; end
    else if x0 >= z0 then begin i1 := 1; j1 := 0; k1 := 0; i2 := 1; j2 := 0; k2 := 1; end
    else begin i1 := 0; j1 := 0; k1 := 1; i2 := 1; j2 := 0; k2 := 1; end;
  end
  else
  begin
    if y0 < z0 then begin i1 := 0; j1 := 0; k1 := 1; i2 := 0; j2 := 1; k2 := 1; end
    else if x0 < z0 then begin i1 := 0; j1 := 1; k1 := 0; i2 := 0; j2 := 1; k2 := 1; end
    else begin i1 := 0; j1 := 1; k1 := 0; i2 := 1; j2 := 1; k2 := 0; end;
  end;

  x1 := x0 - i1 + G3;       y1 := y0 - j1 + G3;       z1 := z0 - k1 + G3;
  x2 := x0 - i2 + 2.0 * G3; y2 := y0 - j2 + 2.0 * G3; z2 := z0 - k2 + 2.0 * G3;
  x3 := x0 - 1.0 + 3.0 * G3; y3 := y0 - 1.0 + 3.0 * G3; z3 := z0 - 1.0 + 3.0 * G3;

  ii := i and 255;
  jj := j and 255;
  kk := k and 255;
  gi0 := PermMod12[ii + Perm[jj + Perm[kk]]];
  gi1 := PermMod12[ii + i1 + Perm[jj + j1 + Perm[kk + k1]]];
  gi2 := PermMod12[ii + i2 + Perm[jj + j2 + Perm[kk + k2]]];
  gi3 := PermMod12[ii + 1 + Perm[jj + 1 + Perm[kk + 1]]];

  t0 := 0.6 - x0 * x0 - y0 * y0 - z0 * z0;
  if t0 < 0 then n0 := 0
  else begin t0 := t0 * t0; n0 := t0 * t0 * (Grad3[gi0, 0] * x0 + Grad3[gi0, 1] * y0 + Grad3[gi0, 2] * z0); end;

  t1 := 0.6 - x1 * x1 - y1 * y1 - z1 * z1;
  if t1 < 0 then n1 := 0
  else begin t1 := t1 * t1; n1 := t1 * t1 * (Grad3[gi1, 0] * x1 + Grad3[gi1, 1] * y1 + Grad3[gi1, 2] * z1); end;

  t2 := 0.6 - x2 * x2 - y2 * y2 - z2 * z2;
  if t2 < 0 then n2 := 0
  else begin t2 := t2 * t2; n2 := t2 * t2 * (Grad3[gi2, 0] * x2 + Grad3[gi2, 1] * y2 + Grad3[gi2, 2] * z2); end;

  t3 := 0.6 - x3 * x3 - y3 * y3 - z3 * z3;
  if t3 < 0 then n3 := 0
  else begin t3 := t3 * t3; n3 := t3 * t3 * (Grad3[gi3, 0] * x3 + Grad3[gi3, 1] * y3 + Grad3[gi3, 2] * z3); end;

  Result := 32.0 * (n0 + n1 + n2 + n3);
end;

initialization
  NoiseSeed(0);

end.
