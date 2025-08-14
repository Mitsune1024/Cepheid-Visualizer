#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

varying vec3 vPos;
varying vec3 vNormal;

uniform vec3  albedo;
uniform float metallic;
uniform float roughness;
uniform float ao;

uniform int   numLights;
uniform float lightPos[24];
uniform float lightColor[24];

uniform vec3 roomSize;

const float PI = 3.14159265359;

void main(){
  vec3 N = normalize(vNormal);
  vec3 V = normalize(-vPos);
  vec3 colorOut = vec3(0.0);

  // ambient base
  colorOut += 0.20 * albedo * ao;

  for(int i = 0; i < numLights; i++){
    vec3 Lpos = vec3(
      lightPos[i*3+0],
      lightPos[i*3+1],
      lightPos[i*3+2]
    );
    vec3 L = normalize(Lpos - vPos);
    vec3 radiance = vec3(
      lightColor[i*3+0],
      lightColor[i*3+1],
      lightColor[i*3+2]
    );

    vec3 H = normalize(V + L);
    float NdotH = max(dot(N,H), 0.0);
    float NDF   = pow(NdotH + 0.0001, (1.0 - roughness) * 128.0);
    float k     = roughness + 1.0;
    float G     = (NdotH * k) / (dot(V,H) + k + 0.0001);
    vec3 F0     = mix(vec3(0.04), albedo, metallic);
    float VdotH = max(dot(V,H), 0.0);
    vec3 F      = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);

    vec3 kS = F;
    vec3 kD = (1.0 - kS) * (1.0 - metallic);
    float NdotL = max(dot(N,L), 0.0);
    vec3 spec = (NDF * G * F) / (4.0 * max(dot(N,V),0.0001) * max(NdotL, 0.0001) + 0.0001);

    colorOut += (kD * albedo / PI + spec) * radiance * NdotL;
  }

  // Temporary: do not darken by room edges yet (helps debugging/visibility)
  // If you want edge darkening, replace next line with your smoothstep version.
  float fade = 1.0;

  colorOut *= fade;

  gl_FragColor = vec4(colorOut, 1.0);
}
