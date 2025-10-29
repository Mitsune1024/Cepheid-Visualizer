// Mode1.pde
// Grid de wireframe-cubes renderizado en un overlay 3D limpio (sin cubo central).

void drawMode1_cubes(PGraphics pg) {
  if (overlay3D == null) {
    drawMode1_direct(pg);
    return;
  }

  overlay3D.beginDraw();
  overlay3D.clear();
  overlay3D.pushStyle();
  overlay3D.pushMatrix();
  overlay3D.translate(overlay3D.width * 0.5, overlay3D.height * 0.5, 0);
  overlay3D.colorMode(HSB, 360, 100, 100);
  overlay3D.noFill();
  overlay3D.strokeWeight(1.2);
  overlay3D.strokeCap(ROUND);
  overlay3D.hint(ENABLE_DEPTH_TEST);

  int gridX = 5;
  int gridY = 5;
  float spacing = min(overlay3D.width, overlay3D.height) * 0.12;
  float cubeSize = spacing * 0.35;

  int idxGlobal = 0;
  for (int gx = 0; gx < gridX; gx++) {
    for (int gy = 0; gy < gridY; gy++) {
      int i = gx * gridY + gy;
      float f0 = fftNorm(i % MAX_FFT_USED, 6.0);
      float f1 = fftNorm((i + 1) % MAX_FFT_USED, 6.0);

      float cx = (gx - (gridX - 1) / 2.0) * spacing;
      float cy = (gy - (gridY - 1) / 2.0) * spacing;
      float cz = 0;

      float rx = sin(t * 0.5 + i * 0.3) * 0.6f + f0 * PI * 0.6f;
      float ry = f0 * PI * 0.8f;
      float rz = f1 * PI * 0.8f;

      float hue = (i * 17) % 360;
      overlay3D.stroke(hue, 80, 100, 200);

      PVector[] verts = new PVector[8];
      float s = cubeSize * 0.5f;
      verts[0] = new PVector(-s, -s, -s);
      verts[1] = new PVector(s, -s, -s);
      verts[2] = new PVector(s, s, -s);
      verts[3] = new PVector(-s, s, -s);
      verts[4] = new PVector(-s, -s, s);
      verts[5] = new PVector(s, -s, s);
      verts[6] = new PVector(s, s, s);
      verts[7] = new PVector(-s, s, s);

      PMatrix3D R = new PMatrix3D();
      R.rotateX(rx);
      R.rotateY(ry);
      R.rotateZ(rz);

      PVector[] tv = new PVector[8];
      for (int k = 0; k < 8; k++) tv[k] = multiplyAndTranslate(R, verts[k], cx, cy, cz);

      overlay3D.pushMatrix();
        overlay3D.noFill();
        overlay3D.strokeWeight(1.4f + f0 * 2.0f);
        overlay3D.beginShape(LINES);
          drawLineBetween(overlay3D, tv[0], tv[1]);
          drawLineBetween(overlay3D, tv[1], tv[2]);
          drawLineBetween(overlay3D, tv[2], tv[3]);
          drawLineBetween(overlay3D, tv[3], tv[0]);

          drawLineBetween(overlay3D, tv[4], tv[5]);
          drawLineBetween(overlay3D, tv[5], tv[6]);
          drawLineBetween(overlay3D, tv[6], tv[7]);
          drawLineBetween(overlay3D, tv[7], tv[4]);

          drawLineBetween(overlay3D, tv[0], tv[4]);
          drawLineBetween(overlay3D, tv[1], tv[5]);
          drawLineBetween(overlay3D, tv[2], tv[6]);
          drawLineBetween(overlay3D, tv[3], tv[7]);
        overlay3D.endShape();
      overlay3D.popMatrix();

      idxGlobal++;
      if (idxGlobal >= MAX_FFT_USED) idxGlobal = 0;
    }
  }

  overlay3D.popMatrix();
  overlay3D.popStyle();
  overlay3D.endDraw();

  pg.pushStyle();
  pg.blendMode(BLEND);
  pg.image(overlay3D, -pg.width * 0.5f, -pg.height * 0.5f);
  pg.blendMode(BLEND);
  pg.popStyle();
}

// Fallback sin overlay3D
void drawMode1_direct(PGraphics pg) {
  pg.pushStyle();
  pg.strokeWeight(1.2f);
  pg.noFill();

  int gridX = 5;
  int gridY = 5;
  float spacing = min(pg.width, pg.height) * 0.12f;
  float cubeSize = spacing * 0.35f;

  for (int gx = 0; gx < gridX; gx++) {
    for (int gy = 0; gy < gridY; gy++) {
      int i = gx * gridY + gy;
      float f0 = fftNorm(i % MAX_FFT_USED, 6.0);
      float f1 = fftNorm((i+1) % MAX_FFT_USED, 6.0);

      float cx = (gx - (gridX-1)/2.0f) * spacing;
      float cy = (gy - (gridY-1)/2.0f) * spacing;
      float cz = 0;

      float rx = sin(t * 0.5f + i * 0.3f) * 0.6f + f0 * PI * 0.6f;
      float ry = f0 * PI * 0.8f;
      float rz = f1 * PI * 0.8f;

      float hue = (i * 17) % 360;
      pg.stroke(hue, 80, 100, 200);

      PVector[] verts = new PVector[8];
      float s = cubeSize * 0.5f;
      verts[0] = new PVector(-s, -s, -s);
      verts[1] = new PVector(s, -s, -s);
      verts[2] = new PVector(s, s, -s);
      verts[3] = new PVector(-s, s, -s);
      verts[4] = new PVector(-s, -s, s);
      verts[5] = new PVector(s, -s, s);
      verts[6] = new PVector(s, s, s);
      verts[7] = new PVector(-s, s, s);

      PMatrix3D R = new PMatrix3D();
      R.rotateX(rx);
      R.rotateY(ry);
      R.rotateZ(rz);

      PVector[] tv = new PVector[8];
      for (int k = 0; k < 8; k++) tv[k] = multiplyAndTranslate(R, verts[k], cx, cy, cz);

      pg.pushMatrix();
        pg.noFill();
        pg.strokeWeight(1.4f + f0 * 2.0f);
        pg.beginShape(LINES);
          drawLineBetween(pg, tv[0], tv[1]);
          drawLineBetween(pg, tv[1], tv[2]);
          drawLineBetween(pg, tv[2], tv[3]);
          drawLineBetween(pg, tv[3], tv[0]);

          drawLineBetween(pg, tv[4], tv[5]);
          drawLineBetween(pg, tv[5], tv[6]);
          drawLineBetween(pg, tv[6], tv[7]);
          drawLineBetween(pg, tv[7], tv[4]);

          drawLineBetween(pg, tv[0], tv[4]);
          drawLineBetween(pg, tv[1], tv[5]);
          drawLineBetween(pg, tv[2], tv[6]);
          drawLineBetween(pg, tv[3], tv[7]);
        pg.endShape();
      pg.popMatrix();
    }
  }
  pg.popStyle();
}
