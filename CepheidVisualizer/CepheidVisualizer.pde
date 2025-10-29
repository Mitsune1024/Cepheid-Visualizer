// CepheidVisualizer.pde
// Versión modularizada basada en GenerationsCombined.pde
// Archivo principal. Mantén modes/ con los modos y data/ con shaders.

import processing.sound.*;
import java.util.ArrayList;

int SCR_W = 1280;
int SCR_H = 720;

AudioIn mic;
Amplitude amp;
FFT fft;
int fftBands = 512;
float[] spectrum;
float rms = 0.0;

PShader mode0Shader;
PShader glowShader;
PShader bloom;

PGraphics layerFbo;   // acumulación / feedback (P3D)
PGraphics overlay2D;  // buffer 2D para overlays y algunos modos (P2D)
PGraphics overlay3D;  // buffer 3D para modos que necesitan rotación/3D sin acumular
PGraphics bloomFbo;   // adicional para efecto glow

int mode = 0; // 0..8
int prevMode = -1; // Clean layerFBO when the mode changes
PVector roomSize = new PVector(400,400,400);

// timing
float t = 0.0;
float dt = 1.0/60.0;

// parameters
float decayAlpha = 0.03; // alpha para fade
boolean useFFT = true;
boolean bloomOn = false;
// parámetros de ganancia que controla el menú
float rmsGain = 28.0;   // multiplicador para ajustar sensibilidad RMS (ajustable desde el menú)
float fftGain = 2.5;    // multiplicador global aplicado en fftNorm (ajustable desde el menú)

// limits
final int MAX_FFT_USED = 128;

// developer typing buffer (Lazuli)
String devBuffer = "";
boolean devMode = false;

void settings() {
  size(SCR_W, SCR_H, P3D);
}

void setup() {
  frameRate(60);
  colorMode(HSB, 360, 100, 100);
  surface.setTitle("CepheidVisualizer - Live Visuals");

  // audio init
  mic = new AudioIn(this, 0);
  mic.start();
  amp = new Amplitude(this);
  amp.input(mic);
  fft = new FFT(this, fftBands);
  fft.input(mic);
  spectrum = new float[fftBands];

  mode0Shader = null;
  try { mode0Shader = loadShader("mode0.frag"); } catch (Exception e) { println("mode0.frag not found in data/"); }
  try { glowShader = loadShader("glowFrag.glsl"); } catch (Exception e) { println("glowFrag.glsl not found in data/"); }
  try { bloom = loadShader("bloom.glsl"); } catch (Exception e) { println("bloom.glsl not found in data/"); }

  ensureBuffers();

  println("Ready. Controles: 0..8 cambiar modos, + / - ajustar decayAlpha, f toggles FFT, b toggles bloom, h abrir/ocultar menu");
  printHelp();
}

void draw() {
  ensureBuffers();

  t = millis() / 1000.0;
  updateAudio();

  // Si cambiaron el modo, limpiamos el layerFbo completamente una vez
  if (mode != prevMode) {
    layerFbo.beginDraw();
      layerFbo.clear();
      layerFbo.background(0);
    layerFbo.endDraw();
    prevMode = mode;
    println("Switched to mode " + mode + " — buffer cleared");
  }

  // render into layerFbo (P3D) con persistencia
  layerFbo.beginDraw();
    // fade global controlado por decayAlpha
    layerFbo.pushStyle();
      layerFbo.noStroke();
      layerFbo.colorMode(RGB,255);
      float alpha = constrain(decayAlpha, 0.001, 0.9);
      layerFbo.fill(0, (int)(alpha * 255.0));
      layerFbo.rect(0,0,layerFbo.width,layerFbo.height);
    layerFbo.popStyle();

    layerFbo.pushMatrix();
      layerFbo.translate(layerFbo.width*0.5, layerFbo.height*0.5, 0);

      // Llamada a los modos. Los archivos de modo están en modes/ y contienen las funciones drawModeX
      switch(mode) {
        case 8: drawMode0(layerFbo); break;
        case 0: drawMode1_cubes(layerFbo); break;
        case 1: drawMode2_helix(layerFbo); break;
        case 2: drawMode3_roseton(layerFbo); break;
        case 3: drawMode4_star(layerFbo); break;
        case 4: drawMode5_spiralRings(layerFbo); break;
        case 5: drawMode6_gridStars(layerFbo); break;
        case 6: drawMode7_shipArms(layerFbo); break;
        case 7: drawMode8_spiroflower(layerFbo); break;
        default: drawMode0(layerFbo); break;
      }
    layerFbo.popMatrix();

  layerFbo.endDraw();

  // composición final
  background(0);
  if (bloomOn && bloom != null) {
    try {
      bloom.set("resolution", float(width), float(height));
      layerFbo.filter(bloom);
    } catch (Exception e) { /* shader may not support these uniforms */ }
  }

  image(layerFbo, 0, 0, width, height);

  // HUD mínimo con logs
  pushStyle();
    fill(0, 0, 100, 90);
    textSize(12);
    textAlign(LEFT, TOP);
    String s = "Mode: " + mode + " | RMS: " + nf(rms,1,3) + " | decayAlpha: " + nf(decayAlpha,1,3) + " | FFT: " + (useFFT ? "ON" : "OFF");
    text(s, 8, 8);
  popStyle();

  // Menú UI (delegado al archivo MenuUI.pde)
  // drawMenuUI() está definida en MenuUI.pde; si no existe, esto no hace nada (Processing une archivos PDE)
  try {
    drawMenuUI();
  } catch (Exception e) {
    // si MenuUI.pde no está presente, evitamos crash
  }
}

