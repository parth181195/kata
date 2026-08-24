#version 460 core
#include <flutter/runtime_effect.glsl>

// Film grain as reconstruction, not overlay (after Denis Patrut's grain
// experiment): the image is re-expressed as thresholded grain dots — a dot
// "develops" where noise falls under the local brightness, so density follows
// luminance the way silver halide does. Three layers stand in for the
// emulsion's depth, upper layers thinner. uStrength mixes the reconstruction
// back over the original.

uniform vec2 uSize;       // set by the engine: input texture size
uniform float uGrainPx;   // grain clump size in physical px
uniform float uStrength;  // 0..1 mix toward the grain reconstruction
uniform float uSeed;

uniform sampler2D uInput; // set by the engine: the photo being filtered

out vec4 fragColor;

// interleaved gradient noise — cheap, with a usefully blue-ish spectrum
float ign(vec2 p) {
  return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 xy = FlutterFragCoord().xy;
  vec2 uv = xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 c = texture(uInput, uv);
  float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  // threshold in linear space — grain statistics are Poisson in exposure,
  // not in gamma-encoded values
  float lin = pow(lum, 2.2);

  vec2 cell = xy / max(uGrainPx, 0.75);
  // jitter the lattice: real particles vary in size and position — a straight
  // grid of dots is exactly the "square, uniform" tell of digital noise
  vec2 j = vec2(ign(floor(cell) + 11.0), ign(floor(cell) + 29.0)) - 0.5;
  vec2 g = floor(cell + j * 0.8);
  // three emulsion layers; the deeper the layer, the less light it sees
  float d0 = step(ign(g + uSeed), lin);
  float d1 = step(ign(g * 1.83 + 17.0 + uSeed), lin * 0.92);
  float d2 = step(ign(g * 2.71 + 47.0 + uSeed), lin * 0.84);
  float grain = (d0 + 0.6 * d1 + 0.35 * d2) / 1.95;

  // developed silver follows exposure: shadows are fixed clean, highlights
  // carry the grain — the reverse of digital noise
  float w = uStrength * smoothstep(0.0, 0.30, lin);
  float outLin = mix(lin, grain, w);
  float outLum = pow(max(outLin, 0.0), 1.0 / 2.2);
  vec3 scaled = c.rgb * (outLum / max(lum, 1e-3));
  // a whisper of per-channel offset: colour film's chroma speckle, no confetti
  float cn = (ign(g + 3.1 + uSeed) - 0.5) * uStrength * 0.06;
  fragColor = vec4(clamp(scaled + vec3(cn, -cn * 0.6, cn * 0.3), 0.0, 1.0), c.a);
}
