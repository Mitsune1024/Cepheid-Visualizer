// GenerationsCombined.pde
// (version integrated with provided Mode 7 - shipArms)
// Modes reordered as you requested earlier (old mode1->0 ... old mode0->8)

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
PShader glowShader;

PGraphics layerFbo;
PGraphics overlay2D;
PGraphics bloomFbo;

int mode = 0;
PVector roomSize = new PVector(400,400,400);

// timing
float t = 0.0;
float dt = 1.0/60.0;

// parameters
float decayAlpha = 0.03;
boolean useFFT = true;
boolean bloomOn = true;

final int MAX_FFT_USED = 128;

float camRotY = 0.0;
float camDist = 800.0;

// ========== Mode 7 specific globals ==========
float shipEnergySmooth = 0.0;
final int SHIP_FORMULAS = 7;
float morphU = 0.0;
float morphTargetU = 0.0;
float morphTau = 2.5;

void settings() {
  size(SCR_W, SCR_H, P3D);
}

void setup() {
  frameRate(60);
  colorMode(HSB, 360, 100, 100);
  surface.setTitle("GenerationsCombined - Live Visuals (with shipArms)");

  mic = new AudioIn(this, 0);
  mic.start();
  amp = new Amplitude(this);
  amp.input(mic);
  fft = new FFT(this, fftBands);
  fft.input(mic);
  spectrum = new float[fftBands];

  mode0Shader = null;
  glowShader = null;
  try { mode0Shader = loadShader("mode0.frag"); } catch (Exception e) { println("mode0.frag not found"); }
  try { glowShader = loadShader("glowFrag.glsl"); } catch (Exception e) { println("glowFrag.glsl not found"); }

  ensureBuffers();

  println("Loaded. Controls: keys 0..8 to switch modes, +/- adjust decayAlpha, b toggles bloom, f toggles FFT, arrows rotate camera, h prints help");
  printHelp();
}

void draw() {
  ensureBuffers();
  t = millis()/1000.0;
  updateAudio();

  // morphing update for shipArms (always update so morphU is ready when entering mode)
  morphTargetU = constrain(shipEnergySmooth * (SHIP_FORMULAS - 1), 0, SHIP_FORMULAS - 1);
  float morphAlpha = 1.0 - exp(-dt / morphTau);
  morphU = lerp(morphU, morphTargetU, morphAlpha);

  layerFbo.beginDraw();
    layerFbo.blendMode(BLEND);
    layerFbo.noStroke();
    layerFbo.pushStyle();
    layerFbo.colorMode(RGB, 255);
    float alpha = constrain(decayAlpha, 0.0005, 0.999);
    layerFbo.fill(0, alpha * 255.0);
    layerFbo.rect(0, 0, layerFbo.width, layerFbo.height);
    layerFbo.popStyle();

    layerFbo.pushMatrix();
      layerFbo.translate(layerFbo.width*0.5, layerFbo.height*0.5);
      layerFbo.rotateY(camRotY);

      switch(mode) {
        case 0: drawMode1_cubes(layerFbo); break;
        case 1: drawMode2_helix(layerFbo); break;
        case 2: drawMode3_roseton(layerFbo); break;
        case 3: drawMode4_star(layerFbo); break;
        case 4: drawMode5_spiralRings(layerFbo); break;
        case 5: drawMode6_gridStars(layerFbo); break;
        case 6: drawMode7_shipArms(layerFbo, 1.0); break; // new signature with alpha
        case 7: drawMode8_flower(layerFbo); break;
        case 8: drawMode0(layerFbo); break;
        default: break;
      }

    layerFbo.popMatrix();
  layerFbo.endDraw();

  if (glowShader != null && bloomOn) {
    bloomFbo.beginDraw();
      bloomFbo.clear();
      bloomFbo.image(layerFbo, 0, 0, bloomFbo.width, bloomFbo.height);
      bloomFbo.filter(glowShader);
    bloomFbo.endDraw();
  }

  pushStyle();
  image(layerFbo, 0, 0, width, height);
  if (glowShader != null && bloomOn) {
    blendMode(ADD);
    image(bloomFbo, 0, 0, width, height);
    blendMode(BLEND);
  }
  popStyle();

  drawHUD();
}

