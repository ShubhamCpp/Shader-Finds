// Raymarch scene + SDF AO (hemisphere sampling) — self-contained snippet
// AO returns 1 = unoccluded, 0 = occluded
// Paste into Shadertoy "Image" shader.

#define MAX_STEPS   128
#define FAR_CLIP    20.0
#define HIT_EPS     0.0008
#define NOR_EPS     0.0005

// ------------------ Scene SDF ------------------

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdPlane(vec3 p, vec4 n) { return dot(p, n.xyz) + n.w; }

float sdTorusXY(vec3 p, vec2 t, vec2 centerXY)
{
    // Torus whose ring sits in XY plane (using p.xy), with "tube" along Z.
    // t.x = major radius, t.y = minor radius.
    vec2 q = vec2(length(p.xy - centerXY) - t.x, p.z);
    return length(q) - t.y;
}

float distFunc(vec3 p)
{
    // Plane at y = -2 (since dot(p, (0,1,0)) + 2 = 0 => y = -2)
    float dPlane  = sdPlane(p, vec4(0.0, 1.0, 0.0, 2.0));

    // Sphere centered near the torus
    vec3 sphereC  = vec3(1.0, -1.8, -1.0);
    float dSphere = sdSphere(p - sphereC, 0.5);

    // Torus centered around (0,-2) in XY
    float dTorus  = sdTorusXY(p, vec2(0.5, 0.2), vec2(0.0, -2.0));

    return min(dTorus, min(dSphere, dPlane));
}

// ------------------ Normals ------------------

vec3 getNormal(vec3 p)
{
    // Central differences
    vec2 e = vec2(NOR_EPS, 0.0);
    return normalize(vec3(
        distFunc(p + vec3(e.x, e.y, e.y)) - distFunc(p - vec3(e.x, e.y, e.y)),
        distFunc(p + vec3(e.y, e.x, e.y)) - distFunc(p - vec3(e.y, e.x, e.y)),
        distFunc(p + vec3(e.y, e.y, e.x)) - distFunc(p - vec3(e.y, e.y, e.x))
    ));
}

// ------------------ Raymarch ------------------

float rayMarch(vec3 ro, vec3 rd, out vec3 hitPos)
{
    float t = 0.0;
    for (int i = 0; i < MAX_STEPS; ++i)
    {
        vec3 p = ro + rd * t;
        float d = distFunc(p);
        if (d < HIT_EPS) { hitPos = p; return t; }
        t += d;
        if (t > FAR_CLIP) break;
    }
    hitPos = ro + rd * t;
    return -1.0;
}

// ------------------ Soft shadow (SDF) ------------------

float softShadowSDF(vec3 ro, vec3 rd)
{
    // A common SDF shadow heuristic
    float t = 0.02;
    float res = 1.0;
    const float k = 16.0;

    for (int i = 0; i < 48; ++i)
    {
        float h = distFunc(ro + rd * t);
        if (h < 0.0001) return 0.0;
        res = min(res, k * h / max(t, 1e-4));
        t += h;
        if (t > FAR_CLIP) break;
    }
    return clamp(res, 0.0, 1.0);
}

// ------------------ Hemisphere AO (SDF) ------------------

// Tiny hash for stable per-pixel randomness
float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Uniform random unit vector on sphere
vec3 randomUnitVector(vec2 seed)
{
    float u = hash12(seed);
    float v = hash12(seed + 17.17);
    float z = 1.0 - 2.0 * u;
    float a = 6.28318530718 * v;
    float r = sqrt(max(0.0, 1.0 - z*z));
    return vec3(r * cos(a), r * sin(a), z);
}

// Build tangent frame from normal
mat3 makeTBN(vec3 n)
{
    vec3 t = normalize(cross(n, abs(n.y) < 0.999 ? vec3(0,1,0) : vec3(1,0,0)));
    vec3 b = cross(n, t);
    return mat3(t, b, n);
}

float ambientOcclusionHemisphereSDF(vec3 p, vec3 n, vec2 fragCoord)
{
    const int   AO_SAMPLES  = 16;
    const float AO_RADIUS   = 0.30;
    const float AO_BIAS     = 0.02;
    const float AO_STRENGTH = 1.0;

    mat3 tbn = makeTBN(n);

    float occ = 0.0;

    for (int i = 0; i < AO_SAMPLES; ++i)
    {
        // Random direction
        vec3 dir = randomUnitVector(fragCoord + vec2(float(i) * 13.7, float(i) * 71.3));

        // Clamp to hemisphere (+Z in local frame)
        dir.z = abs(dir.z);

        // Optional: bias direction slightly toward the normal for nicer "contact" AO
        dir = normalize(mix(dir, vec3(0,0,1), 0.35));

        // To world
        vec3 wdir = normalize(tbn * dir);

        // Sample radius schedule (more near samples)
        float t = (float(i) + 0.5) / float(AO_SAMPLES);
        float r = AO_RADIUS * (0.15 + 0.85 * t * t);

        vec3 sp = p + n * AO_BIAS + wdir * r;
        float d = distFunc(sp);

        // Occlusion heuristic: if SDF distance is small compared to r => blocked nearby
        float a = clamp((r - d) / max(r, 1e-4), 0.0, 1.0);

        // Weight closer samples more
        float w = 1.0 - t;
        occ += a * w;
    }

    occ /= float(AO_SAMPLES);

    float ao = 1.0 - clamp(AO_STRENGTH * occ, 0.0, 1.0);
    return ao;
}

// ------------------ Camera helpers ------------------

mat3 makeCamera(vec3 ro, vec3 ta)
{
    vec3 f = normalize(ta - ro);
    vec3 r = normalize(cross(f, vec3(0,1,0)));
    vec3 u = cross(r, f);
    return mat3(r, u, f);
}

// ------------------ Main ------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    // Mouse orbit
    vec2 m = (iMouse.xy == vec2(0.0)) ? vec2(0.3, 0.3) : (iMouse.xy / iResolution.xy);
    float yaw = 6.2831853 * (m.x - 0.5);
    float pitch = (m.y - 0.5);

    vec3 camPos = vec3(3.5 * cos(yaw), -0.5 + 2.0 * pitch, 3.5 * sin(yaw));
    vec3 camTarget = vec3(0.0, -1.6, -1.0);
    mat3 cam = makeCamera(camPos, camTarget);

    vec3 rd = normalize(cam * vec3(p, 1.6));
    vec3 ro = camPos;

    vec3 hitPos;
    float tHit = rayMarch(ro, rd, hitPos);

    vec3 col = vec3(0.0);

    if (tHit > 0.0)
    {
        vec3 n = getNormal(hitPos);

        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        float ndl = max(dot(n, lightDir), 0.0);

        float shadow = softShadowSDF(hitPos + n * 0.001, lightDir);
        float ao = ambientOcclusionHemisphereSDF(hitPos, n, fragCoord);

        // Simple shading: ambient + diffuse
        vec3 ambient = vec3(0.12) * ao;
        vec3 diffuse = vec3(1.0) * ndl * shadow;

        col = ambient + diffuse;

        // Fog-ish
        col *= exp(-tHit * 0.08);
    }
    else
    {
        // Background
        col = vec3(0.02, 0.03, 0.05) + 0.25 * vec3(uv.y);
    }

    fragColor = vec4(col, 1.0);
}
