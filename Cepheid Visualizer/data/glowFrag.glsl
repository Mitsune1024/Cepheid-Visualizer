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
  for (float x = -4.0; x <= 4.0; x++) {
    for (float y = -4.0; y <= 4.0; y++) {
      float w = exp(-(x*x + y*y)/(2.0*blurAmount));
      vec2 off = vec2(x,y)/resolution;
      sum += texture2D(texture, uv + off).rgb * w;
      wsum += w;
    }
  }
  vec3 col = sum/wsum;
  gl_FragColor = vec4(col,1.0);
}