void ensureBuffers() {
  if (layerFbo == null || layerFbo.width != width || layerFbo.height != height) {
    println("Recreate buffers for size " + width + "x" + height);
    layerFbo = createGraphics(width, height, P3D);
    overlay2D = createGraphics(width, height, P2D);
    bloomFbo = createGraphics(width, height, P2D);

    layerFbo.beginDraw();
      layerFbo.clear();
      layerFbo.background(0);
    layerFbo.endDraw();

    overlay2D.beginDraw();
      overlay2D.clear();
    overlay2D.endDraw();

    bloomFbo.beginDraw();
      bloomFbo.clear();
    bloomFbo.endDraw();

    if (glowShader != null) {
      try { glowShader.set("resolution", float(width), float(height)); } catch (Exception e) {}
    }
  }
}

void updateAudio() {
  rms = amp.analyze();
  if (useFFT) fft.analyze(spectrum);

  // update ship energy each frame here (so shipEnergySmooth is available)
  getShipEnergy();
}

float fftNorm(int idx, float scale) {
  if (spectrum == null) return 0;
  idx = constrain(idx, 0, spectrum.length-1);
  float v = spectrum[idx];
  float nv = constrain(v * (scale), 0, 1);
  return nv;
}

// ---------- Mode implementations (kept as in your original, only mode7 replaced) ----------

void drawMode0(PGraphics pg) {
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

  pg.pushStyle();
    pg.blendMode(ADD);
    pg.image(overlay2D, -pg.width*0.5, -pg.height*0.5);
    pg.blendMode(BLEND);
  pg.popStyle();
}

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

// old mode2 (now new 1) - helix with central cube added
void drawMode2_helix(PGraphics pg) {
  pg.pushStyle();
  pg.colorMode(HSB, 360, 100, 100);
  pg.blendMode(ADD);

  float base = min(pg.width, pg.height);
  float R0 = base * 0.18;
  float k = base * 0.0018;
  float omega = 6.0;
  float step = (base > 1200) ? 2.5 : (base > 800) ? 2.0 : 3.0;
  int maxT = (base > 1200) ? 600 : (base > 800) ? 420 : 300;

  int idx = 0;
  pg.noStroke();

  pg.pushMatrix();
    for (float tt = 0; tt < maxT; tt += step) {
      float r = R0 + k * tt;
      float phaseMod = fftNorm(idx % MAX_FFT_USED, 10.0);
      float phi = omega * tt * 0.02 + phaseMod * TWO_PI + t * 0.12;

      float x = r * cos(phi);
      float y = r * sin(phi);
      float z = (tt - maxT * 0.5) * (base * 0.0009);

      float v = fftNorm(idx % MAX_FFT_USED, 6.0);
      float hue = (map(idx, 0, maxT/step, 0, 360) + frameCount * 0.3 + v * 120) % 360;
      float brightness = 80 + v * 20;
      float alpha = 160 + v * 95;

      float psBase = map(base, 300, 1600, 2.5, 18.0);
      float pointSize = psBase * (0.5 + v * 2.5) + rms * (psBase * 1.5);

      pg.pushMatrix();
        pg.translate(x, y, z);
        pg.noStroke();
        pg.fill(hue, 80, brightness, alpha);
        pg.rectMode(CENTER);
        pg.rect(0, 0, pointSize, pointSize);
      pg.popMatrix();

      idx++;
      if (idx >= MAX_FFT_USED) idx = 0;
    }

    // ---- Draw central wireframe cube to fill the center ----
    drawCenterCube(pg, base);

  pg.popMatrix();

  pg.blendMode(BLEND);
  pg.popStyle();
}

