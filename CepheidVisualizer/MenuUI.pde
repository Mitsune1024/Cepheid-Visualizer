/* MenuUI.pde
   Versión sin el botón "Clear buffer".
   Integración:
     - Pegar en la carpeta del sketch.
     - En draw() llamar drawMenuUI();
     - En mousePressed/Dragged/Released/keyTyped llamar:
         menuMousePressed();
         menuMouseDragged();
         menuMouseReleased();
         menuKeyTyped();
     - Para exponer parámetros de un modo: menuRegisterParam(...)
*/

// -------------------------
// Config visual y estado
// -------------------------
boolean menuVisible = true;
int menuX = 16, menuY = 24;
int menuW = 360, menuH = 680;
boolean draggingMenu = false;
int dragOffX = 0, dragOffY = 0;
boolean resizingMenu = false;
int resizeHandle = 12;

// autohide inicial (solo la primera vez)
int menuShowStart = -1;
int menuShowDurationMs = 4500;
boolean initialAutoHideDone = false;

// theme
color panelBg = color(12, 12, 14);
color borderBlue = color(40, 120, 240);
color buttonBg = panelBg;
color textColor = color(220, 220, 220);

// UI sizes
int uiTitleSize = 16;
int uiTextSize = 13;

// -------------------------
// Datos y estados del menu
// -------------------------
ArrayList<MenuParam> registeredParams = new ArrayList<MenuParam>();
ArrayList<Integer> customModes = new ArrayList<Integer>();
int nextCustomModeIndex = 9;

HashMap<Integer, Boolean> modeExpanded = new HashMap<Integer, Boolean>();

// scroll list
float modeListScroll = 0;
float modeListContentH = 0;
float modeListMaxScroll = 0;
int listItemH = 36;

// slider drag
boolean draggingSlider = false;
MenuParam activeParam = null;
float sliderGrabX = 0;

// presets file
String presetsFilename = "menu_presets.json";

// tooltip
String tooltipText = "";
int tooltipTimer = 0;

// -------------------------
// Param struct & API
// -------------------------
interface ParamAccessor {
  float get();
  void set(float v);
}

class MenuParam {
  int modeIndex;
  String id;
  String label;
  ParamAccessor accessor;
  float minV, maxV, defaultV;
  MenuParam(int modeIndex, String id, String label, ParamAccessor accessor, float minV, float maxV, float defaultV) {
    this.modeIndex = modeIndex;
    this.id = id;
    this.label = label;
    this.accessor = accessor;
    this.minV = minV; this.maxV = maxV; this.defaultV = defaultV;
  }
}

void menuRegisterParam(int modeIndex, String id, ParamAccessor accessor, float minV, float maxV, float defaultV) {
  for (MenuParam mp : registeredParams) {
    if (mp.modeIndex == modeIndex && mp.id.equals(id)) {
      mp.accessor = accessor;
      mp.minV = minV; mp.maxV = maxV; mp.defaultV = defaultV;
      return;
    }
  }
  registeredParams.add(new MenuParam(modeIndex, id, id, accessor, minV, maxV, defaultV));
}

ArrayList<MenuParam> menuParamsForMode(int modeIndex) {
  ArrayList<MenuParam> out = new ArrayList<MenuParam>();
  for (MenuParam mp : registeredParams) if (mp.modeIndex == modeIndex) out.add(mp);
  return out;
}

// -------------------------
// Coordenadas reusables
// -------------------------
int innerX, innerW;
int addBtnX, addBtnY, addBtnW, addBtnH;
int delBtnX, delBtnY, delBtnW, delBtnH;
int listX, listY, listW, listH;
int modeSettingsX, modeSettingsY, modeSettingsW, modeSettingsH;
int globalSettingsX, globalSettingsY, globalSettingsW, globalSettingsH;

