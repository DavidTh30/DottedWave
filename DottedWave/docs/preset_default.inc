{ Dotted Wave Mesh preset - generated 2026-10-20 20:58 }
{ usage: uses uWaveTypes; ... ApplyWavePreset(Config); }
procedure ApplyWavePreset(var C: TWaveConfig);
begin
  C := DefaultConfig;
  C.Values[wpLines] := 120.00; { Lines }
  C.Values[wpDotSpacing] := 3.4000; { Dot spacing }
  C.Values[wpDotSize] := 1.9000; { Dot size }
  C.Values[wpAmplitude] := 115.000; { Amplitude }
  C.Values[wpNoiseScale] := 0.001700; { Noise scale }
  C.Values[wpOctaves] := 3.00; { Octaves }
  C.Values[wpLacunarity] := 2.0000; { Lacunarity }
  C.Values[wpGain] := 0.4500; { Gain }
  C.Values[wpStretchX] := 0.5500; { Stretch X }
  C.Values[wpWarp] := 18.000; { Warp X }
  C.Values[wpTilt] := 0.1500; { Perspective tilt }
  C.Values[wpSpeed] := 0.12000; { Speed }
  C.Values[wpDriftX] := 0.6000; { Drift X }
  C.Values[wpDriftY] := 0.2500; { Drift Y }
  C.Values[wpLightAzimuth] := 225.00; { Light azimuth }
  C.Values[wpLightElevation] := 32.00; { Light elevation }
  C.Values[wpRelief] := 2.6000; { Relief }
  C.Values[wpAmbient] := 0.07000; { Ambient }
  C.Values[wpDiffuse] := 1.0000; { Diffuse }
  C.Values[wpSpecular] := 0.6000; { Specular }
  C.Values[wpSpecPower] := 20.00; { Spec power }
  C.Values[wpExposure] := 1.4500; { Exposure }
  C.Values[wpContrast] := 1.5000; { Contrast (gamma) }
  C.Values[wpVignette] := 0.2500; { Vignette }
  C.Values[wpIriAmount] := 0.0000; { Iridescent mix }
  C.Values[wpIriPalette] := 1.00; { Iri palette }
  C.Values[wpIriFrequency] := 1.2000; { Iri angle bands }
  C.Values[wpIriHeight] := 0.4000; { Iri by height }
  C.Values[wpIriSpread] := 0.5000; { Iri by position }
  C.Values[wpIriSpeed] := 1.0000; { Iri hue speed }
  C.Values[wpIriOffset] := 0.00000; { Iri hue offset }
  C.Values[wpIriSaturation] := 1.2000; { Iri saturation }
  C.Values[wpIriSpecWhite] := 0.3500; { Iri spec white }
  C.Values[wpRippleStrength] := 0.9000; { Ripple strength }
  C.Values[wpRippleRadius] := 160.00; { Ripple radius }
  C.Values[wpRenderScale] := 1.0000; { Render scale }
  C.Values[wpSeed] := 7.00; { Seed }
  C.BgColor := BGRA(0, 0, 0);
  C.DotColor := BGRA(242, 242, 242);
  C.VSync := True;
end;
