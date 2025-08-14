// GenerationsCombined.pde
// Sketch principal con 2 modos:
// modo 0 -> PBR + bloom + MiniSpheres
// modo 1 -> Agujero negro ligero + 6 rayos

import processing.sound.*;

int SCR_W = 640;
int SCR_H = 480;

AudioIn mic;
Amplitude amp;
FFT fft;
boolean useFFT = false;
int fftBands = 512;
float audioLevel = 0.0;

PShader pbr, bloom, blackholeShader;
PGraphics scene, glowLayer, rayLayer;

ArrayList<MiniSphere> miniSpheres;
PVector roomSize;
int maxLights = 8;

int mode = 0; // 0 = PBR, 1 = Black Hole

// Rayo (modo 1)
class Ray {
  PVector pos;
  PVector vel;
  float thickness;
  color col;
  boolean alive;
}
ArrayList<Ray> rays;
int NUM_RAYS = 6;

// BH params
PVector bhPos;
float bhRadius = 0.12; // fracción pantalla
float bhStrength = 0.4;
float haloIntensity = 0.35;
float rayBaseThickness = 3.0;

void settings() {
  size(SCR_W, SCR_H, P3D);
}

void setup() {
  frameRate(60);
  surface.setResizable(false);

  // color mode HSB para colores cómodos
  colorMode(HSB, 360, 100, 100);

  // Audio
  mic = new AudioIn(this, 0);
  mic.start();
  amp = new Amplitude(this);
  amp.input(mic);
  fft = new FFT(this, fftBands);
  fft.input(mic);

  // Buffers
  scene = createGraphics(width, height, P3D);
  glowLayer = createGraphics(width, height, P3D);
  rayLayer = createGraphics(width, height, P2D);

  // Shaders (archivos dentro de data/)
  pbr = loadShader("pbr.frag.glsl", "pbr.vert.glsl");
  bloom = loadShader("glowFrag.glsl");
  blackholeShader = loadShader("generations.frag");

  bloom.set("resolution", float(width), float(height));
  bloom.set("blurAmount", 8.0);

  // Modo 0 init
  roomSize = new PVector(400, 400, 400);
  miniSpheres = new ArrayList<MiniSphere>();

  // Initial PBR uniforms
  pbr.set("roomSize", roomSize.x, roomSize.y, roomSize.z);

  // Modo 1 init
  rays = new ArrayList<Ray>();
  for (int i = 0; i < NUM_RAYS; i++) spawnRay(i);
  bhPos = new PVector(width*0.5, height*0.5);

  println("Listo. Controles: 1=PBR  2=BlackHole  f=toggle FFT  +/- o flechas para bhRadius  mover mouse para bhPos");
}

void draw() {
  updateAudio();

  if (mode == 0) modo0_draw();
  else modo1_draw();

  // HUD en RGB para evitar confusión con HSB
  pushStyle();
  colorMode(RGB, 255);
  fill(255, 220);
  noStroke();
  textSize(12);
  textAlign(LEFT, TOP);
  text("Modo " + mode + "  |  audio " + nf(audioLevel,1,3) + "  |  FPS " + int(frameRate), 6, 6);
  popStyle();
}

void updateAudio() {
  audioLevel = amp.analyze();
  if (useFFT) fft.analyze();
}