// -------------------------
// Dibujado principal
// -------------------------
void drawMenuUI() {
  if (menuShowStart < 0) menuShowStart = millis();
  if (!initialAutoHideDone && menuVisible && millis() - menuShowStart > menuShowDurationMs) {
    menuVisible = false;
    initialAutoHideDone = true;
  }
  if (!menuVisible) return;

  // clamp menu inside screen
  menuX = constrain(menuX, 6, width - 80);
  menuY = constrain(menuY, 6, height - 80);

  // layout zones sizes (fixed and adaptive)
  innerX = menuX + 12;
  innerW = menuW - 24;

  // top header height
  int headerH = 44;
  // list area fixed height
  listX = innerX;
  listY = menuY + headerH;
  listW = innerW;
  listH = 260;

  // mode settings area under list
  modeSettingsX = innerX;
  modeSettingsY = listY + listH + 10;
  modeSettingsW = innerW;
  modeSettingsH = 140;

  // global settings area in bottom portion
  globalSettingsX = innerX;
  globalSettingsW = innerW;
  globalSettingsH = max(120, menuH - (headerH + listH + modeSettingsH + 60));
  globalSettingsY = modeSettingsY + modeSettingsH + 10;

  pushStyle();

  // panel
  noStroke();
  fill(panelBg);
  rect(menuX, menuY, menuW, menuH, 8);

  // border
  stroke(borderBlue);
  strokeWeight(2);
  noFill();
  rect(menuX, menuY, menuW, menuH, 8);

  // header title and close X
  noStroke();
  fill(textColor);
  textSize(uiTitleSize);
  textAlign(LEFT, TOP);
  text("Menu", menuX + 14, menuY + 10);
  textAlign(RIGHT, TOP);
  textSize(uiTextSize+2);
  text("x", menuX + menuW - 14, menuY + 10);

  // Mode manager title and buttons
  int y = menuY + 44;
  textAlign(LEFT, TOP);
  textSize(uiTextSize+1);
  fill(textColor);
  text("Mode manager", innerX, y - 28);

  // Add/Delete buttons with stored coordinates
  int btnW = (innerW - 10) / 2;
  int btnH = 28;
  addBtnX = innerX; addBtnY = y - 22; addBtnW = btnW; addBtnH = btnH;
  delBtnX = innerX + btnW + 10; delBtnY = y - 22; delBtnW = btnW; delBtnH = btnH;
  drawUIButton(addBtnX, addBtnY, addBtnW, addBtnH, "Add mode");
  drawUIButton(delBtnX, delBtnY, delBtnW, delBtnH, "Delete mode");

  // list background
  noStroke();
  fill(20, 20, 22, 140);
  rect(listX, listY, listW, listH, 6);

  // build displayed modes
  ArrayList<Integer> displayedModes = new ArrayList<Integer>();
  for (int i = 1; i <= 8; i++) displayedModes.add(i);
  displayedModes.add(0);
  for (int cm : customModes) displayedModes.add(cm);

  // content height & clamp scroll
  modeListContentH = displayedModes.size() * listItemH;
  modeListMaxScroll = max(0, modeListContentH - listH);
  modeListScroll = constrain(modeListScroll, 0, modeListMaxScroll);

  // draw visible items only
  int startIndex = max(0, int(modeListScroll / listItemH) - 1);
  int endIndex = min(displayedModes.size()-1, startIndex + int(listH / listItemH) + 2);

  for (int i = startIndex; i <= endIndex; i++) {
    int mIdx = displayedModes.get(i);
    float itemTop = listY + i * listItemH - modeListScroll;

    // highlight selected
    if (mIdx == mode) {
      fill(40, 120, 240, 60);
      rect(listX + 6, itemTop + 6, listW - 12, listItemH - 8, 6);
    }

    // label
    fill(textColor);
    textSize(uiTextSize);
    textAlign(LEFT, CENTER);
    String label;
    switch(mIdx) {
      case 0: label = "Mode0_shader"; break;
      case 1: label = "Mode1_cubes"; break;
      case 2: label = "Mode2_helix"; break;
      case 3: label = "Mode3_roseton"; break;
      case 4: label = "Mode4_star"; break;
      case 5: label = "Mode5_spiralRings"; break;
      case 6: label = "Mode6_gridStars"; break;
      case 7: label = "Mode7_shipArms"; break;
      case 8: label = "Mode8_spiroflower"; break;
      default: label = "Custom Mode " + mIdx; break;
    }
    text(label, listX + 12, itemTop + listItemH*0.5);

    // chevron area
    boolean expanded = modeExpanded.containsKey(mIdx) ? modeExpanded.get(mIdx) : false;
    textAlign(RIGHT, CENTER);
    text(expanded ? "v" : ">", listX + listW - 18, itemTop + listItemH*0.5);

    // expanded params drawn immediately beneath the item (if visible inside list)
    if (expanded) {
      ArrayList<MenuParam> params = menuParamsForMode(mIdx);
      int subY = int(itemTop + listItemH);
      int px = listX + 12;
      int pw = listW - 28;
      for (MenuParam mp : params) {
        if (subY + 44 >= listY && subY <= listY + listH) {
          fill(textColor);
          textAlign(LEFT, TOP);
          text(mp.label, px, subY + 4);
          drawMiniSlider(px, subY + 20, pw, mp);
        }
        subY += 48;
      }
    }
  }

  // scrollbar
  float sbX = listX + listW - 10;
  float sbY = listY + 8;
  float sbH = listH - 16;
  noFill();
  stroke(80);
  rect(sbX - 6, sbY - 4, 8, sbH + 8, 4);
  if (modeListMaxScroll > 0) {
    float thumbH = max(24, sbH * (listH / (modeListContentH + 0.001)));
    float thumbPos = map(modeListScroll, 0, modeListMaxScroll, sbY, sbY + sbH - thumbH);
    noStroke();
    fill(borderBlue);
    rect(sbX - 6, thumbPos - 2, 8, thumbH + 4, 4);
  }

  // Mode settings panel (below list)
  fill(18);
  rect(modeSettingsX, modeSettingsY, modeSettingsW, modeSettingsH, 6);
  fill(textColor);
  textSize(uiTextSize+1);
  textAlign(LEFT, TOP);
  text("Mode settings", modeSettingsX + 8, modeSettingsY + 8);

  // show selected mode params
  ArrayList<MenuParam> sel = menuParamsForMode(mode);
  int paramY = modeSettingsY + 30;
  if (sel.size() == 0) {
    fill(170);
    textSize(uiTextSize);
    text("No parameters registered for this mode.", modeSettingsX + 8, paramY);
  } else {
    for (MenuParam mp : sel) {
      fill(textColor);
      textSize(uiTextSize);
      text(mp.label, modeSettingsX + 8, paramY);
      drawMiniSlider(modeSettingsX + 8, paramY + 16, modeSettingsW - 28, mp);
      paramY += 44;
      if (paramY > modeSettingsY + modeSettingsH - 24) break; // avoid overflow
    }
  }

  // Global settings panel
  fill(18);
  rect(globalSettingsX, globalSettingsY, globalSettingsW, globalSettingsH, 6);
  fill(textColor);
  textSize(uiTextSize+1);
  textAlign(LEFT, TOP);
  text("Settings", globalSettingsX + 8, globalSettingsY + 8);

  // sliders inside global settings
  int sY = globalSettingsY + 30;
  textSize(uiTextSize);
  fill(textColor);
  text("RMS Gain", globalSettingsX + 8, sY);
  drawSimpleSlider(globalSettingsX + 8, sY + 16, globalSettingsW - 28, "rms", rmsGain, 1.0, 60.0);
  sY += 42;
  text("FFT Gain", globalSettingsX + 8, sY);
  drawSimpleSlider(globalSettingsX + 8, sY + 16, globalSettingsW - 28, "fft", fftGain, 0.5, 8.0);
  sY += 42;
  text("Decay alpha", globalSettingsX + 8, sY);
  drawSimpleSlider(globalSettingsX + 8, sY + 16, globalSettingsW - 28, "decay", decayAlpha, 0.001, 0.9);
  sY += 48;

  // footer line
  textSize(11);
  fill(140);
  textAlign(LEFT, BOTTOM);
  text("h: mostrar/ocultar menu · Ctrl+N: cambiar a modo N · click: seleccionar/expandir", innerX, menuY + menuH - 12);

  popStyle();

  // tooltip draw
  if (!tooltipText.equals("") && millis() - tooltipTimer < 2500) {
    pushStyle();
    fill(30, 30, 30, 220);
    stroke(borderBlue);
    strokeWeight(1);
    rect(mouseX + 12, mouseY + 12, textWidth(tooltipText) + 16, 26, 6);
    fill(240);
    textSize(12);
    textAlign(LEFT, CENTER);
    noStroke();
    text(tooltipText, mouseX + 20, mouseY + 25);
    popStyle();
  }
}

