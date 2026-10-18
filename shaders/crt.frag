// CRT look over the reader: scanlines, a slight bloom, and a phosphor tint
// from the theme's foreground. Applied with ImageFilter.shader, so the
// reader arrives as u_input in physical pixels.
//
// Every pixel keeps its own sample at its own coordinate: nothing is
// displaced or curved, so no line of text can move (AGENTS.md rule 2).
#version 460 core

#include <flutter/runtime_effect.glsl>

// Set by the engine: the size of u_input, in physical pixels.
uniform vec2 u_size;
// 0 (off) to 1 (full effect).
uniform float u_intensity;
// The theme's foreground, 0-1 per channel.
uniform vec3 u_tint;
// Physical pixels per logical pixel; keeps scanlines the same apparent size.
uniform float u_dpr;

uniform sampler2D u_input;

out vec4 frag_color;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
const float kPi = 3.14159265;

void main() {
  vec2 coord = FlutterFragCoord().xy;
  // No y flip. The ImageFilter.shader docs ask for one on OpenGL ES, but on
  // Impeller GLES with Flutter 3.47.7 the flip turned the reader upside
  // down (checked on the emulator; docs/decisions.md).
  vec2 uv = coord / u_size;
  vec4 source = texture(u_input, uv);

  // Bloom: a small cross of neighbours, added as glow around bright text.
  vec2 r = vec2(1.25 * u_dpr) / u_size;
  vec3 halo = (texture(u_input, uv + vec2(r.x, 0.0)).rgb +
               texture(u_input, uv - vec2(r.x, 0.0)).rgb +
               texture(u_input, uv + vec2(0.0, r.y)).rgb +
               texture(u_input, uv - vec2(0.0, r.y)).rgb) * 0.25;
  vec3 colour = source.rgb + halo * 0.35 * u_intensity;

  // Phosphor: pull colour toward the tint at the pixel's brightness.
  vec3 tint = u_tint / max(max(u_tint.r, u_tint.g), max(u_tint.b, 0.001));
  colour = mix(colour, tint * dot(colour, kLuma), 0.3 * u_intensity);

  // Scanlines: a soft dark band every 3 logical pixels.
  float period = 3.0 * u_dpr;
  float band = 0.5 + 0.5 * cos(2.0 * kPi * coord.y / period);
  colour *= 1.0 - 0.35 * u_intensity * (1.0 - band);

  frag_color = vec4(clamp(colour, 0.0, 1.0), source.a);
}
