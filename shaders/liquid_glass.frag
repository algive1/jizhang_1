#version 320 es

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec2 centered = uv - vec2(0.5);
  float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

  // Pull edge samples slightly toward the center to create a restrained lens
  // bend without making text behind the bar visibly wobble.
  float lens = 1.0 - 0.028 * (1.0 - smoothstep(0.0, 0.18, edge));
  vec2 sample_uv = clamp(vec2(0.5) + centered * lens, vec2(0.0), vec2(1.0));
  vec2 pixel = 1.25 / u_size;

  vec4 color = texture(u_texture, sample_uv) * 0.36;
  color += texture(u_texture, sample_uv + vec2(pixel.x, 0.0)) * 0.16;
  color += texture(u_texture, sample_uv - vec2(pixel.x, 0.0)) * 0.16;
  color += texture(u_texture, sample_uv + vec2(0.0, pixel.y)) * 0.16;
  color += texture(u_texture, sample_uv - vec2(0.0, pixel.y)) * 0.16;

  float rim = 1.0 - smoothstep(0.0, 0.16, edge);
  float top_specular = (1.0 - smoothstep(0.0, 0.20, uv.y)) * 0.08;
  color.rgb += vec3(0.94, 0.97, 1.0) * (rim * 0.045 + top_specular);
  frag_color = color;
}
