// Mode4.pde
// Estrella pulsante / starfield reactivo al audio

void drawMode4_star(PGraphics pg) {
  overlay2D.beginDraw();
  overlay2D.clear();
  overlay2D.pushStyle();
  overlay2D.colorMode(HSB, 360, 100, 100);
  overlay2D.noFill();

  overlay2D.translate(overlay2D.width * 0.5, overlay2D.height * 0.5);

  float energy = getShipEnergy();
  float base = min(overlay2D.width, overlay2D.height);
  float radius = base * (0.25 + fftNorm(2, 6.0) * 0.25);
  int points = 5 + int(fftNorm(3, 8.0) * 6);
  float rotation = t * 0.8;

  int layers = 3;
  for (int l = 0; l < layers; l++) {
    float hue = (frameCount * 0.8 + l * 60) % 360;
    overlay2D.stroke(hue, 80, 100, 180 - l * 40);
    overlay2D.strokeWeight(1.5 + l * 0.3);

    overlay2D.pushMatrix();
    overlay2D.rotate(rotation + l * 0.3);

    overlay2D.beginShape();
    for (int i = 0; i < points * 2; i++) {
      float angle = i * PI / points;
      float r = (i % 2 == 0) ? radius : radius * (0.4 + 0.4 * energy);
      float x = cos(angle) * r;
      float y = sin(angle) * r;
      overlay2D.vertex(x, y);
    }
    overlay2D.endShape(CLOSE);
    overlay2D.popMatrix();
  }

  overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
  pg.blendMode(ADD);
  pg.image(overlay2D, -pg.width * 0.5, -pg.height * 0.5);
  pg.blendMode(BLEND);
  pg.popStyle();
}
