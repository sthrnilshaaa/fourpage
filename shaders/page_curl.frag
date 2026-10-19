// Play Books-style page turn: the page slides away under the finger while
// its free edge rolls up around a narrow cylinder. Only the front of the
// roll is seen (curved, compressed print); there is no folded-over flap.
//
// Along uDir (from the fold toward the free edge), d is the distance from
// the fold line on screen:
//   d <= 0        flat page, shifted by uShift      src = p + dir * uShift
//   0 < d < r     front of the roll                 u = r * asin(d / r)
//   d >= r        the page underneath (with a shadow cast by the roll)
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // painted area, logical px
uniform vec2 uOrigin;   // a point on the fold line
uniform vec2 uDir;      // unit vector from the fold toward the free edge
uniform float uRadius;  // roll radius
uniform float uShift;   // how far the flat part has slid (along -uDir)
uniform float uHasBack; // 1: draw uBack where the page is gone, 0: leave it clear

uniform sampler2D uFront; // the turning page
uniform sampler2D uBack;  // the page underneath

out vec4 fragColor;

bool inPage(vec2 p) {
  return p.x >= 0.0 && p.y >= 0.0 && p.x <= uSize.x && p.y <= uSize.y;
}

vec4 under(vec2 p, float shadow) {
  if (uHasBack > 0.5) {
    vec4 c = texture(uBack, p / uSize);
    return vec4(c.rgb * (1.0 - shadow), c.a);
  }
  return vec4(0.0, 0.0, 0.0, shadow);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float r = max(uRadius, 0.5);
  float d = dot(p - uOrigin, uDir);

  if (d <= 0.0) {
    vec2 src = p + uDir * uShift;
    if (inPage(src)) {
      vec4 c = texture(uFront, src / uSize);
      // A touch darker just before the roll starts.
      float s = 1.0 - 0.06 * (1.0 - smoothstep(0.0, r, -d));
      fragColor = vec4(c.rgb * s, c.a);
      return;
    }
    fragColor = under(p, 0.0);
    return;
  }

  if (d < r) {
    float a = asin(clamp(d / r, 0.0, 1.0));
    vec2 src = p + uDir * (uShift + r * a - d);
    if (inPage(src)) {
      vec4 c = texture(uFront, src / uSize);
      // Lit at the top of the roll, darker as it turns away.
      float t = d / r;
      float shade = 1.0 - 0.38 * t * t + 0.05 * (1.0 - t);
      fragColor = vec4(c.rgb * shade, c.a);
      return;
    }
  }

  // Page underneath, shadowed close to the roll.
  float shadow = 0.32 * (1.0 - smoothstep(0.0, r * 1.6, d - r));
  fragColor = under(p, shadow);
}
