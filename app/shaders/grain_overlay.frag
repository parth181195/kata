#version 460 core
#include <flutter/runtime_effect.glsl>

// Grain overlay per docs/design/waku-grain.md: samples the Dart-generated
// correlated tile (GrainTemplate, seamless, unit-variance encoded around 0.5)
// with per-block random offsets — the AV1 template architecture — and emits
// noise centred on mid-gray. Drawn with BlendMode.overlay, so the surface
// beneath supplies the tonal coupling (neutral at the extremes, biting into
// the mids). Runs under a plain CustomPainter FragmentShader: works on both
// Impeller and Skia, every platform kata ships on.

uniform vec2 uSize;      // painted rect size, logical px
uniform float uDpr;      // device pixel ratio → grain lives in physical px
uniform float uStrength; // amplitude scale
uniform float uSeed;

uniform sampler2D uTemplate; // 128x128 grain tile

out vec4 fragColor;

const float kTemplate = 128.0;
const float kBlock = 64.0; // physical px per offset block
const float kStd = 0.22;   // encoding scale used by GrainTemplate.image

float hash(vec2 p, float seed) {
  vec3 q = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195) + seed * 0.6180339887);
  q += dot(q, q.yzx + 19.19);
  return fract((q.x + q.y) * q.z);
}

void main() {
  vec2 pxy = FlutterFragCoord().xy * uDpr;
  vec2 block = floor(pxy / kBlock);
  vec2 off = vec2(hash(block, uSeed), hash(block + 101.0, uSeed)) * kTemplate;
  vec2 tuv = fract((pxy - block * kBlock + off) / kTemplate);
  float g = (texture(uTemplate, tuv).r - 0.5) / kStd;
  float v = clamp(0.5 + g * uStrength * 0.5, 0.0, 1.0);
  fragColor = vec4(vec3(v), 1.0);
}
