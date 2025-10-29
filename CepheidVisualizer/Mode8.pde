// Mode8.pde
// “Aurora Nebula” — modo experimental y libre, con desvanecimiento dinámico.

void drawMode8_spiroflower(PGraphics pg) {
  // --- Limpieza parcial con decayAlpha para el desvanecimiento ---
  pg.pushStyle();
  pg.noStroke();
  pg.fill(0, 0, 0, decayAlpha * 255);
  pg.rectMode(CENTER);
  pg.rect(0, 0, pg.width, pg.height);
  pg.popStyle();

  // --- Dibujo principal ---
  pg.pushStyle();
  pg.colorMode(HSB, 360, 100, 100);
  pg.noStroke();

  float base = min(pg.width, pg.height);
  int layers = 6 + int(fftNorm(5, 8.0) * 8);
  int pointsPerLayer = 80;
  float time = t * 0.8;
  float rmsAmp = rms * 4.0 + getShipEnergy() * 2.0;

  for (int l = 0; l < layers; l++) {
    float layerPhase = l * 0.4 + time * 0.2;
    float radius = base * (0.08 + l * 0.05 + fftNorm(l * 4 % MAX_FFT_USED, 10.0) * 0.15);
    float hueBase = (frameCount * 0.6 + l * 60 + rmsAmp * 200) % 360;
    float alpha = 90 + 60 * sin(time + l);

    for (int i = 0; i < pointsPerLayer; i++) {
      float a = i * TWO_PI / pointsPerLayer + layerPhase + sin(time * 0.5 + l) * 0.3;
      float rMod = 1.0 + 0.3 * sin(a * 5.0 + fftNorm((i + l * 10) % MAX_FFT_USED, 6.0) * 6.0 + t * 2.0);
      float x = cos(a) * radius * rMod;
      float y = sin(a) * radius * rMod;
      float z = sin(a * 3.0 + t * 0.6 + fftNorm(i % MAX_FFT_USED, 8.0) * 5.0) * base * 0.05;

      float sat = 70 + 30 * fftNorm((i + l) % MAX_FFT_USED, 6.0);
      float bri = 60 + 40 * rmsAmp;
      float size = base * 0.008 + rms * base * 0.02 + fftNorm((i + l * 3) % MAX_FFT_USED, 8.0) * base * 0.01;

      pg.fill((hueBase + i * 2) % 360, sat, bri, alpha);
      pg.pushMatrix();
      pg.translate(x, y, z);
      pg.ellipse(0, 0, size, size);
      pg.popMatrix();
    }
  }

  // --- Núcleo pulsante ---
  float coreHue = (frameCount * 0.6 + rmsAmp * 300) % 360;
  float coreSize = base * (0.1 + rms * 0.3);
  pg.fill(coreHue, 90, 100, 180);
  pg.ellipse(0, 0, coreSize, coreSize);

  pg.popStyle();
}