// -------------------------
// UI primitives
// -------------------------
void drawUIButton(int x, int y, int w, int h, String label) {
  pushStyle();
  stroke(borderBlue);
  strokeWeight(1.4);
  fill(buttonBg);
  rect(x, y, w, h, 6);
  fill(textColor);
  textSize(uiTextSize);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  popStyle();
}

void drawSimpleSlider(int x, int y, int w, String id, float value, float minV, float maxV) {
  pushStyle();
  stroke(80);
  fill(18);
  rect(x, y, w, 12, 6);
  float t = map(value, minV, maxV, 0, 1);
  noStroke();
  fill(borderBlue);
  rect(x, y, w * t, 12, 6);
  fill(textColor);
  ellipse(x + constrain(w * t, 6, w - 6), y + 6, 10, 10);
  popStyle();

  if (mousePressed && mouseButton == LEFT && mouseX >= x && mouseX <= x + w && mouseY >= y - 6 && mouseY <= y + 18) {
    draggingSlider = true;
    sliderGrabX = x;
    float px = constrain(mouseX, x, x + w);
    float nt = (px - x) / w;
    float nv = lerp(minV, maxV, nt);
    if (id.equals("decay")) decayAlpha = nv;
    else if (id.equals("rms")) rmsGain = nv;
    else if (id.equals("fft")) fftGain = nv;
  }
}

