void drawMode5_spiralRings(PGraphics pg) {
  overlay2D.beginDraw();
    overlay2D.clear();
    overlay2D.pushStyle();
    overlay2D.colorMode(HSB,360,100,100);
    overlay2D.noFill();
    int rings = 40;
    float R0 = min(overlay2D.width,overlay2D.height) * 0.06;
    float d = min(overlay2D.width,overlay2D.height) * 0.02;
    for (int i = 0; i < rings; i++) {
      float bandVal = fftNorm(i % MAX_FFT_USED, 6.0);
      float radius = R0 + i * d * (1.0 + bandVal * 0.6);
      float hue = map(i,0,rings, 180, 320);
      overlay2D.stroke(hue, 80, 100, 140);
      overlay2D.strokeWeight(1.0 + bandVal * 3.0);
      overlay2D.pushMatrix();
        overlay2D.translate(overlay2D.width*0.5, overlay2D.height*0.5);
        overlay2D.beginShape();
        for (float th = 0.0; th <= TWO_PI; th += 0.05) {
          float x = (radius) * cos(th);
          float y = (radius) * sin(th);
          overlay2D.vertex(x, y);
        }
        overlay2D.endShape(CLOSE);
      overlay2D.popMatrix();
    }
    overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
    pg.blendMode(ADD);
    pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
    pg.blendMode(BLEND);
  pg.popStyle();
}
