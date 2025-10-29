// Mode0.pde
// Fondo generativo / shader fallback

void drawMode0(PGraphics pg) {
  pg.pushStyle();
  pg.pushMatrix();

  // Si existe shader, úsalo sobre el layerFbo
  if (mode0Shader != null) {
    try {
      mode0Shader.set("iTime", t);
      mode0Shader.set("iResolution", (float)pg.width, (float)pg.height);
      pg.beginDraw();
      pg.shader(mode0Shader);
      pg.rect( -pg.width*0.5, -pg.height*0.5, pg.width, pg.height );
      pg.resetShader();
      pg.endDraw();
    } catch (Exception e) {
      // fallback a dibujo manual abajo
    }
    pg.popMatrix();
    pg.popStyle();
    return;
  }

  // Fallback: gradiente y partículas sencillas
  pg.colorMode(HSB, 360, 100, 100);
  pg.noStroke();
  for (int i = 0; i < 60; i++) {
    float r = map(i, 0, 60, 0, min(pg.width, pg.height) * 0.7f);
    float hue = (frameCount * 0.05f + i * 6.0f) % 360;
    pg.fill(hue, 40, 12, 6);
    pg.ellipse(0, 0, r, r);
  }

  // partículas reactivas
  int N = 80;
  for (int i = 0; i < N; i++) {
    float a = i * TWO_PI / N + t * 0.2f;
    float rad = min(pg.width, pg.height) * 0.35f + sin(t * 1.2f + i) * (rms * 120.0f);
    float x = cos(a) * rad;
    float y = sin(a) * rad;
    float hue = (i * 5 + frameCount * 0.2f) % 360;
    float s = 1.5f + rms * 12.0f;
    pg.fill(hue, 70, 100, 200);
    pg.ellipse(x, y, s, s);
  }

  pg.popMatrix();
  pg.popStyle();
}
