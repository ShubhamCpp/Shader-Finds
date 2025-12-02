// Water ripple refraction + Fresnel + fake specular + 2nd octave
//
// Expected inputs:
//   iChannel0: background texture (any image)
//
// Notes:
// - This is not physical water; it's a clean, teachable "water-ish" screen effect.
// - Fresnel blends between refracted scene and a fake sky reflection color.
// - Specular is a simple Blinn-Phong-ish highlight using the heightfield normal.

const float RIPPLE_FREQ1   = 30.0;
const float RIPPLE_SPEED1  = 10.0;

const float RIPPLE_FREQ2   = 85.0;   // higher = smaller ripples
const float RIPPLE_SPEED2  = 18.0;

const float AMP1           = 1.0;
const float AMP2           = 0.35;

const float DISTORTION     = 0.06;   // UV distortion strength
const float NORMAL_EPS     = 0.01;   // finite diff step

// Shading knobs
const float FRESNEL_POWER  = 5.0;    // higher = stronger edge reflection
const float SPEC_POWER     = 120.0;  // higher = tighter highlight
const float SPEC_STRENGTH  = 0.35;

float ripple(vec2 uv, vec2 centerOffset, float freq, float speed, float phase)
{
    float r = length(uv + centerOffset);
    return sin(r * freq - iTime * speed + phase);
}

float heightField(vec2 uv)
{
    float r = length(uv);

    // Large-scale ripples (3 sources)
    float h1 = ripple(uv, vec2( 0.10), RIPPLE_FREQ1, RIPPLE_SPEED1, 0.0);
    float h2 = ripple(uv, vec2( 0.40), RIPPLE_FREQ1, RIPPLE_SPEED1, 0.0);
    float h3 = ripple(uv, vec2(-0.80), RIPPLE_FREQ1, RIPPLE_SPEED1 * 0.5, 1.0);

    float base = (h1 + h2 + h3) * AMP1;

    // Second octave: smaller, faster detail ripples
    float d1 = ripple(uv, vec2( 0.23, -0.17), RIPPLE_FREQ2, RIPPLE_SPEED2, 0.7);
    float d2 = ripple(uv, vec2(-0.31,  0.29), RIPPLE_FREQ2, RIPPLE_SPEED2 * 0.9, 2.1);
    float detail = (d1 + d2) * AMP2;

    // Fade toward edges so it doesn't look like a tiled screen filter
    float fade = clamp(1.0 - r, 0.0, 1.0);
    fade *= fade;

    return (base + detail) * fade;
}

vec3 heightNormal(vec2 uv)
{
    vec2 ex = vec2(NORMAL_EPS, 0.0);
    vec2 ey = vec2(0.0, NORMAL_EPS);

    float hpx = heightField(uv + ex);
    float hmx = heightField(uv - ex);
    float hpz = heightField(uv + ey);
    float hmz = heightField(uv - ey);

    float dhdx = (hpx - hmx) * 0.5;
    float dhdz = (hpz - hmz) * 0.5;

    vec3 tx = vec3(1.0, dhdx, 0.0);
    vec3 tz = vec3(0.0, dhdz, 1.0);

    return normalize(cross(tz, tx));
}

float fresnelSchlick(float cosTheta, float F0, float power)
{
    // Not true Schlick (which is power=5), but a nice controllable variant.
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, power);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Aspect-correct centered coords (so ripples are circular)
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Normal from heightfield
    vec3 n = heightNormal(p);

    // View direction for a "screen water plane" (approx)
    // Pretend the camera is looking toward -Z; Y is "up", X is right.
    vec3 v = normalize(vec3(0.0, 0.4, 1.0)); // tweak to taste

    // Background UV
    vec2 uv = fragCoord / iResolution.xy;

    // Refract/distort UV using normal
    vec2 uvRefract = uv + n.xz * DISTORTION;
    uvRefract = clamp(uvRefract, 0.001, 0.999);

    vec3 refracted = texture(iChannel0, uvRefract).rgb;

    // Fake sky reflection color (replace with cubemap later if desired)
    vec3 sky = vec3(0.08, 0.18, 0.28);
    sky += 0.12 * vec3(smoothstep(-0.2, 0.8, p.y)); // subtle vertical gradient

    // Fresnel: more reflection at grazing angles
    float cosTheta = clamp(dot(n, v), 0.0, 1.0);
    float F = fresnelSchlick(cosTheta, 0.02, FRESNEL_POWER);

    // Fake specular highlight (single directional light)
    vec3 l = normalize(vec3(-0.4, 0.8, 0.2));
    vec3 h = normalize(l + v);
    float spec = pow(max(dot(n, h), 0.0), SPEC_POWER) * SPEC_STRENGTH;

    // Compose:
    // - Fresnel blends refracted scene with sky reflection
    // - Spec adds a highlight on top
    vec3 col = mix(refracted, sky, F);
    col += spec;

    // Optional: subtle water tint (helps sell "water")
    col = mix(col, col * vec3(0.85, 0.95, 1.05), 0.15);

    fragColor = vec4(col, 1.0);
}
