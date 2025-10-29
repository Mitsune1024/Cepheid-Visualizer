// Mode7.pde
// Ship arms: full morphing implementation, todas las fórmulas, y control por energía.
// Depende de: fftNorm(), getShipEnergy(), shipEnergySmooth (global), t, dt, MAX_FFT_USED

// estado local del modo (mantener entre frames)
float mode7_morphU = 0.0;
float mode7_morphTargetU = 0.0;
final int MODE7_FORMULAS = 7;
float mode7_morphTau = 2.5; // segundos característicos para suavizar morph

void drawMode7_shipArms(PGraphics pg) {
  if (pg == null) return;

  pg.pushStyle();
  pg.pushMatrix();

  pg.colorMode(HSB,360,100,100);
  pg.noFill();
  pg.strokeWeight(1.0);
  try { pg.hint(DISABLE_DEPTH_TEST); } catch (Exception e) { }

  // actualizar energía (getShipEnergy está en main y actualiza shipEnergySmooth)
  float energy = getShipEnergy();

  // calcular target de morph según la energía
  mode7_morphTargetU = constrain(shipEnergySmooth * (MODE7_FORMULAS - 1), 0, MODE7_FORMULAS - 1);
  float morphAlpha = 1.0 - exp(-dt / max(0.0001, mode7_morphTau));
  mode7_morphU = lerp(mode7_morphU, mode7_morphTargetU, morphAlpha);

  // interpolación entre fórmulas
  float u = constrain(mode7_morphU, 0, MODE7_FORMULAS - 1);
  int i0 = int(floor(u));
  int i1 = min(i0 + 1, MODE7_FORMULAS - 1);
  float blend = u - i0;

  int N = 40;
  float dz = 6.0;
  float baseA = min(pg.width, pg.height) * 2.67;

  for (int j = 0; j < N; j++) {
    int bandIndex = j % MAX_FFT_USED;
    float band = fftNorm(bandIndex, 8.0);
    float A = baseA * (0.32 + (band / 0.86) * 0.8);
    float z = (j - N*0.2) * (dz / 0.746);
    float hue = (j * 7) % 360;

    float alphaStroke = (30 + band * 120 * (0.5 + 0.5 * energy));
    alphaStroke = constrain(alphaStroke, 6, 255);
    pg.stroke(hue, 80, 100, alphaStroke);

    pg.beginShape();
    for (float tt = 0; tt < TWO_PI; tt += 0.06) {
      PVector v0 = mode7_shipFormula(i0, baseA, A, tt, j, band, t);
      PVector v1 = mode7_shipFormula(i1, baseA, A, tt, j, band, t);
      float x = lerp(v0.x, v1.x, blend);
      float y = lerp(v0.y, v1.y, blend);
      pg.vertex(x, y, z);
    }
    pg.endShape();
  }

  try { pg.hint(ENABLE_DEPTH_TEST); } catch (Exception e) { }
  pg.popMatrix();
  pg.popStyle();
}

// ---- ship formulas completas ----
PVector mode7_shipFormula(int idx, float baseA, float A, float tt, int j, float band, float tNow) {
  float x = 0;
  float y = 0;
  float phaseJ = tNow * (1.0 + 0.05 * j);

  switch(idx) {
    case 0:
      x = (baseA * 0.23) * sin(12.0 * PI * phaseJ * j) * cos(2.0 * PI * tt * A);
      y = (baseA * 0.1) * cos(2.0 * PI * tt * A) * cos(2.0 * PI * tt * A);
      break;
    case 1:
      x = (baseA * 0.18) * sin(6.0 * PI * phaseJ * j) * cos(2.0 * PI * tt * (A * 0.6));
      y = (baseA * 0.14) * sin(2.0 * PI * tt * (A * 0.9)) * cos(2.0 * PI * tt * (A * 0.6));
      break;
    case 2:
      float spikeAmp = 1.0 + band * 3.0 + shipEnergySmooth * 4.0;
      x = (baseA * 0.28) * sin(18.0 * PI * phaseJ * j) * cos(2.0 * PI * tt * A) * spikeAmp;
      y = (baseA * 0.08) * cos(2.0 * PI * tt * A) * cos(4.0 * PI * tt * A) * spikeAmp;
      break;
    case 3:
      float r3 = baseA * 0.06 * (1.0 + 0.8 * band);
      x = r3 * cos(tt) * (1.0 + 0.5 * sin(4.0 * tt + phaseJ));
      y = r3 * sin(tt) * (1.0 + 0.5 * cos(3.0 * tt - phaseJ));
      break;
    case 4:
      float lobes = 3.0 + floor(band * 5.0);
      float rad4 = baseA * 0.12 * (1.0 + 0.6 * sin(lobes * tt + phaseJ));
      x = rad4 * cos(tt);
      y = rad4 * sin(tt) * (0.6 + 0.4 * cos(2.0 * tt + phaseJ));
      break;
    case 5:
      float rr5 = baseA * 0.02 * (1.0 + tt * 0.2) * (1.0 + 0.6 * band);
      x = rr5 * cos(2.0 * tt + 0.2 * phaseJ) * (1.0 + 0.3 * sin(6.0 * tt));
      y = rr5 * sin(2.0 * tt + 0.2 * phaseJ) * (1.0 + 0.3 * cos(5.0 * tt));
      break;
    case 6:
      float p6 = 1.0 + 0.8 * sin(8.0 * tt + phaseJ) + 0.5 * sin(16.0 * tt * (1.0 + band));
      x = (baseA * 0.15) * cos(tt) * p6;
      y = (baseA * 0.12) * sin(tt) * p6;
      break;
    default:
      x = (baseA * 0.2) * cos(tt);
      y = (baseA * 0.1) * sin(tt);
      break;
  }
  return new PVector(x, y);
}
