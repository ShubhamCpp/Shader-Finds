// Water (flow/advected waves): refraction + Fresnel + fake specular
// Input: iChannel0 = background texture

#define PI 3.14159265359

// --- Knobs ---
const float DISTORTION    = 0.06;
const float NORMAL_EPS    = 0.01;

const int   FLOW_ITERS    = 2;     // advection steps
const float FLOW_STRENGTH = 0.10;

const float FRESNEL_POWER = 5.0;
const float SPEC_POWER    = 140.0;
const float SPEC_STRENGTH = 0.35;

// Simple smooth-ish “cheap flow field” (no noise texture required)
vec2 flowField(vec2 p, float t)
{
    // Rotational-ish vector field made from trig
    float a = sin(p.x * 1.7 + t * 1.1) + cos(p.y * 1.9 - t * 1.0);
    vec2 v  = vec2(cos(a), sin(a));
    // Add a second component so it doesn't look too uniform
    float b = sin(p.y * 1.3 + t * 0.8) - cos(p.x * 1.1 - t * 1.2);
    v += 0.5 * vec2(cos(b), sin(b));
    return normalize(v);
}

float heightField(vec2 p)
{
    float t = iTime;

    // Semi-Lagrangian style advection (cheap: iterate a couple times)
    vec2 q = p;
    for (int i = 0; i < FLOW_ITERS; ++i)
    {
        vec2 v = flowField(q, t + float(i) * 2.3);
        q += v * FLOW_STRENGTH;
    }

    // Interference of a few traveling waves evaluated at advected coord
    float h = 0.0;
    h += sin(dot(q, normalize(vec2( 1.0,  0.2))) * 14.0 + t * 1.7) * 0.12;
    h += sin(dot(q, normalize(vec2(-0.3,  1.0))) * 17.0 - t * 1.3) * 0.10;
    h += sin(dot(q, normalize(vec2( 0.8, -0.6))) * 12.0 + t * 2.1) * 0.08;

    // Subtle nonlinear shaping makes crests feel sharper
    h = tanh(h * 1.4) * 0.8;

    // Fade toward edges in p-space (optional)
    float r = length(p);
    float fade = smoothstep(1.3, 0.2, r);
    return h * fade;
}

vec3 heightNormal(vec2 p)
{
    vec2 ex = vec2(NORMAL_EPS, 0.0);
    vec2 ey = vec2(0.0, NORMAL_EPS);

    float hpx = heightField(p + ex);
    float hmx = heightField(p - ex);
    float hpz = heightField(p + ey);
    float hmz = heightField(p - ey);

    float dhdx = (hpx - hmx) * 0.5;
    float dhdz = (hpz - hmz) * 0.5;

    vec3 tx = vec3(1.0, dhdx, 0.0);
    vec3 tz = vec3(0.0, dhdz, 1.0);

    return normalize(cross(tz, tx));
}

float fresnelTerm(vec3 n, vec3 v, float F0, float power)
{
    float cosTheta = clamp(dot(n, v), 0.0, 1.0);
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, power);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Aspect-correct centered coords: circles stay circular
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec2 uv = fragCoord / iResolution.xy;

    vec3 n = heightNormal(p);

    // Distort UV (refraction)
    vec2 uvRefract = uv + n.xz * DISTORTION;
    uvRefract = clamp(uvRefract, 0.001, 0.999);

    vec3 refracted = texture(iChannel0, uvRefract).rgb;

    // Fake sky reflection (simple gradient)
    vec3 sky = vec3(0.06, 0.16, 0.26);
    sky += 0.15 * vec3(smoothstep(-0.3, 0.9, p.y));

    // View dir approx
    vec3 v = normalize(vec3(0.0, 0.45, 1.0));

    // Fresnel blend
    float F = fresnelTerm(n, v, 0.02, FRESNEL_POWER);

    // Fake specular (Blinn-Phong)
    vec3 l = normalize(vec3(-0.4, 0.85, 0.2));
    vec3 h = normalize(l + v);
    float spec = pow(max(dot(n, h), 0.0), SPEC_POWER) * SPEC_STRENGTH;

    vec3 col = mix(refracted, sky, F);
    col += spec;

    // Slight water tint
    col = mix(col, col * vec3(0.88, 0.96, 1.05), 0.18);

    fragColor = vec4(col, 1.0);
}
