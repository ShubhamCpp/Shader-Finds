// Water (cellular/Voronoi ripples): refraction + Fresnel + fake specular
// Input: iChannel0 = background texture

// --- Knobs ---
const float DISTORTION    = 0.07;
const float NORMAL_EPS    = 0.01;

const float CELL_SCALE    = 7.0;   // more = more ripple sources
const float WAVE_FREQ     = 48.0;
const float WAVE_SPEED    = 2.2;

const float FRESNEL_POWER = 5.0;
const float SPEC_POWER    = 160.0;
const float SPEC_STRENGTH = 0.40;

// Hash helpers
float hash21(vec2 p)
{
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p)
{
    float n = hash21(p);
    return vec2(n, hash21(p + n + 19.19));
}

// Return (nearest distance, vector-to-nearest) in cell space
vec2 voronoiNearest(vec2 x)
{
    vec2 n = floor(x);
    vec2 f = fract(x);

    float bestD = 1e9;
    vec2  bestV = vec2(0.0);

    // Search neighbor cells
    for (int j = -1; j <= 1; ++j)
    for (int i = -1; i <= 1; ++i)
    {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g);     // random seed in [0,1)
        vec2 r = g + o - f;         // vector from sample to seed
        float d = dot(r, r);        // squared distance
        if (d < bestD) { bestD = d; bestV = r; }
    }

    return vec2(sqrt(bestD), bestV.x); // pack distance + something (distance is what we need)
}

float heightField(vec2 p)
{
    float t = iTime * WAVE_SPEED;

    // Scale to cell space
    vec2 x = p * CELL_SCALE;

    // Nearest-seed distance (Voronoi)
    vec2 n = floor(x);
    vec2 f = fract(x);

    float bestD = 1e9;

    for (int j = -1; j <= 1; ++j)
    for (int i = -1; i <= 1; ++i)
    {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g);
        vec2 r = g + o - f;
        float d = dot(r, r);
        bestD = min(bestD, d);
    }

    float dist = sqrt(bestD); // 0..~0.7 in a cell

    // Make a local ripple around each seed:
    // oscillation in distance + exponential decay
    float ring = sin(dist * WAVE_FREQ - t);
    float decay = exp(-6.0 * dist);

    float h = ring * decay;

    // Add a second octave for detail
    float ring2 = sin(dist * (WAVE_FREQ * 1.9) - t * 1.5);
    float decay2 = exp(-10.0 * dist);
    h += 0.35 * ring2 * decay2;

    // Edge fade in world p-space (optional)
    float r = length(p);
    float fade = smoothstep(1.3, 0.2, r);

    return h * 0.22 * fade;
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
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 uv = fragCoord / iResolution.xy;

    vec3 n = heightNormal(p);

    // Refract
    vec2 uvRefract = uv + n.xz * DISTORTION;
    uvRefract = clamp(uvRefract, 0.001, 0.999);

    vec3 refracted = texture(iChannel0, uvRefract).rgb;

    // Fake sky reflection
    vec3 sky = vec3(0.06, 0.15, 0.24);
    sky += 0.14 * vec3(smoothstep(-0.3, 0.9, p.y));

    vec3 v = normalize(vec3(0.0, 0.45, 1.0));

    float F = fresnelTerm(n, v, 0.02, FRESNEL_POWER);

    vec3 l = normalize(vec3(-0.4, 0.85, 0.2));
    vec3 h = normalize(l + v);
    float spec = pow(max(dot(n, h), 0.0), SPEC_POWER) * SPEC_STRENGTH;

    vec3 col = mix(refracted, sky, F);
    col += spec;

    col = mix(col, col * vec3(0.88, 0.97, 1.05), 0.18);

    fragColor = vec4(col, 1.0);
}