void drawMiniSlider(int x, int y, int w, MenuParam mp) {
  float value = mp.accessor != null ? mp.accessor.get() : mp.defaultV;
  pushStyle();
  stroke(70);
  fill(18);
  rect(x, y, w, 10, 6);
  float t = map(value, mp.minV, mp.maxV, 0, 1);
  noStroke();
  fill(borderBlue);
  rect(x, y, w * t, 10, 6);
  fill(textColor);
  ellipse(x + constrain(w * t, 6, w - 6), y + 5, 8, 8);
  fill(180);
  textSize(11);
  textAlign(RIGHT, CENTER);
  text(nf(value,1,3), x + w - 6, y + 5);
  popStyle();

  if (mousePressed && mouseButton == LEFT && mouseX >= x && mouseX <= x + w && mouseY >= y - 8 && mouseY <= y + 20) {
    draggingSlider = true;
    activeParam = mp;
    sliderGrabX = x;
    float px = constrain(mouseX, x, x + w);
    float nt = (px - x) / w;
    float nv = lerp(mp.minV, mp.maxV, nt);
    if (mp.accessor != null) mp.accessor.set(nv);
  }
}

// -------------------------
// Eventos
// -------------------------
void menuMousePressed() {
  if (!menuVisible) return;
  // close
  if (mouseX >= menuX + menuW - 30 && mouseX <= menuX + menuW - 6 && mouseY >= menuY + 6 && mouseY <= menuY + 26) {
    menuVisible = false;
    initialAutoHideDone = true;
    return;
  }
  // header drag
  if (mouseX >= menuX && mouseX <= menuX + menuW && mouseY >= menuY && mouseY <= menuY + 36) {
    draggingMenu = true;
    dragOffX = mouseX - menuX;
    dragOffY = mouseY - menuY;
    initialAutoHideDone = true;
    return;
  }
  // resize
  if (mouseX >= menuX + menuW - resizeHandle && mouseX <= menuX + menuW && mouseY >= menuY + menuH - resizeHandle && mouseY <= menuY + menuH) {
    resizingMenu = true;
    initialAutoHideDone = true;
    return;
  }
  // Add
  if (mouseX >= addBtnX && mouseX <= addBtnX + addBtnW && mouseY >= addBtnY && mouseY <= addBtnY + addBtnH) {
    selectInput("addModeFileSelected", "Choose a .pde or .java file to add as mode");
    initialAutoHideDone = true;
    return;
  }
  // Delete
  if (mouseX >= delBtnX && mouseX <= delBtnX + delBtnW && mouseY >= delBtnY && mouseY <= delBtnY + delBtnH) {
    if (customModes.size() > 0) {
      int removed = customModes.remove(customModes.size() - 1);
      println("MenuUI -> deleted custom mode " + removed);
    } else {
      println("MenuUI -> no custom modes to delete");
    }
    initialAutoHideDone = true;
    return;
  }
  // Click en lista
  if (mouseX >= listX && mouseX <= listX + listW && mouseY >= listY && mouseY <= listY + listH) {
    float localY = mouseY - listY + modeListScroll;
    int clickedIndex = int(localY / listItemH);
    ArrayList<Integer> displayedModes = new ArrayList<Integer>();
    for (int i = 1; i <= 8; i++) displayedModes.add(i);
    displayedModes.add(0);
    for (int cm : customModes) displayedModes.add(cm);
    if (clickedIndex >= 0 && clickedIndex < displayedModes.size()) {
      int mIdx = displayedModes.get(clickedIndex);
      if (mouseX > listX + listW - 36) {
        boolean cur = modeExpanded.containsKey(mIdx) ? modeExpanded.get(mIdx) : false;
        modeExpanded.put(mIdx, !cur);
        initialAutoHideDone = true;
        return;
      } else {
        mode = mIdx;
        if (layerFbo != null) {
          layerFbo.beginDraw();
          layerFbo.clear();
          layerFbo.background(0);
          layerFbo.endDraw();
        }
        println("MenuUI -> selected mode " + mIdx);
        initialAutoHideDone = true;
        return;
      }
    }
  }
}

