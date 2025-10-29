
// Mode2.pde
// Helix of boxes/points — versión en overlay3D (3D, limpio cada frame)

void drawMode2_helix(PGraphics pg) {
  if (overlay3D == null) {
    // Fallback: dibuja directo en pg (no ideal)
    drawMode2_direct(pg);
    return;
  }

  overlay3D.beginDraw();
  overlay3D.clear();
  overlay3D.pushStyle();
  overlay3D.colorMode(HSB, 360, 100, 100);
  overlay3D.noStroke();

  float base = min(overlay3D.width, overlay3D.height);
  float R0 = base * 0.18f;
  float k = base * 0.0018f;
  float omega = 6.0f;
  float step = (base > 1200) ? 2.5f : (base > 800) ? 2.0f : 3.0f;
  int maxT = (base > 1200) ? 600 : (base > 800) ? 420 : 300;

  int idx = 0;

  overlay3D.pushMatrix();
  overlay3D.translate(overlay3D.width * 0.5f, overlay3D.height * 0.5f, 0);
  for (float tt = 0; tt < maxT; tt += step) {
    float r = R0 + k * tt;
    float phaseMod = fftNorm(idx % MAX_FFT_USED, 10.0f);
    float phi = omega * tt * 0.02f + phaseMod * TWO_PI + t * 0.12f;

    float x = r * cos(phi);
    float y = r * sin(phi);
    float z = (tt - maxT * 0.5f) * (base * 0.0009f);

    float v = fftNorm(idx % MAX_FFT_USED, 6.0f);
    float hue = (map(idx, 0, maxT / step, 0, 360) + frameCount * 0.3f + v * 120) % 360;
    float brightness = 80 + v * 20;
    float alpha = 160 + v * 95;

    float psBase = map(base, 300, 1600, 2.5f, 18.0f);
    float pointSize = psBase * (0.5f + v * 2.5f) + rms * (psBase * 1.5f);

    overlay3D.pushMatrix();
    overlay3D.translate(x, y, z);
    overlay3D.fill(hue, 80, brightness, alpha);
    overlay3D.rectMode(CENTER);
    overlay3D.rect(0, 0, pointSize, pointSize);
    overlay3D.popMatrix();

    idx++;
    if (idx >= MAX_FFT_USED) idx = 0;
  }

  // cubo central (3D) dibujado en overlay3D para que rote y no acumule
  drawCenterCube_overlay(overlay3D, base);

  overlay3D.popMatrix();
  overlay3D.popStyle();
  overlay3D.endDraw();

  pg.pushStyle();
  pg.blendMode(ADD);
  pg.image(overlay3D, -pg.width * 0.5f, -pg.height * 0.5f);
  pg.blendMode(BLEND);
  pg.popStyle();
}

void drawMode2_direct(PGraphics pg) {
  // Fallback simple si no hay overlay3D: dibuja puntos planos en pg
  pg.pushStyle();
  pg.colorMode(HSB,360,100,100);
  pg.noStroke();
  float base = min(pg.width, pg.height);
  float R0 = base * 0.18f;
  float k = base * 0.0018f;
  float omega = 6.0f;
  float step = (base > 1200) ? 2.5f : (base > 800) ? 2.0f : 3.0f;
  int maxT = (base > 1200) ? 600 : (base > 800) ? 420 : 300;
  int idx = 0;
  pg.pushMatrix();
  for (float tt = 0; tt < maxT; tt += step) {
    float r = R0 + k * tt;
    float phaseMod = fftNorm(idx % MAX_FFT_USED, 10.0f);
    float phi = omega * tt * 0.02f + phaseMod * TWO_PI + t * 0.12f;
    float x = r * cos(phi);
    float y = r * sin(phi);
    float v = fftNorm(idx % MAX_FFT_USED, 6.0f);
    float hue = (map(idx, 0, maxT / step, 0, 360) + frameCount * 0.3f + v * 120) % 360;
    float brightness = 80 + v * 20;
    float alpha = 160 + v * 95;
    float psBase = map(base, 300, 1600, 2.5f, 18.0f);
    float pointSize = psBase * (0.5f + v * 2.5f) + rms * (psBase * 1.5f);
    pg.fill(hue, 80, brightness, alpha);
    pg.rectMode(CENTER);
    pg.rect(x, y, pointSize, pointSize);
    idx++;
    if (idx >= MAX_FFT_USED) idx = 0;
  }
  pg.popMatrix();
  pg.popStyle();
}

