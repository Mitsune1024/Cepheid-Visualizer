// Mode6.pde
// Grid of stars / luces pulsantes

void drawMode6_gridStars(PGraphics pg) {

  overlay2D.beginDraw();
  overlay2D.clear();
  overlay2D.pushStyle();
  overlay2D.colorMode(HSB, 360, 100, 100);
  overlay2D.strokeWeight(1.8);
  overlay2D.noFill();

  float base = min(overlay2D.width, overlay2D.height);
  float centerX = overlay2D.width * 0.5;
  float centerY = overlay2D.height * 0.5;

  float energy = getShipEnergy();

  int arms = 12;
  float maxRadius = base * 0.48;

  for (int i = 0; i < arms; i++) {
    float bandVal = fftNorm(i % MAX_FFT_USED, 8.0);
    float armPhase = t * 0.9 + i * 0.5;
    float hue = (i * 30 + frameCount * 0.3 + bandVal * 180) % 360;
    overlay2D.stroke(hue, 80, 100, 200);

    overlay2D.beginShape();
    int segments = 120;
    for (int j = 0; j < segments; j++) {
      float ang = armPhase + j * 0.06;
      float radius = map(j, 0, segments, 0, maxRadius);
      float mod = sin(ang * 0.9 + fftNorm((i + j) % MAX_FFT_USED, 10.0) * PI * 2.0);
      float r = radius * (0.7 + mod * 0.3 + rms * 1.8);
      float x = centerX + cos(ang) * r;
      float y = centerY + sin(ang) * r;
      overlay2D.vertex(x, y);
    }
    overlay2D.endShape();
  }

  overlay2D.popStyle();
  overlay2D.endDraw();

  // Dibujar en el PGraphics principal con blendMode(ADD) y decayAlpha correcto
  pg.pushStyle();
  pg.blendMode(ADD);
  pg.image(overlay2D, -pg.width * 0.5, -pg.height * 0.5);
  pg.blendMode(BLEND);
  pg.popStyle();
}