void menuMouseDragged() {
  if (!menuVisible) return;
  if (draggingMenu) {
    menuX = mouseX - dragOffX;
    menuY = mouseY - dragOffY;
    menuX = constrain(menuX, 6, width - 60);
    menuY = constrain(menuY, 6, height - 60);
    return;
  }
  if (resizingMenu) {
    menuW = max(280, mouseX - menuX);
    menuH = max(220, mouseY - menuY);
    return;
  }
  // scroll with drag inside list
  if (mouseX >= listX && mouseX <= listX + listW && pmouseY >= listY && pmouseY <= listY + listH) {
    float dy = pmouseY - mouseY;
    modeListScroll = constrain(modeListScroll + dy, 0, modeListMaxScroll);
    return;
  }
  if (draggingSlider && activeParam != null) {
    float sx = menuX + 12;
    float sw = menuW - 36;
    float px = constrain(mouseX, sx, sx + sw);
    float t = (px - sx) / sw;
    float nv = lerp(activeParam.minV, activeParam.maxV, t);
    if (activeParam.accessor != null) activeParam.accessor.set(nv);
  }
}

void menuMouseReleased() {
  draggingMenu = false;
  resizingMenu = false;
  draggingSlider = false;
  activeParam = null;
}

void menuKeyTyped() {
  if (key == 'h' || key == 'H') {
    menuVisible = !menuVisible;
    initialAutoHideDone = true;
    return;
  }
  if ((key >= '0' && key <= '9') && (keyEvent != null && (keyEvent.isControlDown() || keyEvent.isMetaDown()))) {
    int n = key - '0';
    mode = n;
    if (layerFbo != null) {
      layerFbo.beginDraw();
      layerFbo.clear();
      layerFbo.background(0);
      layerFbo.endDraw();
    }
    initialAutoHideDone = true;
    println("MenuUI -> Ctrl+" + n + " -> mode " + mode);
  }
}