// ---------------- MODO 0 ----------------
void modo0_draw() {
  // spawn spheres by audio (visual)
  if (audioLevel > 0.04 && frameCount % 6 == 0) miniSpheres.add(new MiniSphere());

  // update spheres
  for (int i = miniSpheres.size()-1; i >= 0; i--) {
    MiniSphere m = miniSpheres.get(i);
    m.update();
    if (m.isDead()) miniSpheres.remove(i);
  }

  // build lights
  float[] lightPos = new float[maxLights*3];
  float[] lightColor = new float[maxLights*3];
  int cnt = 0;

  // central light
  color c0 = color((frameCount * 0.5f) % 360, 80, 100);
  lightPos[cnt*3+0] = 0;
  lightPos[cnt*3+1] = 0;
  lightPos[cnt*3+2] = 0;
  // valores en rango 0..1; multiplicador modera intensidad
  lightColor[cnt*3+0] = red(c0)/255.0f * 1.8;
  lightColor[cnt*3+1] = green(c0)/255.0f * 1.8;
  lightColor[cnt*3+2] = blue(c0)/255.0f * 1.8;
  cnt++;

  for (int i = 0; i < miniSpheres.size() && cnt < maxLights; i++) {
    MiniSphere m = miniSpheres.get(i);
    lightPos[cnt*3+0] = m.pos.x;
    lightPos[cnt*3+1] = m.pos.y;
    lightPos[cnt*3+2] = m.pos.z;
    lightColor[cnt*3+0] = red(m.c)/255.0f * 0.9;
    lightColor[cnt*3+1] = green(m.c)/255.0f * 0.9;
    lightColor[cnt*3+2] = blue(m.c)/255.0f * 0.9;
    cnt++;
  }

  // send to shader
  pbr.set("numLights", cnt);
  pbr.set("lightPos", lightPos);
  pbr.set("lightColor", lightColor);
  pbr.set("albedo", 1.0f, 1.0f, 1.0f);
  pbr.set("metallic", 0.0f);
  pbr.set("roughness", 0.25f);
  pbr.set("ao", 1.0f);
  pbr.set("roomSize", roomSize.x, roomSize.y, roomSize.z);

  // main scene
  scene.beginDraw();
    scene.background(10); // algo más claro que 0 para comprobar luces
    scene.shader(pbr);
    // cámara fija
    scene.lights();
    setFixedCamera(scene);
    // draw room y objetos
    drawRoom(scene);
    drawCentralSphere(scene);
    for (MiniSphere m : miniSpheres) m.drawSceneSphere(scene);
    scene.resetShader();
  scene.endDraw();

  // glow pass (solo objetos brillantes)
  glowLayer.beginDraw();
    glowLayer.background(0);
    glowLayer.noStroke();
    setFixedCamera(glowLayer);
    glowLayer.shader(pbr);
    drawCentralSphere(glowLayer);
    for (MiniSphere m : miniSpheres) m.drawSceneSphere(glowLayer);
    glowLayer.resetShader();
  glowLayer.endDraw();

  // aplicar bloom con cuidado
  glowLayer.filter(bloom);

  // composite
  image(scene, 0, 0);
  blend(glowLayer, 0, 0, width, height, 0, 0, width, height, ADD);
}

void setFixedCamera(PGraphics pg) {
  pg.camera(0, 0, 600, 0, 0, 0, 0, 1, 0);
}

void drawRoom(PGraphics pg) {
  pg.pushMatrix();
    pg.noStroke();
    pg.fill(30, 10, 80); // HSB: color de la habitación algo claro
    float s = roomSize.x;
    pg.translate(0,0,0);
    pg.box(s);
  pg.popMatrix();
}

void drawCentralSphere(PGraphics pg) {
  pg.pushMatrix();
    pg.translate(0, 0, 0);
    pg.noStroke();
    color c = color((frameCount * 0.5f) % 360, 80, 100);
    pg.fill(c);
    pg.sphereDetail(32);
    // tamaño siempre visible, modulado levemente por audio
    pg.sphere(60 + audioLevel * 120);
  pg.popMatrix();
}

// ---------------- MODO 1 ----------------
void modo1_draw() {
  // background + rays dibujados a mano en rayLayer
  rayLayer.beginDraw();
    rayLayer.background(0);
    drawStars(rayLayer, 180);
    updateAndDrawRays(rayLayer);
  rayLayer.endDraw();

  // shader de pantalla
  blackholeShader.set("tex", rayLayer);
  blackholeShader.set("resolution", float(width), float(height));
  blackholeShader.set("bhPos", bhPos.x/width, bhPos.y/height);
  blackholeShader.set("bhRadius", bhRadius);
  // fuerza mapeada para no exagerar
  float strengthMapped = constrain(bhStrength + audioLevel * 1.5, 0.0, 2.0);
  blackholeShader.set("strength", strengthMapped);
  // halo color (HSB -> RGB conversion automática con color())
  float hue = (frameCount * 0.4f) % 360;
  color haloCol = color(hue, 80, 100);
  blackholeShader.set("haloColor", red(haloCol)/255.0, green(haloCol)/255.0, blue(haloCol)/255.0);
  blackholeShader.set("haloIntensity", haloIntensity + audioLevel*0.6);
  blackholeShader.set("time", millis()/1000.0);

  // render fullscreen quad con shader
  pushMatrix();
  resetMatrix();
  shader(blackholeShader);
  rect(0, 0, width, height);
  resetShader();
  popMatrix();
}

