#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform mat4 projectionMatrix;
uniform mat4 modelviewMatrix;

attribute vec4 position;
attribute vec3 normal;

varying vec3 vPos;
varying vec3 vNormal;

void main() {
  vec4 worldPos = modelviewMatrix * position;
  vPos    = worldPos.xyz;
  vNormal = normalize((modelviewMatrix * vec4(normal,0.0)).xyz);
  gl_Position = projectionMatrix * worldPos;
}
