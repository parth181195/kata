#version 460 core
#include <flutter/runtime_effect.glsl>

// Grain overlay per docs/design/waku-grain.md: two taps of the Dart-generated
// seamless tile (GrainTemplate — band-passed, wrap-convolved) at incommensurate
// scales. Seamless tiling needs no block offsets (their un-blended edges showed
// as seams), and the second tap breaks the 128 px repetition. Emits noise
// centred on mid-gray for BlendMode.overlay; the surface beneath supplies the
// tonal coupling.

uniform float uDpr;      // logical px → GRAIN px: screen dpr, or the export ratio
uniform float uStrength; // amplitude scale
uniform float uSeed;

uniform sampler2D uTemplate; // 128x128 seamless grain tile

out vec4 fragColor;

const float kTemplate = 128.0;
const float kStd = 0.22; // encoding scale used by GrainTemplate.image

void main() {
  vec2 pxy = FlutterFragCoord().xy * uDpr;
  vec2 uv1 = fract(pxy / kTemplate);
  vec2 uv2 = fract(pxy * 0.5309 / kTemplate + vec2(fract(uSeed * 0.1131) + 0.193, fract(uSeed * 0.2571) + 0.437));
  float g1 = texture(uTemplate, uv1).r - 0.5;
  float g2 = texture(uTemplate, uv2).r - 0.5;
  float g = (g1 + 0.6 * g2) / (kStd * 1.1662); // variance renormalised
  float v = clamp(0.5 + g * uStrength * 0.5, 0.0, 1.0);
  fragColor = vec4(vec3(v), 1.0);
}
