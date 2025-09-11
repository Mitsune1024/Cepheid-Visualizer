// GenerationsCombined.pde
// Modes:
// 0 = Sphere (previous mode0 shader)
// 1 = Grid of rotating wireframe cubes (FFT-driven)
// 2 = Helix of points (spiral vertical)
// 3 = Rosette harmonic (2D polygonal rosette)
// 4 = Star radial (polar r(t) = R + a*cos(k t))
// 5 = Spiral of concentric rings (z stacked)
// 6 = Grid of parametric stars (small rosettes per cell)
// 7 = Reflective modular "ship" arms structure
// 8 = Enveloping spiral flower (3D spirograph)
//
// This variant adapts to resolution changes (fullscreen) by recreating
// the PGraphics buffers and updating shader resolution when needed.

import processing.sound.*;
import java.util.ArrayList;

int SCR_W = 960;
int SCR_H = 640;

AudioIn mic;
Amplitude amp;
FFT fft;
int fftBands = 512;
float[] spectrum;
float rms = 0.0;

PShader mode0Shader;
PShader bloom;

PGraphics layerFbo;   // feedback / accumulation FBO (P3D)
PGraphics overlay2D;  // used for 2D-only modes (grid lines etc.)

int mode = 0; // current mode (0..8)
PVector roomSize = new PVector(400,400,400);

// timing
float t = 0.0;
float dt = 1.0/60.0;

// parameters
float decayAlpha = 0.03; // alpha applied each frame for decay (smaller = longer persistence)
boolean useFFT = true;

// Useful geometry constants
final int MAX_FFT_USED = 128; // how many bands we'll sample at most (safety)

// camera control
float camRotY = 0.0;
float camDist = 800.0; // reserved; not used as big translate

void settings() {
  size(SCR_W, SCR_H, P3D);
}

void setup() {
  frameRate(60);
  colorMode(HSB, 360, 100, 100);
  surface.setTitle("GenerationsCombined - multi-modes (responsive)");

  // audio initialization
  mic = new AudioIn(this, 0);
  mic.start();
  amp = new Amplitude(this);
  amp.input(mic);
  fft = new FFT(this, fftBands);
  fft.input(mic);
  spectrum = new float[fftBands];

  // load shaders if present
  mode0Shader = null;
  bloom = null;
  try { mode0Shader = loadShader("mode0.frag"); } catch (Exception e) { println("mode0.frag not found"); }
  try { bloom = loadShader("glowFrag.glsl"); } catch (Exception e) { println("glowFrag.glsl not found"); }

  // create initial buffers using current width/height
  ensureBuffers();

  println("Loaded. Controls: keys 0..8 to switch modes, +/- adjust decayAlpha, arrows rotate camera, f toggles FFT, h prints help");
  printHelp();
}

void draw() {
  // Ensure buffers match current window size (handles fullscreen/resizing)
  ensureBuffers();

  t = millis()/1000.0;
  updateAudio();

  // render into accumulation FBO with fade for persistence
  layerFbo.beginDraw();
    // fade previous frame slightly to keep persistence/trails
    layerFbo.noStroke();
    layerFbo.pushStyle();
    layerFbo.colorMode(RGB,255);
    float alpha = constrain(decayAlpha, 0.001, 0.9);
    layerFbo.fill(0, (int)(alpha * 255.0));
    layerFbo.rect(0,0,layerFbo.width,layerFbo.height);
    layerFbo.popStyle();

    // debug faint grid so we can confirm FBO is rendering
    layerFbo.pushStyle();
      layerFbo.stroke(0, 10);
      layerFbo.strokeWeight(1);
      for (int gx = 0; gx < layerFbo.width; gx += max(1, layerFbo.width/6)) layerFbo.line(gx, 0, gx, layerFbo.height);
      for (int gy = 0; gy < layerFbo.height; gy += max(1, layerFbo.height/6)) layerFbo.line(0, gy, layerFbo.width, gy);
    layerFbo.popStyle();

    // center coordinates for drawing and apply Y rotation
    layerFbo.pushMatrix();
    layerFbo.translate(layerFbo.width*0.5, layerFbo.height*0.5);
    layerFbo.rotateY(camRotY);

    // draw current mode
    switch(mode) {
      case 0: drawMode0(layerFbo); break;
      case 1: drawMode1_cubes(layerFbo); break;
      case 2: drawMode2_helix(layerFbo); break;
      case 3: drawMode3_roseton(layerFbo); break;
      case 4: drawMode4_star(layerFbo); break;
      case 5: drawMode5_spiralRings(layerFbo); break;
      case 6: drawMode6_gridStars(layerFbo); break;
      case 7: drawMode7_shipArms(layerFbo); break;
      case 8: drawMode8_flower(layerFbo); break;
      default: break;
    }

    layerFbo.popMatrix();
  layerFbo.endDraw();

  // final composite: scale FBO to current window (should match exactly)
  image(layerFbo, 0, 0, width, height);

  // HUD
  drawHUD();
}

