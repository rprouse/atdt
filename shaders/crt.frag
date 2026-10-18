// CRT look over the reader: scanlines, bloom, a phosphor tint from the
// theme's foreground, a faint phosphor glow behind the text and a
// vignette. Applied with ImageFilter.shader, so the reader arrives as
// u_input in physical pixels.
//
// Every pixel keeps its own sample at its own coordinate: brightness and
// colour change, position never does, so no line of text can move
// (AGENTS.md rule 2).
#version 460 core

#include <flutter/runtime_effect.glsl>

// Set by the engine: the size of u_input, in physical pixels.
uniform vec2 u_size;
// 0 (off) to 1 (full effect).
uniform float u_intensity;
// The theme's foreground, 0-1 per channel.
uniform vec3 u_tint;
// Physical pixels per logical pixel; keeps the effect the same apparent
// size on every screen.
uniform float u_dpr;

uniform sampler2D u_input;

out vec4 frag_color;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
const float kPi = 3.14159265;

// The average of eight neighbours on a circle of radius r: axes and
// diagonals, so the glow is round instead of four offset copies.
vec3 ring(vec2 uv, vec2 r) {
  vec2 d = r * 0.7071;
  return (texture(u_input, uv + vec2(r.x, 0.0)).rgb +
          texture(u_input, uv - vec2(r.x, 0.0)).rgb +
          texture(u_input, uv + vec2(0.0, r.y)).rgb +
          texture(u_input, uv - vec2(0.0, r.y)).rgb +
          texture(u_input, uv + d).rgb + texture(u_input, uv - d).rgb +
          texture(u_input, uv + vec2(d.x, -d.y)).rgb +
          texture(u_input, uv + vec2(-d.x, d.y)).rgb) * 0.125;
}

void main() {
  float i = u_intensity;
  vec2 coord = FlutterFragCoord().xy;
  // No y flip. The ImageFilter.shader docs ask for one on OpenGL ES, but on
  // Impeller GLES with Flutter 3.47.7 the flip turned the reader upside
  // down (checked on the emulator; docs/decisions.md).
  vec2 uv = coord / u_size;
  vec4 source = texture(u_input, uv);

  // Bloom: two tight rings of neighbours, closer than a glyph stroke is
  // wide, so the glow hugs the text rather than echoing it.
  vec2 px = vec2(u_dpr) / u_size;
  vec3 halo = ring(uv, 0.75 * px) * 0.6 + ring(uv, 1.5 * px) * 0.4;
  vec3 colour = source.rgb + halo * 0.8 * i;

  // Phosphor: pull colour toward the tint at the pixel's brightness, and
  // let the screen itself glow faintly, as lit phosphor does.
  vec3 tint = u_tint / max(max(u_tint.r, u_tint.g), max(u_tint.b, 0.001));
  colour = mix(colour, tint * dot(colour, kLuma), 0.55 * i);
  colour += tint * 0.05 * i;

  // Scanlines: a dark gap between bright rows, every 2.5 logical pixels.
  float row = abs(sin(kPi * coord.y / (2.5 * u_dpr)));
  colour *= 1.0 - 0.75 * i * (1.0 - smoothstep(0.0, 0.6, row));

  // Vignette: the tube's edges fall off.
  vec2 centred = (uv - 0.5) * 1.4142;
  colour *= 1.0 - 0.45 * i * pow(dot(centred, centred), 1.5);

  frag_color = vec4(clamp(colour, 0.0, 1.0), source.a);
}
