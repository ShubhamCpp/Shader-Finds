// Buffer A: GBuffer for SSAO
// Output:
//   RGB: view-space normal (approx), in [-1,1]
//   A  : depth01 in [0,1], where depth01 = t / FAR_CLIP (t = ray distance along view ray)
//
// Scene: SDF raymarch (floor + complex-ish primitives + repetition)

#define FAR_CLIP      10.0
#define NEAR_CLIP     0.10
#define MAX_STEPS     72
#define HIT_EPS       0.001
#define NORMAL_EPS    0.001

// ------------------- SDF Primitives -------------------

float sdPlane(vec3 p) {
    return p.y; // y=0
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdRoundBox(vec3 p, vec3 b, float r) {
    // Rounded box: box with spherical corners
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdCylinderY(vec3 p, vec2 h) {
    // h.x = radius in XZ, h.y = half-height in Y
    vec2 d = abs(vec2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdTorus(vec3 p, vec2 t) {
    // t.x = major radius, t.y = minor radius
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// ------------------- SDF Operators -------------------

float opUnion(float d1, float d2) {
    return min(d1, d2);
}

float opSubtract(float d1, float d2) {
    return max(-d2, d1);
}

float opIntersect(float d1, float d2) {
    return max(d1, d2);
}

float opSmoothUnion(float d1, float d2, float k) {
    // k controls blend radius (bigger = smoother)
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Repeat space every cellSize units (centered)
vec3 opRepeat(vec3 p, vec3 cellSize) {
    return mod(p + 0.5 * cellSize, cellSize) - 0.5 * cellSize;
}

// Polar repetition around Y axis (returns rotated 2D coords in xz-plane)
vec2 opPolarRepeat(vec2 p, float n) {
    float ang = atan(p.y, p.x);
    float r   = length(p);
    float seg = 6.28318530718 / n;
    ang = mod(ang + 0.5 * seg, seg) - 0.5 * seg;
    return vec2(cos(ang), sin(ang)) * r;
}

// ------------------- Scene SDF -------------------

float sceneSDF(vec3 p) {
    float d = sdPlane(p);

    // --- Central pedestal (stacked shapes) ---
    float baseCyl = sdCylinderY(p - vec3(0.0, 0.18, 0.0), vec2(0.85, 0.18));
    float capBox  = sdRoundBox  (p - vec3(0.0, 0.42, 0.0), vec3(0.75, 0.10, 0.75), 0.05);
    float pedestal = opSmoothUnion(baseCyl, capBox, 0.08);
    d = opUnion(d, pedestal);

    // --- A torus “crown” floating above ---
    float torus = sdTorus(p - vec3(0.0, 1.15, 0.0), vec2(0.70, 0.10));
    d = opUnion(d, torus);

    // --- Original sphere-ish blob, with a subtractive bite ---
    float hollowSphere = opSubtract(
        sdSphere(p - vec3(0.0, 1.15, 0.0), 1.00),
        opUnion(
            sdSphere(p - vec3(0.0, 1.15, 0.0), 0.77),
            sdSphere(p - vec3(0.7, 1.60, 0.7), 0.70)
        )
    );
    d = opUnion(d, hollowSphere);

    // --- Ring of columns via polar repetition ---
    {
        vec3 q = p;
        // Work in XZ polar plane: repeat around origin, then shift radius outward
        vec2 xz = opPolarRepeat(q.xz, 12.0);
        q.xz = xz - vec2(2.2, 0.0); // move each repeated slice outward
        float col = sdCylinderY(q - vec3(0.0, 0.6, 0.0), vec2(0.12, 0.60));
        float colCap = sdSphere(q - vec3(0.0, 1.25, 0.0), 0.16);
        d = opUnion(d, opSmoothUnion(col, colCap, 0.04));
    }

    // --- Repeated small floor props (grid) ---
    {
        vec3 q = p;
        q.y -= 0.05; // slightly above floor
        // tile in XZ, keep y unchanged
        vec3 cell = vec3(1.0, 0.0, 1.0);
        vec3 r = q;
        r.xz = opRepeat(vec3(q.x, 0.0, q.z), cell).xz;

        float pebble = sdSphere(r - vec3(0.0, 0.10, 0.0), 0.10);
        float smallBox = sdRoundBox(r - vec3(0.35, 0.10, 0.35), vec3(0.10, 0.10, 0.10), 0.03);

        // Only keep props within a ring region (avoid clutter everywhere)
        float ringMask = abs(length(q.xz) - 3.0) - 0.7; // negative inside band
        float props = opUnion(pebble, smallBox);
        props = opIntersect(props, ringMask); // clamp to band
        d = opUnion(d, props);
    }

    // --- A cutout “arch” somewhere to create AO-friendly concavities ---
    {
        vec3 q = p - vec3(-1.8, 0.0, 1.2);
        float block = sdRoundBox(q - vec3(0.0, 0.55, 0.0), vec3(0.55, 0.55, 0.25), 0.05);
        float hole  = sdCylinderY(q - vec3(0.0, 0.55, 0.0), vec2(0.28, 0.55));
        float arch  = opSubtract(block, hole);
        d = opUnion(d, arch);
    }

    return d;
}

// ------------------- Raymarch -------------------

float rayMarch(vec3 rayOrigin, vec3 rayDir) {
    float t = NEAR_CLIP;

    for (int i = 0; i < MAX_STEPS; ++i) {
        float dist = sceneSDF(rayOrigin + rayDir * t);
        if (dist < HIT_EPS) return t; // hit
        t += dist;
        if (t > FAR_CLIP) break;      // miss
    }

    return -1.0;
}

// ------------------- Normals -------------------

vec3 estimateNormal(vec3 p) {
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
    if (t <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec3 hitPosWorld = camPos + rayDirWorld * t;

    vec3 nWorld = estimateNormal(hitPosWorld);
    vec3 nView  = transpose(camToWorld) * nWorld;
    nView.z *= -1.0;

    float depth01 = t / FAR_CLIP;
    return vec4(nView, depth01);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 m = iMouse.xy / iResolution.xy;
    float yaw   = 7.0 * m.x;
    float pitch = m.y;

    vec3 camPos    = vec3(3.4 * cos(yaw), 1.0 + 2.2 * pitch, 3.4 * sin(yaw));
    vec3 camTarget = vec3(0.0, 0.9, 0.0);

    mat3 camToWorld = makeCamera(camPos, camTarget, 0.0);

    vec3 viewDirLocal = normalize(vec3(p, 1.5));
    fragColor = renderGBuffer(camPos, viewDirLocal, camToWorld);
}