// ensure PGraphics and shader resolution match current width/height
void ensureBuffers() {
  // if layerFbo not created or size mismatch, recreate both buffers
  if (layerFbo == null || layerFbo.width != width || layerFbo.height != height) {
    println("Recreating buffers to match new size: " + width + "x" + height);
    // dispose old references (leave GC to handle actual memory)
    layerFbo = createGraphics(width, height, P3D);
    overlay2D = createGraphics(width, height, P2D);

    // clear them
    layerFbo.beginDraw();
      layerFbo.clear();
      layerFbo.background(0);
    layerFbo.endDraw();

    overlay2D.beginDraw();
      overlay2D.clear();
    overlay2D.endDraw();

    // update bloom shader resolution if present
    if (bloom != null) {
      try {
        bloom.set("resolution", float(width), float(height));
      } catch (Exception e) {
        // some GLSL variations may not accept this uniform; ignore safely
      }
    }
  }
}

// ---------- audio helpers ----------
void updateAudio() {
  rms = amp.analyze(); // envelope 0..~1
  if (useFFT) {
    fft.analyze(spectrum); // fill spectrum[]
  }
}

// normalized FFT accessor (0..1)
float fftNorm(int idx, float scale) {
  if (spectrum == null) return 0;
  idx = constrain(idx, 0, spectrum.length-1);
  float v = spectrum[idx];
  float nv = constrain(v * (scale), 0, 1);
  return nv;
}

// ---------- Mode 0: Sphere using shader ----------
void drawMode0(PGraphics pg) {
  // render the shader into overlay2D freshly (clear first)
  overlay2D.beginDraw();
    overlay2D.clear();
    overlay2D.noStroke();
    if (mode0Shader != null) {
      overlay2D.shader(mode0Shader);
      mode0Shader.set("resolution", float(overlay2D.width), float(overlay2D.height));
      mode0Shader.set("center", overlay2D.width*0.5/overlay2D.width, overlay2D.height*0.5/overlay2D.height);
      mode0Shader.set("radius", 0.16);
      mode0Shader.set("time", t);
      mode0Shader.set("audioLevel", rms);
      mode0Shader.set("haloIntensity", 0.6);
      mode0Shader.set("glowPass", 0);
    } else {
      overlay2D.background(10);
    }
    overlay2D.rect(0,0,overlay2D.width,overlay2D.height);
    if (mode0Shader != null) overlay2D.resetShader();
  overlay2D.endDraw();

  // composite overlay2D onto pg using ADD blending
  pg.pushStyle();
    pg.blendMode(ADD);
    pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
    pg.blendMode(BLEND);
  pg.popStyle();
}

