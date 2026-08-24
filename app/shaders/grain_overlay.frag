#version 460 core
#include <flutter/runtime_effect.glsl>

// Grain overlay per docs/design/waku-grain.md: two taps of the Dart-generated
// seamless tile (GrainTemplate — band-passed, wrap-convolved) at incommensurate
// scales. Seamless tiling needs no block offsets (their un-blended edges showed
// as seams), and the second tap breaks the tile's repetition. Emits noise
// centred on mid-gray for BlendMode.overlay; the surface beneath supplies the
// tonal coupling.
//
// Coordinates are the SHEET's: uScale and uTile come from GrainGeometry, which
// grows the template with the export scale instead of shrinking the tooth, so
// the print keeps its tooth whatever resolution it is rendered at.

uniform float uScale;    // logical canvas px → template texels
uniform float uStrength; // amplitude scale
uniform float uSeed;
uniform float uTile;     // template size in texels

uniform sampler2D uTemplate; // seamless grain tile

out vec4 fragColor;

const float kStd = 0.22; // encoding scale used by GrainTemplate.bytes

void main() {
  vec2 pxy = FlutterFragCoord().xy * uScale;
  vec2 uv1 = fract(pxy / uTile);
  vec2 uv2 = fract(pxy * 0.5309 / uTile + vec2(fract(uSeed * 0.1131) + 0.193, fract(uSeed * 0.2571) + 0.437));
  float g1 = texture(uTemplate, uv1).r - 0.5;
  float g2 = texture(uTemplate, uv2).r - 0.5;
  float g = (g1 + 0.6 * g2) / (kStd * 1.1662); // variance renormalised
  float v = clamp(0.5 + g * uStrength * 0.5, 0.0, 1.0);
  fragColor = vec4(vec3(v), 1.0);
}