// -------------------------
// Utilities
// -------------------------
void tooltip(String s) {
  tooltipText = s;
  tooltipTimer = millis();
}

// -------------------------
// File-chooser: Add mode
// -------------------------
void addModeFileSelected(File selection) {
  if (selection == null) {
    println("MenuUI -> no file selected");
    return;
  }
  String path = selection.getAbsolutePath();
  String lower = path.toLowerCase();
  if (!(lower.endsWith(".pde") || lower.endsWith(".java"))) {
    println("MenuUI -> only .pde and .java files are accepted");
    return;
  }
  try {
    String[] lines = loadStrings(path);
    String modesDir = sketchPath("modes");
    File d = new File(modesDir);
    if (!d.exists()) d.mkdirs();
    String destName = selection.getName();
    String destPath = modesDir + File.separator + destName;
    File destFile = new File(destPath);
    if (destFile.exists()) {
      String stamp = Long.toString(System.currentTimeMillis()/1000);
      int dot = destName.lastIndexOf('.');
      String base = (dot > 0) ? destName.substring(0, dot) : destName;
      String ext = (dot > 0) ? destName.substring(dot) : "";
      String newName = base + "_copy" + stamp + ext;
      destPath = modesDir + File.separator + newName;
      println("MenuUI -> file exists, saving as " + newName);
    }
    saveStrings(destPath, lines);
    println("MenuUI -> file copied to " + destPath);
    tooltip("Archivo copiado. Reinicia Processing para cargar el nuevo modo.");
  } catch (Exception e) {
    println("MenuUI -> error copying file: " + e.getMessage());
  }
}

// -------------------------
// Presets
// -------------------------
void saveMenuPresets() {
  JSONObject root = new JSONObject();
  JSONObject global = new JSONObject();
  global.setFloat("decayAlpha", decayAlpha);
  global.setFloat("rmsGain", rmsGain);
  global.setFloat("fftGain", fftGain);
  global.setBoolean("useFFT", useFFT);
  global.setBoolean("bloomOn", bloomOn);
  root.setJSONObject("global", global);

  JSONObject modesObj = new JSONObject();
  for (MenuParam mp : registeredParams) {
    String mKey = "mode_" + mp.modeIndex;
    JSONObject mo = modesObj.hasKey(mKey) ? modesObj.getJSONObject(mKey) : new JSONObject();
    mo.setFloat(mp.id, mp.accessor.get());
    modesObj.setJSONObject(mKey, mo);
  }
  root.setJSONObject("modes", modesObj);
  saveJSONObject(root, presetsFilename);
  println("MenuUI -> presets saved");
}

void loadMenuPresets() {
  try {
    JSONObject root = loadJSONObject(presetsFilename);
    if (root == null) return;
    JSONObject global = root.getJSONObject("global");
    if (global != null) {
      if (global.hasKey("decayAlpha")) decayAlpha = global.getFloat("decayAlpha");
      if (global.hasKey("rmsGain")) rmsGain = global.getFloat("rmsGain");
      if (global.hasKey("fftGain")) fftGain = global.getFloat("fftGain");
      if (global.hasKey("useFFT")) useFFT = global.getBoolean("useFFT");
      if (global.hasKey("bloomOn")) bloomOn = global.getBoolean("bloomOn");
    }
    JSONObject modesObj = root.getJSONObject("modes");
    if (modesObj != null) {
      for (MenuParam mp : registeredParams) {
        String mKey = "mode_" + mp.modeIndex;
        if (modesObj.hasKey(mKey)) {
          JSONObject mo = modesObj.getJSONObject(mKey);
          if (mo.hasKey(mp.id)) {
            float v = mo.getFloat(mp.id);
            mp.accessor.set(constrain(v, mp.minV, mp.maxV));
          }
        }
      }
    }
    println("MenuUI -> presets loaded");
  } catch (Exception e) {
    println("MenuUI -> error loading presets: " + e.getMessage());
  }
}

// -------------------------
// FIN
// -------------------------