void drawStars(PGraphics pg, int n) {
  pg.pushMatrix();
    pg.noStroke();
    pg.fill(255);
    for (int i = 0; i < n; i++) {
      float x = random(width);
      float y = random(height);
      float s = random(1,3);
      pg.ellipse(x, y, s, s);
    }
  pg.popMatrix();
}

void updateAndDrawRays(PGraphics pg) {
  pg.pushStyle();
  pg.noStroke();
  // update
  for (int i = 0; i < rays.size(); i++) {
    Ray r = rays.get(i);
    float volFactor = 1.0 + audioLevel * 10.0;
    r.thickness = rayBaseThickness * volFactor * (0.6 + 0.8 * noise(i*0.2 + frameCount*0.01));
    float h = (map(i, 0, NUM_RAYS-1, 200, 320) + audioLevel * 100) % 360;
    r.col = color(h, 80, 100);

    r.pos.add(r.vel);

    pg.pushMatrix();
      pg.translate(r.pos.x, r.pos.y);
      pg.fill(r.col);
      pg.rectMode(CENTER);
      // rect largo para simular rayo
      pg.rect(0, 0, max(2, r.thickness), height * 0.035);
    pg.popMatrix();

    // inside BH?
    float dx = r.pos.x - bhPos.x;
    float dy = r.pos.y - bhPos.y;
    float distN = sqrt(dx*dx + dy*dy) / max(width, height);
    if (distN < bhRadius * 0.9) respawnRay(i);

    // offscreen
    if (r.pos.x < -100 || r.pos.x > width + 100 || r.pos.y < -100 || r.pos.y > height + 100) respawnRay(i);
  }
  pg.popStyle();
}

void spawnRay(int idx) {
  Ray r = new Ray();
  float lane = map(idx, 0, NUM_RAYS-1, 0.12, 0.88);
  r.pos = new PVector(random(-width*0.3, -10), lane * height + random(-6,6), 0);
  r.vel = new PVector(random(1.2, 3.5), random(-0.2, 0.2), 0);
  r.thickness = rayBaseThickness;
  float h = map(idx, 0, NUM_RAYS-1, 200, 320);
  r.col = color(h, 80, 100);
  r.alive = true;
  rays.add(r);
}

void respawnRay(int i) {
  Ray r = rays.get(i);
  r.pos.x = random(-width*0.25, -10);
  r.pos.y = map(i, 0, NUM_RAYS-1, height*0.12, height*0.88) + random(-6,6);
  r.vel.x = random(1.2, 3.5);
  r.vel.y = random(-0.3, 0.3);
  r.thickness = rayBaseThickness;
}

void keyPressed() {
  if (key == '1') mode = 0;
  if (key == '2') mode = 1;
  if (key == 'f') useFFT = !useFFT;
  if (key == CODED) {
    if (keyCode == UP) bhRadius = min(0.45, bhRadius + 0.01);
    if (keyCode == DOWN) bhRadius = max(0.02, bhRadius - 0.01);
  }
  if (key == '+') bhRadius = min(0.45, bhRadius + 0.01);
  if (key == '-') bhRadius = max(0.02, bhRadius - 0.01);
}

void mouseDragged() {
  bhPos.x = mouseX;
  bhPos.y = mouseY;
}

void mouseMoved() {
  bhPos.x = mouseX;
  bhPos.y = mouseY;
}
