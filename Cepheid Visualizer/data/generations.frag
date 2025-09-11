#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D tex;
uniform vec2 resolution;
uniform vec2 bhPos;
uniform float bhRadius;
uniform float strength;
uniform vec3 haloColor;
uniform float haloIntensity;
uniform float time;
uniform float audioLevel;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p,p+45.32);
  return fract(p.x * p.y);
}
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash21(i + vec2(0.0,0.0));
  float b = hash21(i + vec2(1.0,0.0));
  float c = hash21(i + vec2(0.0,1.0));
  float d = hash21(i + vec2(1.0,1.0));
  vec2 u = f*f*(3.0-2.0*f);
  return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}
float fbm(vec2 p) {
  float v=0.0; float a=0.5; float f=1.0;
  for (int i=0;i<5;i++){ v += a*noise(p*f); f*=2.0; a*=0.5; }
  return v;
}

mat2 rot(float a){ float c=cos(a); float s=sin(a); return mat2(c,-s,s,c); }

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  vec2 toBH = uv - bhPos;
  float dist = length(toBH);

  float influence = clamp(1.0 - smoothstep(bhRadius*0.05, bhRadius*1.5, dist), 0.0, 1.0);
  float audioBoost = 1.0 + audioLevel * 2.5;
  float fall = bhRadius / max(dist, 1e-6);
  float deform = strength * pow(fall, 0.95) * influence * 0.06 * audioBoost;

  vec2 dir = normalize(toBH + vec2(1e-4));
  vec2 perp = vec2(-dir.y, dir.x);

  float ringNoise = fbm((uv - bhPos) * (30.0 + audioLevel*120.0) + time*1.2);
  float ringAmp = smoothstep(bhRadius*0.9, bhRadius*1.4, dist) * (0.5 + audioLevel*1.5);
  float edgeOffset = (ringNoise - 0.5) * ringAmp * 0.04;

  vec2 displaced = uv + perp * (deform * (0.6 + edgeOffset)) - dir * deform * 0.2;

  float swirl = 0.6 * influence * strength * (0.4 + audioLevel*0.8);
  float angle = swirl * (1.0 - smoothstep(0.0, bhRadius*1.2, dist));
  vec2 centered = (uv - bhPos);
  centered = rot(angle * 0.7) * centered;
  displaced = bhPos + centered * (1.0 + deform * 0.02);

  vec3 sceneCol = texture2D(tex, displaced).rgb;

  float ringW = max(0.02 * bhRadius, 0.005);
  float ringField = exp(-pow((dist - (bhRadius * (1.0 + edgeOffset))) / ringW, 2.0));
  vec3 ringCol = haloColor * (0.6 + audioLevel*1.0) * ringField * (0.9 + 0.8*ringNoise);

  float inside = smoothstep(bhRadius * 0.9, 0.0, dist);
  float horizon = smoothstep(bhRadius * 1.15, bhRadius * 0.95, dist);
  vec3 glow = haloColor * (0.3 + haloIntensity*0.7) * horizon * (0.9 + 0.6*ringNoise);

  vec3 col = sceneCol * (1.0 - inside);
  col += ringCol * (1.0 - inside);
  col += glow * (1.0 - inside);

  vec2 pos = (gl_FragCoord.xy / resolution.xy) - 0.5;
  float vign = smoothstep(0.95, 0.40, length(pos));
  col *= vign;

  gl_FragColor = vec4(col, 1.0);
}
