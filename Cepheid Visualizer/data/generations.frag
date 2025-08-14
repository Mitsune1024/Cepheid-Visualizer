#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D tex;
uniform vec2 resolution;
uniform vec2 bhPos;      // (0..1)
uniform float bhRadius;  // (0..0.5)
uniform float strength;  // deformación
uniform vec3 haloColor;
uniform float haloIntensity;
uniform float time;

const float PI = 3.14159265359;

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  vec2 toBH = uv - bhPos;
  float dist = length(toBH);

  // Influence falloff (0..1)
  float influence = smoothstep(bhRadius*1.6, bhRadius*0.05, dist);
  // prevent divide by zero
  float fall = bhRadius / max(dist, 0.0001);
  float deform = strength * pow(fall, 0.9) * influence * 0.05;

  vec2 dir = normalize(toBH + vec2(0.0001));
  vec2 perp = vec2(-dir.y, dir.x);

  float swirl = 0.45 * influence * strength * 0.5;
  float angle = swirl * (1.0 - smoothstep(0.0, bhRadius * 1.2, dist));

  vec2 displaced = uv + perp * deform - dir * deform * 0.18;

  float rotAmt = angle * 0.6;
  vec2 centered = (uv - bhPos);
  centered = rot(rotAmt) * centered;
  displaced = bhPos + centered * (1.0 + deform * 0.02);

  vec3 sceneCol = texture2D(tex, displaced).rgb;

  // ring
  float ring = exp(-pow((dist - bhRadius) * 200.0, 2.0));
  vec3 halo = haloColor * ring * haloIntensity * (0.5 + 0.5 * sin(time * 3.0));

  float inside = smoothstep(bhRadius * 0.9, 0.0, dist);
  float horizonGlow = smoothstep(bhRadius * 1.2, bhRadius * 0.95, dist);

  vec3 col = sceneCol * (1.0 - inside) + vec3(0.0) * inside;
  col += halo * (1.0 - inside) * 0.85;
  col += halo * horizonGlow * 0.35;

  // subtle vignette
  vec2 pos = (gl_FragCoord.xy / resolution.xy) - 0.5;
  float vign = smoothstep(0.8, 0.45, length(pos));
  col *= vign;

  gl_FragColor = vec4(col, 1.0);
}
