#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform vec2 resolution;
uniform vec2 center;
uniform float radius;
uniform float time;
uniform float audioLevel;
uniform float haloIntensity;
uniform int glowPass; // 0 = full, 1 = glow-only

// hash / noise
float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
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
  float v = 0.0; float amp = 0.5; float freq = 1.0;
  for (int i=0;i<5;i++) { v += amp * noise(p*freq); freq*=2.0; amp*=0.5; }
  return v;
}

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  vec2 toC = uv - center;
  float dist = length(toC);

  float disk = smoothstep(radius, radius*0.98, dist);
  disk = 1.0 - disk;

  float quiet = 1.0 - smoothstep(0.02, 0.15, audioLevel);
  float pattern = fbm((uv - center) * 80.0 + time*0.05) * 0.6 + 0.4;
  float edgeNoise = fbm((uv - center) * (40.0 + audioLevel*200.0) + time*1.2);
  float edgeAmp = smoothstep(radius*0.9, radius*0.5, dist) * audioLevel;

  float centerBright = mix(0.9 + 0.2*pattern, 0.6 + 0.5*pattern, audioLevel);
  float edge = edgeNoise * edgeAmp * 1.6;

  float ring = exp(-pow((dist - radius) / (radius * 0.08 + 1e-5), 2.0));
  float halo = ring * (0.2 + haloIntensity * (0.6 + audioLevel*1.4));

  vec3 baseCol = vec3(0.95, 0.95, 0.98);
  vec3 audioTint = vec3(0.6, 0.5, 1.0);
  vec3 col = baseCol * centerBright;
  col += audioTint * edge * 0.9;
  col += audioTint * halo * 0.6;

  if (glowPass == 1) {
    float glowOut = (halo * 1.2 + edge * 0.6) * step(dist, radius*1.6);
    gl_FragColor = vec4(col * glowOut, clamp(glowOut, 0.0, 1.0));
    return;
  }

  float vign = smoothstep(0.9, 0.45, length((gl_FragCoord.xy/resolution.xy)-0.5));
  col *= vign;

  float mask = smoothstep(radius*1.02, radius*0.98, dist);
  mask = 1.0 - mask;

  col *= mix(0.95, 1.0+0.08*pattern, 0.7);

  gl_FragColor = vec4(col * mask, 1.0);
}