// cube overlay used by Mode2
void drawCenterCube_overlay(PGraphics pg, float base) {
  pg.pushStyle();
  pg.pushMatrix();
  pg.translate(0, 0, 0);

  float cubeSize = base * 0.11f + rms * base * 0.06f;

  // rotación orgánica (versión abreviada)
    float rx =
    sin(t * 0.8
        + cos(t * 0.3 + sin(t * 0.07) * 3.0)
        + rms * 5.0
        + fftNorm(2, 6.0) * 2.0 * PI
        + sin(t * 1.3 + fftNorm(5, 8.0) * 4.0)
        + cos(t * 0.5 + sin(t * 0.1 + fftNorm(8, 6.0)) * 2.0)
        + fftNorm(10, 8.0) * sin(t * 0.9 + cos(t * 0.4) * 2.0)
        + sin(t * 0.23 + cos(t * 0.45 + rms * 3.0)) * 4.0
        + sin(fftNorm(15, 10.0) * PI * t * 0.4)
    ) * (0.6 + 0.2 * fftNorm(12, 6.0))
    + cos(t * 0.6 + sin(t * 0.2 + fftNorm(6, 6.0)) * 1.8)
    + 0.3 * sin(t * 0.9 + fftNorm(20, 8.0) * 3.0)
    - 0.15 * cos(t * 0.4 + fftNorm(24, 8.0) * 5.0)
    + 0.1 * sin(t * 2.0 + fftNorm(30, 10.0) * 8.0)
    + 0.05 * cos(t * 4.5 + fftNorm(32, 12.0) * 10.0);

  float ry =
    cos(t * 0.6
        + sin(t * 0.25 + fftNorm(4, 6.0)) * 1.8
        + rms * 3.0
        + fftNorm(6, 8.0) * 3.0
        + cos(t * 0.3 + sin(t * 0.5) * 2.0)
        + sin(t * 1.1 + fftNorm(7, 6.0) * 2.0)
        - cos(t * 0.8 + fftNorm(11, 10.0) * 4.0)
        + sin(t * 0.33 + cos(t * 0.23 + rms * 2.5)) * 4.0
        + cos(fftNorm(18, 12.0) * PI * t * 0.6)
    ) * (0.6 + 0.3 * fftNorm(14, 8.0))
    + sin(t * 0.7 + cos(t * 0.45 + fftNorm(9, 8.0)) * 1.5)
    + 0.4 * cos(t * 1.1 + fftNorm(22, 8.0) * 4.0)
    - 0.2 * sin(t * 0.5 + fftNorm(28, 10.0) * 7.0)
    + 0.1 * cos(t * 3.0 + fftNorm(33, 12.0) * 11.0)
    + 0.05 * sin(t * 5.0 + fftNorm(36, 14.0) * 15.0);

  pg.rotateX(rx);
  pg.rotateY(ry);

  float band0 = fftNorm(0, 8.0f);
  float hue = (band0 * 180 + frameCount * 0.2f) % 360;
  float strokeAlpha = 160 + band0 * 95;
  pg.noFill();
  pg.stroke(hue, 80, 100, strokeAlpha);
  pg.strokeWeight(2.0f + band0 * 3.0f);

  float s = cubeSize * 0.5f;
  PVector[] v = new PVector[8];
  v[0] = new PVector(-s, -s, -s);
  v[1] = new PVector(s, -s, -s);
  v[2] = new PVector(s, s, -s);
  v[3] = new PVector(-s, s, -s);
  v[4] = new PVector(-s, -s, s);
  v[5] = new PVector(s, -s, s);
  v[6] = new PVector(s, s, s);
  v[7] = new PVector(-s, s, s);

  pg.beginShape(LINES);
    // front
    pg.vertex(v[0].x, v[0].y, v[0].z); pg.vertex(v[1].x, v[1].y, v[1].z);
    pg.vertex(v[1].x, v[1].y, v[1].z); pg.vertex(v[2].x, v[2].y, v[2].z);
    pg.vertex(v[2].x, v[2].y, v[2].z); pg.vertex(v[3].x, v[3].y, v[3].z);
    pg.vertex(v[3].x, v[3].y, v[3].z); pg.vertex(v[0].x, v[0].y, v[0].z);
    // back
    pg.vertex(v[4].x, v[4].y, v[4].z); pg.vertex(v[5].x, v[5].y, v[5].z);
    pg.vertex(v[5].x, v[5].y, v[5].z); pg.vertex(v[6].x, v[6].y, v[6].z);
    pg.vertex(v[6].x, v[6].y, v[6].z); pg.vertex(v[7].x, v[7].y, v[7].z);
    pg.vertex(v[7].x, v[7].y, v[7].z); pg.vertex(v[4].x, v[4].y, v[4].z);
    // connections
    pg.vertex(v[0].x, v[0].y, v[0].z); pg.vertex(v[4].x, v[4].y, v[4].z);
    pg.vertex(v[1].x, v[1].y, v[1].z); pg.vertex(v[5].x, v[5].y, v[5].z);
    pg.vertex(v[2].x, v[2].y, v[2].z); pg.vertex(v[6].x, v[6].y, v[6].z);
    pg.vertex(v[3].x, v[3].y, v[3].z); pg.vertex(v[7].x, v[7].y, v[7].z);
  pg.endShape();

  pg.popMatrix();
  pg.popStyle();
}