// -----------------------------
// Eventos de teclado y mouse
// Integración plug-and-play con MenuUI.pde:
// si MenuUI define menuKeyTyped/menuMousePressed/... serán llamados aquí.
// -----------------------------

void keyPressed() {
  // si MenuUI tiene handler, delegamos la tecla primero para que el menú la capture (por ejemplo h o Ctrl+N)
  try {
    menuKeyTyped(); // MenuUI espera key y keyEvent a nivel global; si no existe lanza excepción atrapada abajo
  } catch (Exception e) {
    // no hay MenuUI o menuKeyTyped, seguimos normal
  }

  // modos por números
  if (key >= '0' && key <= '8') {
    mode = key - '0';
    println("Switched to mode " + mode);
    return;
  }

  // controles globales
  if (key == '+' || key == '=') { decayAlpha = max(0.001, decayAlpha - 0.005); println("decayAlpha -> " + decayAlpha); return; }
  if (key == '-' || key == '_') { decayAlpha = min(0.9, decayAlpha + 0.005); println("decayAlpha -> " + decayAlpha); return; }
  if (key == 'f' || key == 'F') { useFFT = !useFFT; println("FFT -> " + useFFT); return; }
  if (key == 'b' || key == 'B') { bloomOn = !bloomOn; println("Bloom -> " + bloomOn); return; }

  // legacy: imprimir ayuda con Shift+H (si quieres mantener)
  if (key == 'H') {
    printHelp();
    return;
  }

  // developer buffer (sigue funcionando)
  if ((int)key >= 32 && (int)key < 127) {
    devBuffer += key;
    if (devBuffer.length() > 20) devBuffer = devBuffer.substring(devBuffer.length()-20);
    if (devBuffer.toLowerCase().contains("lazuli")) {
      devMode = !devMode;
      println("Developer mode -> " + devMode);
      devBuffer = "";
    }
  }
}

// Delegación de eventos de mouse al MenuUI (plug-and-play)
void mousePressed() {
  try { menuMousePressed(); } catch (Exception e) { /* no menu */ }
}

void mouseDragged() {
  try { menuMouseDragged(); } catch (Exception e) { /* no menu */ }
}

void mouseReleased() {
  try { menuMouseReleased(); } catch (Exception e) { /* no menu */ }
}

void printHelp() {
  println("Controles:");
  println("  0..8 : switch modes");
  println("  + / - : adjust persistence (decayAlpha)");
  println("  f : toggle FFT");
  println("  b : toggle bloom");
  println("  h : abrir/ocultar menu (usa MenuUI.pde)");
}

// ---------------------------------------------------------------------------
// Audio utilities (global) - mantienen la compatibilidad con el original
// ---------------------------------------------------------------------------

void updateAudio() {
  if (amp != null) {
    // RMS con ganancia configurable y suavizado leve en la curva para mayor reactividad
    float raw = amp.analyze();
    // usamos rmsGain para controlar la sensibilidad; el exponente mantiene la curva suave
    rms = constrain(pow(raw * rmsGain, 0.8), 0, 1);
  } else {
    rms = 0;
  }
  if (useFFT && fft != null && spectrum != null) {
    fft.analyze(spectrum);
  } else if (spectrum != null) {
    for (int i = 0; i < spectrum.length; i++) spectrum[i] = 0;
  }
}

float fftNorm(int idx, float scale) {
  if (spectrum == null) return 0;
  idx = constrain(idx, 0, spectrum.length - 1);
  float v = spectrum[idx];
  // ganancia adicional para recuperar reactividad
  float nv = constrain(v * scale * 2.5, 0, 1);
  return nv;
}

// ---------------------------------------------------------------------------
// Buffer management
// ---------------------------------------------------------------------------

void ensureBuffers() {
  if (layerFbo == null || layerFbo.width != width || layerFbo.height != height) {
    println("Recreate buffers for size " + width + "x" + height);
    layerFbo = createGraphics(width, height, P3D);
    overlay2D = createGraphics(width, height, P2D);
    overlay3D = createGraphics(width, height, P3D);
    bloomFbo = createGraphics(width, height, P2D);

    layerFbo.beginDraw();
      layerFbo.clear();
      layerFbo.background(0);
    layerFbo.endDraw();

    overlay2D.beginDraw();
      overlay2D.clear();
    overlay2D.endDraw();

    overlay3D.beginDraw();
      overlay3D.clear();
      overlay3D.background(0,0);
    overlay3D.endDraw();

    bloomFbo.beginDraw();
      bloomFbo.clear();
    bloomFbo.endDraw();

    if (bloom != null) {
      try { bloom.set("resolution", float(width), float(height)); } catch (Exception e) { }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers comunes que el resto del sketch y los modos usan
// ---------------------------------------------------------------------------

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

// energy helper original
float shipEnergySmooth = 0;
float getShipEnergy() {
  float bandLow = fftNorm(2, 8.0);
  float raw = constrain(rms * 4.0, 0, 1);
  float combined = max(raw, bandLow);

  float smoothFactor = 0.08;
  shipEnergySmooth = lerp(shipEnergySmooth, combined, smoothFactor);
  return shipEnergySmooth;
}
