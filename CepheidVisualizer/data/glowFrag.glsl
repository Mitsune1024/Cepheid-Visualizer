#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D texture;
uniform vec2 resolution;
uniform float blurAmount;

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  vec3 sum = vec3(0.0);
  float wsum = 0.0;
  
  // MÍNIMO blur - solo 3x3 samples para máxima performance
  for (float x = -1.0; x <= 1.0; x++) {
    for (float y = -1.0; y <= 1.0; y++) {
      float w = exp(-(x*x + y*y) / (4.0 * max(blurAmount, 0.5)));
      vec2 off = vec2(x,y)/resolution;
      sum += texture2D(texture, uv + off).rgb * w;
      wsum += w;
    }
  }
  
  vec3 col = sum/wsum;
  gl_FragColor = vec4(col, 1.0);
}