// draw a single wireframe cube in the center. Modulated by audio.
void drawCenterCube(PGraphics pg, float base) {
  pg.pushStyle();
  pg.pushMatrix();
    // cube size relative to screen
    float cubeSize = base * 0.11 + rms * base * 0.06; // bigger with RMS
    // simple rotation for motion
    float rx = sin(t * 0.8) * 0.6;
    float ry = cos(t * 0.6) * 0.6;

    pg.translate(0, 0, 0);
    pg.rotateX(rx);
    pg.rotateY(ry);

    // color derived from low FFT band
    float band0 = fftNorm(0, 8.0);
    float hue = (band0 * 180 + frameCount * 0.2) % 360;
    float strokeAlpha = 160 + band0 * 95;
    pg.noFill();
    pg.stroke(hue, 80, 100, strokeAlpha);
    pg.strokeWeight(2.0 + band0 * 3.0);

    // 8 verts
    float s = cubeSize * 0.5;
    PVector[] v = new PVector[8];
    v[0] = new PVector(-s, -s, -s);
    v[1] = new PVector(s, -s, -s);
    v[2] = new PVector(s, s, -s);
    v[3] = new PVector(-s, s, -s);
    v[4] = new PVector(-s, -s, s);
    v[5] = new PVector(s, -s, s);
    v[6] = new PVector(s, s, s);
    v[7] = new PVector(-s, s, s);

    // draw wireframe lines
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
      for (float th = 0.0; th <= TWO_PI * n; th += 0.01) {
        float x = cos(n * th) * cos(th);
        float y = cos(n * th) * sin(th);
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
      for (float th = 0.0; th <= TWO_PI; th += 0.01) {
        float rfinal = R + a * cos(k * th);
        float x = rfinal * cos(th);
        float y = rfinal * sin(th);
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
          for (float th = 0.0; th <= TWO_PI; th += 0.02) {
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

// ========== New Mode 7 (shipArms) with morphing and audio response ==========
void drawMode7_shipArms(PGraphics pg, float alpha) {
  pg.pushStyle();
  pg.noFill();
  pg.strokeWeight(1.0);

  pg.blendMode(BLEND);
  pg.colorMode(HSB, 360, 100, 100);

  pg.hint(DISABLE_DEPTH_TEST);

  float energy = shipEnergySmooth;

  int N = 40;
  float dz = 6.0;
  float baseA = min(pg.width, pg.height) * 2.67;

  float u = constrain(morphU, 0, SHIP_FORMULAS - 1);
  int i0 = int(floor(u));
  int i1 = min(i0 + 1, SHIP_FORMULAS - 1);
  float blend = u - i0;

  for (int j = 0; j < N; j++) {
    float band = fftNorm(j % MAX_FFT_USED, 8.0);

    float A = baseA * (0.32 + (band / 0.86) * 0.8);
    float z = (j - N*0.2) * (dz / 0.746);
    float hue = (j * 7) % 360;

    float alphaStroke = (30 + band * 120 * (0.5 + 0.5 * energy)) * alpha;
    pg.stroke(hue, 80, 100, alphaStroke);

    pg.beginShape();
    for (float tt = 0.0; tt < TWO_PI; tt += 0.06) {
      PVector v0 = shipFormula(i0, baseA, A, tt, j, band, t);
      PVector v1 = shipFormula(i1, baseA, A, tt, j, band, t);
      float x = lerp(v0.x, v1.x, blend);
      float y = lerp(v0.y, v1.y, blend);
      pg.vertex(x, y, z);
    }
    pg.endShape();
  }

  pg.hint(ENABLE_DEPTH_TEST);
  pg.popStyle();
}

PVector shipFormula(int idx, float baseA, float A, float tt, int j, float band, float tNow) {
  float x = 0;
  float y = 0;

  float phaseJ = tNow * (1.0 + 0.05 * j);

  switch(idx) {
    case 0:
      x = (baseA * 0.23) * sin(12 * PI * phaseJ * j) * cos(2 * PI * tt * A);
      y = (baseA * 0.1) * cos(2 * PI * tt * A) * cos(2 * PI * tt * A);
      break;
    case 1:
      x = (baseA * 0.18) * sin(6 * PI * phaseJ * j) * cos(2 * PI * tt * (A * 0.6));
      y = (baseA * 0.14) * sin(2 * PI * tt * (A * 0.9)) * cos(2 * PI * tt * (A * 0.6));
      break;
    case 2:
      float spikeAmp = 1.0 + band * 3.0 + shipEnergySmooth * 4.0;
      x = (baseA * 0.28) * sin(18 * PI * phaseJ * j) * cos(2 * PI * tt * A) * spikeAmp;
      y = (baseA * 0.08) * cos(2 * PI * tt * A) * cos(4 * PI * tt * A) * spikeAmp;
      break;
    case 3:
      float r = baseA * 0.06 * (1.0 + 0.8 * band);
      x = r * cos(tt) * (1.0 + 0.5 * sin(4.0 * tt + phaseJ));
      y = r * sin(tt) * (1.0 + 0.5 * cos(3.0 * tt - phaseJ));
      break;
    case 4:
      float lobes = 3.0 + floor(band * 5.0);
      float rad = baseA * 0.12 * (1.0 + 0.6 * sin(lobes * tt + phaseJ));
      x = rad * cos(tt);
      y = rad * sin(tt) * (0.6 + 0.4 * cos(2.0 * tt + phaseJ));
      break;
    case 5:
      float rr = baseA * 0.02 * (1.0 + tt * 0.2) * (1.0 + 0.6 * band);
      x = rr * cos(2.0 * tt + 0.2 * phaseJ) * (1.0 + 0.3 * sin(6.0 * tt));
      y = rr * sin(2.0 * tt + 0.2 * phaseJ) * (1.0 + 0.3 * cos(5.0 * tt));
      break;
    case 6:
      float p = 1.0 + 0.8 * sin(8.0 * tt + phaseJ) + 0.5 * sin(16.0 * tt * (1.0 + band));
      x = (baseA * 0.15) * cos(tt) * p;
      y = (baseA * 0.12) * sin(tt) * p;
      break;
    default:
      x = (baseA * 0.2) * cos(tt);
      y = (baseA * 0.1) * sin(tt);
      break;
  }

  return new PVector(x, y);
}

float getShipEnergy() {
  float bandLow = fftNorm(2, 8.0);
  float raw = constrain(rms * 4.0, 0, 1);
  float combined = max(raw, bandLow);

  float smoothFactor = 0.08;
  shipEnergySmooth = lerp(shipEnergySmooth, combined, smoothFactor);
  return shipEnergySmooth;
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
  float Ntheta = 20.0 * PI;
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

void drawHUD() {
  hint(DISABLE_DEPTH_MASK);
  pushStyle();
  colorMode(RGB,255);
  fill(255,220);
  noStroke();
  textSize(12);
  textAlign(LEFT, TOP);
  String bloomS = bloomOn ? "ON" : "OFF";
  text("Mode " + mode + "  | RMS " + nf(rms,1,3) + "  | decayAlpha " + nf(decayAlpha,2,3) + "  | Bloom: " + bloomS + "  | size " + width + "x" + height, 8, 8);
  textAlign(RIGHT, TOP);
  text("FPS " + int(frameRate), width-8, 8);
  popStyle();
  hint(ENABLE_DEPTH_MASK);
}

void keyPressed() {
  if (key >= '0' && key <= '8') {
    mode = key - '0';
    println("mode -> " + mode);
    if (layerFbo != null) {
      layerFbo.beginDraw();
        layerFbo.clear();
        layerFbo.background(0);
      layerFbo.endDraw();
    }
  } else if (key == '+') decayAlpha = max(0.0005, decayAlpha - 0.005);
  else if (key == '-') decayAlpha = min(0.5, decayAlpha + 0.005);
  else if (key == 'b' || key == 'B') {
    bloomOn = !bloomOn;
    println("bloomOn = " + bloomOn);
  } else if (key == 'f' || key == 'F') {
    useFFT = !useFFT;
    println("useFFT = " + useFFT);
  } else if (key == CODED) {
    if (keyCode == LEFT) camRotY -= 0.08;
    if (keyCode == RIGHT) camRotY += 0.08;
    if (keyCode == UP) camDist = max(200, camDist - 20);
    if (keyCode == DOWN) camDist += 20;
  } else if (key == 'h' || key == 'H') {
    printHelp();
  }
}

void printHelp() {
  println("Controls:");
  println("0..8 : select mode (reordered)");
  println("+ / - : adjust persistence decay (smaller = longer trails)");
  println("b : toggle bloom");
  println("Arrow keys : rotate/dolly camera (Y rotation only active)");
  println("f : toggle FFT usage");
  println("h : print this help");
}