// ---------- Mode 1: Grid of rotating wireframe cubes ----------
void drawMode1_cubes(PGraphics pg) {
  pg.pushStyle();
  pg.strokeWeight(1.2);
  pg.noFill();

  int gridX = 5;
  int gridY = 5;
  float spacing = min(pg.width, pg.height) * 0.12;
  float cubeSize = spacing * 0.35;

  for (int gx = 0; gx < gridX; gx++) {
    for (int gy = 0; gy < gridY; gy++) {
      int i = gx * gridY + gy;
      float f0 = fftNorm(i % MAX_FFT_USED, 6.0);
      float f1 = fftNorm((i+1) % MAX_FFT_USED, 6.0);

      float cx = (gx - (gridX-1)/2.0) * spacing;
      float cy = (gy - (gridY-1)/2.0) * spacing;
      float cz = 0;

      float rx = sin(t * 0.5 + i * 0.3) * 0.6 + f0 * PI;
      float ry = f0 * PI * 0.8;
      float rz = f1 * PI * 0.8;

      float hue = (i * 17) % 360;
      int col = color(hue, 80, 100);
      pg.stroke(col, 180);

      PVector[] verts = new PVector[8];
      float s = cubeSize * 0.5;
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
        pg.strokeWeight(1.4 + f0 * 2.0);
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

PVector multiplyAndTranslate(PMatrix3D m, PVector v, float tx, float ty, float tz) {
  float x = m.m00*v.x + m.m01*v.y + m.m02*v.z + m.m03;
  float y = m.m10*v.x + m.m11*v.y + m.m12*v.z + m.m13;
  float z = m.m20*v.x + m.m21*v.y + m.m22*v.z + m.m23;
  return new PVector(x + tx, y + ty, z + tz);
}

void drawLineBetween(PGraphics pg, PVector a, PVector b) {
  pg.vertex(a.x, a.y, a.z);
  pg.vertex(b.x, b.y, b.z);
}

// ---------- Mode 2: Helix of points ----------
void drawMode2_helix(PGraphics pg) {
  pg.pushStyle();
  pg.noFill();

  float R0 = min(pg.width, pg.height) * 0.04;
  float k = 0.015 * min(pg.width, pg.height) * 0.01;
  float omega = 6.0;
  float maxT = 300.0;
  float step = 1.0;
  pg.strokeWeight(2.0);

  int idx = 0;
  for (float tt = 0; tt < maxT; tt += step) {
    float r = R0 + k * tt;
    float phi = omega * tt * 0.02 + fftNorm((idx) % MAX_FFT_USED, 8.0) * PI * 2.0;
    float x = r * cos(phi);
    float y = r * sin(phi);
    float z = (tt - maxT*0.5) * 0.6;
    float v = fftNorm(idx % MAX_FFT_USED, 6.0);
    float hue = map(v, 0, 1, 180, 320);

    float ps = 1.0 + v * 6.0;
    pg.pushMatrix();
      pg.translate(x, y, z);
      pg.rotateY(t * 0.15);
      pg.noStroke();
      pg.fill(hue, 80, 100);
      pg.box(ps);
    pg.popMatrix();

    idx++;
    if (idx > MAX_FFT_USED-2) idx = 0;
  }
  pg.popStyle();
}

// ---------- Mode 3..8 (2D overlays) ----------
void drawMode3_roseton(PGraphics pg) {
  overlay2D.beginDraw();
    overlay2D.clear();
    overlay2D.pushStyle();
    overlay2D.colorMode(HSB,360,100,100);
    overlay2D.noFill();
    overlay2D.strokeWeight(2.0);
    float f1 = fftNorm(2, 6.0);
    int n = int(3 + f1 * 10.0);
    float scale = min(overlay2D.width, overlay2D.height) * (0.3 + fftNorm(1,6.0) * 0.3);
    float hue = (frameCount * 0.6) % 360;
    overlay2D.stroke(hue, 80, 100, 220);

    overlay2D.pushMatrix();
      overlay2D.translate(overlay2D.width*0.5, overlay2D.height*0.5);
      overlay2D.beginShape();
      for (float tt = 0; tt < TWO_PI * n; tt += 0.01) {
        float x = cos(n * tt) * cos(tt);
        float y = cos(n * tt) * sin(tt);
        overlay2D.vertex(x * scale, y * scale);
      }
      overlay2D.endShape();
    overlay2D.popMatrix();

    overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
  pg.blendMode(ADD);
  pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
  pg.blendMode(BLEND);
  pg.popStyle();
}

void drawMode4_star(PGraphics pg) {
  overlay2D.beginDraw();
    overlay2D.clear();
    overlay2D.pushStyle();
    overlay2D.colorMode(HSB,360,100,100);
    overlay2D.noFill();
    int k = 5 + int(fftNorm(4,6.0) * 10.0);
    float R = min(overlay2D.width, overlay2D.height) * 0.3;
    float a = min(overlay2D.width, overlay2D.height) * 0.2;
    float hue = (frameCount * 0.7) % 360;
    overlay2D.stroke(hue, 80, 100);
    overlay2D.strokeWeight(2.0);

    overlay2D.pushMatrix();
      overlay2D.translate(overlay2D.width*0.5, overlay2D.height*0.5);
      overlay2D.beginShape();
      for (float tt = 0; tt < TWO_PI + 0.001; tt += 0.01) {
        float rfinal = R + a * cos(k * tt);
        float x = rfinal * cos(tt);
        float y = rfinal * sin(tt);
        overlay2D.vertex(x, y);
      }
      overlay2D.endShape(CLOSE);
    overlay2D.popMatrix();

    overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
    pg.blendMode(ADD);
    pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
    pg.blendMode(BLEND);
  pg.popStyle();
}

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
        for (float th = 0; th < TWO_PI + 0.001; th += 0.05) {
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

void drawMode6_gridStars(PGraphics pg) {
  overlay2D.beginDraw();
    overlay2D.clear();
    overlay2D.pushStyle();
    overlay2D.colorMode(HSB,360,100,100);
    overlay2D.noFill();
    int nx = 5;
    int ny = 5;
    float cellW = overlay2D.width / float(nx + 1);
    float cellH = overlay2D.height / float(ny + 1);
    for (int i = 0; i < nx; i++) {
      for (int j = 0; j < ny; j++) {
        int bandIndex = (i*ny + j) % MAX_FFT_USED;
        float ff = fftNorm(bandIndex, 6.0);
        float R = min(cellW,cellH) * 0.18 * (1.0 + ff * 0.8);
        float A = min(cellW,cellH) * 0.05;
        int k = 5 + int(ff * 8.0);
        float cx = (i+1) * cellW - cellW*0.5;
        float cy = (j+1) * cellH - cellH*0.5;
        int hue = (bandIndex * 23) % 360;
        overlay2D.stroke(hue, 80, 100, 200);
        overlay2D.strokeWeight(1.2);
        overlay2D.pushMatrix();
          overlay2D.translate(cx, cy);
          overlay2D.beginShape();
          for (float th = 0; th < TWO_PI + 0.001; th += 0.02) {
            float r = R + A * cos(k * th);
            float x = r * cos(th);
            float y = r * sin(th);
            overlay2D.vertex(x, y);
          }
          overlay2D.endShape(CLOSE);
        overlay2D.popMatrix();
      }
    }
    overlay2D.popStyle();
  overlay2D.endDraw();

  pg.pushStyle();
    pg.blendMode(ADD);
    pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
    pg.blendMode(BLEND);
  pg.popStyle();
}

void drawMode7_shipArms(PGraphics pg) {
  pg.pushStyle();
  pg.noFill();
  pg.strokeWeight(1.0);
  int N = 40;
  float dz = 6.0;
  float baseA = min(pg.width,pg.height) * 0.12;
  for (int j = 0; j < N; j++) {
    float band = fftNorm(j % MAX_FFT_USED, 6.0);
    float A = baseA * (0.5 + band * 0.8);
    float z = (j - N*0.5) * dz;
    float hue = (j * 9) % 360;
    pg.stroke(hue, 80, 100, 160);
    pg.beginShape();
    for (float tt = 0; tt < TWO_PI; tt += 0.06) {
      float x = A * sin(12.0 * t + j * 0.3 + tt);
      float y = (baseA * 0.1) * sin(t * 0.5 + j * 0.2 + tt*0.4);
      pg.vertex(x, y, z);
    }
    pg.endShape();
    // mirrored copy for symmetry
    pg.beginShape();
    for (float tt = 0; tt < TWO_PI; tt += 0.06) {
      float x = -A * sin(12.0 * t + j * 0.3 + tt);
      float y = (baseA * 0.1) * sin(t * 0.5 + j * 0.2 + tt*0.4);
      pg.vertex(x, y, z);
    }
    pg.endShape();
  }
  pg.popStyle();
}

void drawMode8_flower(PGraphics pg) {
  pg.pushStyle();
  pg.noFill();
  pg.strokeWeight(1.2);
  int steps = 1200;
  float R = min(pg.width,pg.height) * 0.2;
  float a = min(pg.width,pg.height) * 0.2;
  float b = min(pg.width,pg.height) * 0.2 * 0.5;
  int k = 6;
  int m = 7;
  float phi = fftNorm(6, 6.0) * TWO_PI;
  float Ntheta = 20.0 * PI; // about 20π
  pg.stroke(200, 80, 100, 200);

  pg.pushMatrix();
  pg.beginShape();
  for (float theta = 0.0; theta < Ntheta; theta += Ntheta / steps) {
    float r = R + a * sin(k * theta);
    float x = r * cos(theta);
    float y = r * sin(theta);
    float z = b * sin(m * theta + phi);
    pg.vertex(x, y, z * 0.8);
  }
  pg.endShape();
  pg.popMatrix();
  pg.popStyle();
}

// HUD, input and helpers
void drawHUD() {
  hint(DISABLE_DEPTH_MASK);
  pushStyle();
  colorMode(RGB,255);
  fill(255,220);
  noStroke();
  textSize(12);
  textAlign(LEFT, TOP);
  text("Mode " + mode + "  (0..8)  |  RMS " + nf(rms,1,3) + "  |  decayAlpha " + nf(decayAlpha,2,3) + "  |  size " + width + "x" + height, 8, 8);
  textAlign(RIGHT, TOP);
  text("FPS " + int(frameRate), width-8, 8);
  popStyle();
  hint(ENABLE_DEPTH_MASK);
}

void keyPressed() {
  if (key >= '0' && key <= '8') {
    mode = key - '0';
    println("mode -> " + mode);
    // clear FBO to remove artifacts when switching modes
    if (layerFbo != null) {
      layerFbo.beginDraw();
        layerFbo.clear();
        layerFbo.background(0);
      layerFbo.endDraw();
    }
  } else if (key == '+') decayAlpha = max(0.001, decayAlpha - 0.005);
  else if (key == '-') decayAlpha = min(0.2, decayAlpha + 0.005);
  else if (key == CODED) {
    if (keyCode == LEFT) camRotY -= 0.08;
    if (keyCode == RIGHT) camRotY += 0.08;
    if (keyCode == UP) camDist = max(200, camDist - 20);
    if (keyCode == DOWN) camDist += 20;
  } else if (key == 'f' || key == 'F') {
    useFFT = !useFFT;
    println("useFFT = " + useFFT);
  } else if (key == 'h' || key == 'H') {
    printHelp();
  }
}

void printHelp() {
  println("Controls:");
  println("0..8 : select mode");
  println("+ / - : adjust persistence decay (smaller = longer trails)");
  println("Arrow keys : rotate/dolly camera (Y rotation only active)");
  println("f : toggle FFT usage");
  println("h : print this help");
}
