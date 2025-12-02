// Buffer A: GBuffer for SSAO
// Output:
//   RGB: view-space normal (approx), in [-1,1]
//   A  : depth01 in [0,1], where depth01 = t / FAR_CLIP (t = ray distance along view ray)
//
// Scene: simple SDF raymarch (floor + stacked primitives)

#define FAR_CLIP      10.0
#define NEAR_CLIP     0.10
#define MAX_STEPS     64
#define HIT_EPS       0.001
#define NORMAL_EPS    0.001

// ------------------- SDF Primitives -------------------

float sdPlane(vec3 p) {
    // y=0 plane
    return p.y;
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdCylinderY(vec3 p, vec2 h) {
    // Cylinder aligned with Y:
    // h.x = radius in XZ, h.y = half-height in Y
    vec2 d = abs(vec2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// ------------------- SDF Operators -------------------

float opUnion(float d1, float d2) {
    return min(d1, d2);
}

float opSubtract(float d1, float d2) {
    // subtract shape2 from shape1
    return max(-d2, d1);
}

// ------------------- Scene SDF -------------------

float sceneSDF(vec3 p) {
    float d = sdPlane(p);

    d = opUnion(d, sdCylinderY(p - vec3(0.0, 0.10, 0.0), vec2(0.65, 0.06)));
    d = opUnion(d, sdSphere   (p - vec3(0.0, 1.15, 0.0), 0.75));

    // Box minus slightly larger cylinder => ring-ish cut
    float ring = opSubtract(
        sdBox      (p - vec3(0.0, 0.06, 0.0), vec3(0.80, 0.06, 0.80)),
        sdCylinderY(p - vec3(0.0, 0.10, 0.0), vec2(0.66, 0.065))
    );
    d = opUnion(d, ring);

    // Hollow-ish sphere with a bite taken out
    float hollowSphere = opSubtract(
        sdSphere(p - vec3(0.0, 1.15, 0.0), 1.00),
        opUnion(
            sdSphere(p - vec3(0.0, 1.15, 0.0), 0.77),
            sdSphere(p - vec3(0.7, 1.60, 0.7), 0.70)
        )
    );
    d = opUnion(d, hollowSphere);

    return d;
}

// ------------------- Raymarch -------------------

float rayMarch(vec3 rayOrigin, vec3 rayDir) {
    float t = NEAR_CLIP;

    for (int i = 0; i < MAX_STEPS; ++i) {
        float d = sceneSDF(rayOrigin + rayDir * t);

        if (d < HIT_EPS) return t;    // hit
        t += d;

        if (t > FAR_CLIP) break;      // miss
    }

    return -1.0; // miss
}

// ------------------- Normals -------------------

vec3 estimateNormal(vec3 p) {
    // Central difference on SDF
    vec2 e = vec2(NORMAL_EPS, 0.0);
    vec3 n = vec3(
        sceneSDF(p + vec3(e.x, e.y, e.y)) - sceneSDF(p - vec3(e.x, e.y, e.y)),
        sceneSDF(p + vec3(e.y, e.x, e.y)) - sceneSDF(p - vec3(e.y, e.x, e.y)),
        sceneSDF(p + vec3(e.y, e.y, e.x)) - sceneSDF(p - vec3(e.y, e.y, e.x))
    );
    return normalize(n);
}

// ------------------- Camera -------------------

mat3 makeCamera(vec3 ro, vec3 ta, float roll) {
    vec3 forward = normalize(ta - ro);
    vec3 upHint  = vec3(sin(roll), cos(roll), 0.0);
    vec3 right   = normalize(cross(forward, upHint));
    vec3 up      = normalize(cross(right, forward));
    return mat3(right, up, forward);
}

// ------------------- GBuffer Pack -------------------

vec4 renderGBuffer(vec3 camPos, vec3 viewDirLocal, mat3 camToWorld) {
    vec3 rayDirWorld = camToWorld * viewDirLocal;

    float t = rayMarch(camPos, rayDirWorld);
    if (t <= 0.0) {
        // No hit: normal unused, depth01 set to 1
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    vec3 hitPosWorld = camPos + rayDirWorld * t;

    // Normal in world -> view space (inverse of orthonormal matrix is transpose)
    vec3 nWorld = estimateNormal(hitPosWorld);
    vec3 nView  = transpose(camToWorld) * nWorld;

    // Keep your earlier convention: flip z in view.
    nView.z *= -1.0;

    // Store depth as normalized ray distance.
    float depth01 = t / FAR_CLIP;

    return vec4(nView, depth01);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // NDC-ish coords, maintain aspect
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 m = iMouse.xy / iResolution.xy;

    // Simple orbit camera controlled by mouse
    float yaw   = 7.0 * m.x;
    float pitch = m.y;

    vec3 camPos    = vec3(3.0 * cos(yaw), 1.0 + 2.0 * pitch, 3.0 * sin(yaw));
    vec3 camTarget = vec3(0.0, 1.0, 0.0);

    mat3 camToWorld = makeCamera(camPos, camTarget, 0.0);

    // Local view dir (camera space). Larger z => narrower FOV.
    vec3 viewDirLocal = normalize(vec3(p, 1.5));

    fragColor = renderGBuffer(camPos, viewDirLocal, camToWorld);
}
