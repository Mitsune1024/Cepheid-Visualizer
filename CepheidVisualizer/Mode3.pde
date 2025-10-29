// Mode3.pde
// Rosetón reactivo al audio — versión restaurada y mejorada

void drawMode3_roseton(PGraphics pg) {
  overlay2D.beginDraw();
  overlay2D.clear();
  overlay2D.pushStyle();
  overlay2D.colorMode(HSB, 360, 100, 100);
  overlay2D.noFill();

  overlay2D.translate(overlay2D.width * 0.5, overlay2D.height * 0.5);

  float energy = getShipEnergy();
  float base = min(overlay2D.width, overlay2D.height);
  float radius = base * (0.25 + fftNorm(2, 5.0) * 0.35);
  int petals = 6 + int(fftNorm(1, 5.0) * 12);
  int layers = 3 + int(fftNorm(3, 5.0) * 5);

  for (int l = 0; l < layers; l++) {
    float hue = (frameCount * 0.6 + l * 40) % 360;
    float amp = 0.4 + 0.2 * sin(t * 0.6 + l);
    overlay2D.stroke(hue, 80, 100, 180 - l * 25);
    overlay2D.strokeWeight(1.2 + l * 0.2);

    overlay2D.beginShape();
    for (float a = 0; a < TWO_PI; a += 0.02) {
      float f = sin(petals * a + t * (0.8 + l * 0.3)) * amp;
      float r = radius * (1.0 + f * energy);
      float x = cos(a) * r;
      float y = sin(a) * r;
      overlay2D.vertex(x, y);
    }
    overlay2D.endShape(CLOSE);
  }

  overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
  pg.blendMode(ADD);
  pg.image(overlay2D, -pg.width * 0.5, -pg.height * 0.5);
  pg.blendMode(BLEND);
  pg.popStyle();
}
