// Minimal-ish Path Tracer (Shadertoy)
// - Analytic primitives w/ transforms
// - Sphere area light (solid-angle sampling)
// - Lambert + GGX specular (Schlick Fresnel)
// - Next Event Estimation (light sampling) + MIS
// - BSDF sampling continuation + "hit light" MIS
// - Optional thin-lens DOF
//
// Controls:
//   iMouse.x/y rotates light + camera (a bit)
//   iTime animates slight motion
//
// Notes:
//   ToDo: If textures/normal maps are needed later.

#define PI        3.141592653589793
#define TWO_PI    6.283185307179586

// ----------------------------- Quality knobs -----------------------------
#define SPP           4      // samples per pixel per frame (noise)
#define MAX_BOUNCES   4
#define EPS           1e-4
#define TMAX          1e4

// Bias knobs (optional)
#define CLAMP_LI      2.0    // clamp radiance per-sample (bias)

// Camera / DOF
#define USE_DOF       1
#define LENS_RADIUS   0.10
#define FOCUS_DIST    9.0

// ------------------------------------------------------------------------

// ----------------------------- RNG --------------------------------------
// hash-based RNG: good enough for shadertoy
float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash12(vec2 p)  { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

struct RNG { float s; };
float rnd(inout RNG r) { r.s = hash11(r.s); return r.s; }

// ----------------------------- Math utils --------------------------------
bool isNan(float x) { return x != x; }
bool isInf(float x) { return abs(x) > 1e20; }

vec3 safeNormalize(vec3 v) {
    float l2 = dot(v,v);
    if (l2 < 1e-20) return vec3(0.0,0.0,1.0);
    return v * inversesqrt(l2);
}

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3  x) { return clamp(x, vec3(0.0), vec3(1.0)); }

// Orthonormal basis from normal (Frisvad)
void makeBasis(in vec3 n, out vec3 t, out vec3 b) {
    if (n.z < -0.9999999) {
        t = vec3(0.0, -1.0, 0.0);
        b = vec3(-1.0, 0.0, 0.0);
        return;
    }
    float a = 1.0 / (1.0 + n.z);
    float bb = -n.x * n.y * a;
    t = vec3(1.0 - n.x*n.x*a, bb, -n.x);
    b = vec3(bb, 1.0 - n.y*n.y*a, -n.y);
}

vec3 localToWorld(vec3 l, vec3 n) {
    vec3 t,b; makeBasis(n,t,b);
    return l.x*t + l.y*b + l.z*n;
}

vec3 worldToLocal(vec3 w, vec3 n) {
    vec3 t,b; makeBasis(n,t,b);
    return vec3(dot(w,t), dot(w,b), dot(w,n));
}

// ----------------------------- Sampling ----------------------------------
vec3 sampleCosineHemisphere(float u1, float u2) {
    
    // cosine-weighted hemisphere around +Z
    float r = sqrt(u1);
    float phi = TWO_PI * u2;
    float x = r * cos(phi);
    float y = r * sin(phi);
    float z = sqrt(max(0.0, 1.0 - u1));
    return vec3(x,y,z);
}
float pdfCosineHemisphere(float cosTheta) { return cosTheta * (1.0 / PI); }

// GGX (isotropic) helpers
float ggx_D(float a, float NoH) {
    float a2 = a*a;
    float d = (NoH*NoH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d);
}
float ggx_G1(float a, float NoV) {
    
    // Smith masking G1 for GGX (isotropic)
    float a2 = a*a;
    float denom = NoV + sqrt(a2 + (1.0 - a2) * NoV * NoV);
    return (2.0 * NoV) / max(denom, 1e-6);
}
float ggx_G(float a, float NoV, float NoL) { return ggx_G1(a, NoV) * ggx_G1(a, NoL); }

vec3 fresnelSchlick(vec3 F0, float VoH) {
    float f = pow(1.0 - VoH, 5.0);
    return F0 + (vec3(1.0) - F0) * f;
}

// Sample GGX NDF (half-vector) around +Z in local space
vec3 sampleGGX_H(float a, float u1, float u2) {
    float a2 = a*a;
    float phi = TWO_PI * u2;
    float cosTheta = sqrt((1.0 - u1) / (1.0 + (a2 - 1.0) * u1));
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta*cosTheta));
    return vec3(cos(phi)*sinTheta, sin(phi)*sinTheta, cosTheta);
}
// pdf for half-vector when sampling GGX NDF: p(h) = D(h) * NoH
float pdfGGX_H(float a, float NoH) {
    return ggx_D(a, NoH) * NoH;
}

// ----------------------------- Scene -------------------------------------
// Materials
struct Material {
    vec3  baseColor;
    vec3  F0;
    float roughness;     // [0.02..1]
    float specWeight;    // lobe mixture probability
    vec3  emission;      // for lights (if any)
};

Material getMaterial(int id) {
    
    // Handy defaults
    Material m;
    m.baseColor = vec3(0.8);
    m.F0 = vec3(0.04);
    m.roughness = 0.3;
    m.specWeight = 0.2;
    m.emission = vec3(0.0);

    // Scene materials
    if (id == 0) { // floor/walls
        m.baseColor = vec3(0.75, 0.75, 0.78);
        m.F0 = vec3(0.04);
        m.roughness = 0.7;
        m.specWeight = 0.05;
    } else if (id == 1) { // glossy blue
        m.baseColor = vec3(0.2, 0.45, 1.0);
        m.F0 = vec3(0.04);
        m.roughness = 0.15;
        m.specWeight = 0.35;
    } else if (id == 2) { // metal-ish
        m.baseColor = vec3(0.0);           // diffuse dies for metals generally
        m.F0 = vec3(0.95, 0.92, 0.85);
        m.roughness = 0.08;
        m.specWeight = 1.0;
    } else if (id == 3) { // reddish matte
        m.baseColor = vec3(0.85, 0.35, 0.25);
        m.F0 = vec3(0.04);
        m.roughness = 0.6;
        m.specWeight = 0.08;
    } else if (id == 100) { // light material id
        m.baseColor = vec3(0.0);
        m.F0 = vec3(0.0);
        m.roughness = 1.0;
        m.specWeight = 0.0;
        m.emission = vec3(1.0, 1.0, 0.9) * 40.0; // intensity
    }
    return m;
}

// Object types
#define OBJ_SPHERE   1
#define OBJ_PLANE    2
#define OBJ_AABB     3
#define OBJ_CYL_Y    4

struct Object {
    int type;
    int mtl;
    mat4 T;
    mat4 invT;
    vec4 p0; // params
    vec4 p1; // params
};

// Fast inverse for rigid-ish transforms (rotation+translation)
mat4 inverseOrthonormal(mat4 m) {
    mat3 R = mat3(m);
    mat3 Rt = transpose(R);
    vec3 t = m[3].xyz;
    return mat4(
        vec4(Rt[0], 0.0),
        vec4(Rt[1], 0.0),
        vec4(Rt[2], 0.0),
        vec4(-(Rt * t), 1.0)
    );
}

mat4 makeCS(vec3 p, vec3 z, vec3 xHint) {
    vec3 f = safeNormalize(z);
    vec3 r = safeNormalize(cross(xHint, f));
    vec3 u = cross(f, r);
    return mat4(vec4(r,0), vec4(u,0), vec4(f,0), vec4(p,1));
}

Object makeSphere(mat4 T, float r, int mtl) {
    Object o;
    o.type = OBJ_SPHERE;
    o.mtl = mtl;
    o.T = T;
    o.invT = inverseOrthonormal(T);
    o.p0 = vec4(r, r*r, 0, 0);
    o.p1 = vec4(0);
    return o;
}
Object makePlaneZ0(mat4 T, vec2 minXY, vec2 maxXY, int mtl) {
    
    // Plane in local space is z=0, normal +Z, bounded in XY.
    Object o;
    o.type = OBJ_PLANE;
    o.mtl = mtl;
    o.T = T;
    o.invT = inverseOrthonormal(T);
    o.p0 = vec4(minXY, maxXY); // (minx, miny, maxx, maxy)
    o.p1 = vec4(0);
    return o;
}
Object makeAABB(mat4 T, vec3 bmin, vec3 bmax, int mtl) {
    Object o;
    o.type = OBJ_AABB;
    o.mtl = mtl;
    o.T = T;
    o.invT = inverseOrthonormal(T);
    o.p0 = vec4(bmin, 0.0);
    o.p1 = vec4(bmax, 0.0);
    return o;
}
Object makeCylinderY(mat4 T, float r, float yMin, float yMax, int mtl) {
    
    // Cylinder aligned with local Y; equation x^2+z^2=r^2, y in [yMin,yMax]
    Object o;
    o.type = OBJ_CYL_Y;
    o.mtl = mtl;
    o.T = T;
    o.invT = inverseOrthonormal(T);
    o.p0 = vec4(r, yMin, yMax, 0.0);
    o.p1 = vec4(0);
    return o;
}

// Scene objects (fixed count)
#define OBJ_COUNT 8

Object getObject(int i) {
    
    // Light + 7 surfaces
    float time = iTime;

    // Mouse factors
    float mx = (iMouse.x <= 0.0) ? 0.0 : (2.0 * iMouse.x / iResolution.x - 1.0);
    float my = (iMouse.y <= 0.0) ? 0.0 : (2.0 * iMouse.y / iResolution.y - 1.0);

    // --- 0) Sphere light ---
    if (i == 0) {
        float r = 1.0;
        vec3 lightPos = vec3(mx * 7.0, 5.0 + sin(time), -3.0 - my * 5.0);
        mat4 T = makeCS(lightPos, vec3(0.0, -1.0, 0.0), vec3(1.0,0.0,0.0));
        return makeSphere(T, r, 100);
    }

    // --- 1) Back wall (z=0 in local => transform it) ---
    if (i == 1) {
        mat4 T = mat4(
            vec4(1,0,0,0),
            vec4(0,1,0,0),
            vec4(0,0,1,0),
            vec4(0.0, 5.0, -10.0, 1.0)
        );
        return makePlaneZ0(T, vec2(-10.0,-2.0), vec2(10.0,4.0), 0);
    }

    // --- 2) Floor ---
    if (i == 2) {
        mat4 T = mat4(
            vec4(1,0,0,0),
            vec4(0,0,-1,0),
            vec4(0,-1,0,0),
            vec4(0.0, -1.0, -4.0, 1.0)
        );
        return makePlaneZ0(T, vec2(-10.0,-4.0), vec2(10.0,2.0), 0);
    }

    // --- 3) Big cylinder (for shape variety) ---
    if (i == 3) {
        mat4 T = mat4(
            vec4(0,1,0,0),
            vec4(0,0,1,0),
            vec4(1,0,0,0),
            vec4(0.0, 3.0, -6.0, 1.0)
        );
        return makeCylinderY(T, 4.0, -10.0, 10.0, 0);
    }

    // --- 4) Small glossy sphere ---
    if (i == 4) {
        mat4 T = mat4(
            vec4(1,0,0,0),
            vec4(0,1,0,0),
            vec4(0,0,1,0),
            vec4(1.5, -0.3, -2.0, 1.0)
        );
        return makeSphere(T, 0.7, 1);
    }

    // --- 5) Mid matte sphere ---
    if (i == 5) {
        mat4 T = mat4(
            vec4(1,0,0,0),
            vec4(0,1,0,0),
            vec4(0,0,1,0),
            vec4(0.0, 0.0, -4.5, 1.0)
        );
        return makeSphere(T, 1.0, 3);
    }

    // --- 6) Box ---
    if (i == 6) {
        mat4 T = makeCS(vec3(-1.5, -1.0, -3.0), vec3(0,1,0), vec3(0.2,0.0,-0.7));
        return makeAABB(T, vec3(-0.5,-0.5,0.0), vec3(0.5,0.5,2.5), 2);
    }

    // --- 7) Big sphere ---
    {
        mat4 T = mat4(
            vec4(1,0,0,0),
            vec4(0,1,0,0),
            vec4(0,0,1,0),
            vec4(3.5, 0.5, -4.2, 1.0)
        );
        return makeSphere(T, 1.5, 0);
    }
}

// ----------------------------- Rays & Hits --------------------------------
struct Ray { vec3 o; vec3 d; };

struct Hit {
    bool hit;
    float t;
    vec3 p;
    vec3 n;
    vec2 uv;
    int mtl;
};

// Transform a ray by a matrix (point vs vector)
Ray rayToLocal(Ray r, mat4 invT) {
    Ray rl;
    rl.o = (invT * vec4(r.o, 1.0)).xyz;
    rl.d = (invT * vec4(r.d, 0.0)).xyz;
    return rl;
}
vec3 normalToWorld(vec3 nLocal, mat4 T) {
    
    // For pure rotation matrices: normal transforms with R
    return safeNormalize((T * vec4(nLocal, 0.0)).xyz);
}

// Intersection helpers
bool intersectSphere(Ray r, float r2, out float t, out vec3 nLocal, out vec2 uv) {
    
    // Sphere at origin
    float b = dot(r.o, r.d);
    float c = dot(r.o, r.o) - r2;
    float disc = b*b - c;
    if (disc < 0.0) return false;
    float s = sqrt(disc);

    float t0 = -b - s;
    float t1 = -b + s;
    t = (t0 > EPS) ? t0 : ((t1 > EPS) ? t1 : -1.0);
    if (t < 0.0) return false;

    vec3 p = r.o + t*r.d;
    nLocal = safeNormalize(p);
    // simple spherical uv (not critical for now)
    float u = atan(p.z, p.x) / TWO_PI + 0.5;
    float v = asin(clamp(p.y / max(length(p), 1e-6), -1.0, 1.0)) / PI + 0.5;
    uv = vec2(u,v);
    return true;
}

bool intersectPlaneZ0_Bounds(Ray r, vec4 bounds, out float t, out vec3 nLocal, out vec2 uv) {
    
    // plane z = 0, normal +Z, bounded in x/y
    if (abs(r.d.z) < 1e-8) return false;
    t = (-r.o.z) / r.d.z;
    if (t < EPS) return false;

    vec3 p = r.o + t*r.d;
    float minx = bounds.x, miny = bounds.y, maxx = bounds.z, maxy = bounds.w;
    if (p.x < minx || p.x > maxx || p.y < miny || p.y > maxy) return false;

    nLocal = vec3(0.0, 0.0, 1.0);
    uv = (p.xy - vec2(minx, miny)) / (vec2(maxx-minx, maxy-miny));
    return true;
}

bool intersectAABB(Ray r, vec3 bmin, vec3 bmax, out float t, out vec3 nLocal, out vec2 uv) {
    vec3 invD = 1.0 / r.d;
    vec3 t0 = (bmin - r.o) * invD;
    vec3 t1 = (bmax - r.o) * invD;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);

    float tn = max(max(tmin.x, tmin.y), tmin.z);
    float tf = min(min(tmax.x, tmax.y), tmax.z);
    if (tf < max(tn, EPS)) return false;

    t = (tn > EPS) ? tn : tf;
    vec3 p = r.o + t*r.d;

    // Face normal by which slab is tight
    nLocal = vec3(0.0);
    vec3 c = 0.5*(bmin+bmax);
    vec3 e = 0.5*(bmax-bmin);
    vec3 d = p - c;
    vec3 a = abs(d) - e;

    if (a.x > a.y && a.x > a.z) nLocal = vec3(sign(d.x), 0, 0);
    else if (a.y > a.z)        nLocal = vec3(0, sign(d.y), 0);
    else                       nLocal = vec3(0, 0, sign(d.z));

    // quick uv for debugging (not used)
    uv = fract(p.xy);
    return true;
}

bool intersectCylinderY(Ray r, float rad, float yMin, float yMax, out float t, out vec3 nLocal, out vec2 uv) {
    
    // x^2+z^2=rad^2, y in [yMin,yMax]
    float a = r.d.x*r.d.x + r.d.z*r.d.z;
    float b = 2.0*(r.o.x*r.d.x + r.o.z*r.d.z);
    float c = r.o.x*r.o.x + r.o.z*r.o.z - rad*rad;

    float disc = b*b - 4.0*a*c;
    if (disc < 0.0 || abs(a) < 1e-10) return false;
    float s = sqrt(disc);

    float t0 = (-b - s) / (2.0*a);
    float t1 = (-b + s) / (2.0*a);

    float tt = (t0 > EPS) ? t0 : ((t1 > EPS) ? t1 : -1.0);
    if (tt < 0.0) return false;

    vec3 p = r.o + tt*r.d;
    if (p.y < yMin || p.y > yMax) {
        // try other root
        tt = (tt == t0) ? t1 : t0;
        if (tt < EPS) return false;
        p = r.o + tt*r.d;
        if (p.y < yMin || p.y > yMax) return false;
    }

    t = tt;
    nLocal = safeNormalize(vec3(p.x, 0.0, p.z));
    uv = vec2(atan(p.z, p.x)/TWO_PI + 0.5, (p.y - yMin)/(yMax-yMin));
    return true;
}

Hit intersectScene(Ray r) {
    Hit best;
    best.hit = false;
    best.t   = TMAX;

    for (int i=0; i<OBJ_COUNT; i++) {
        Object o = getObject(i);
        Ray rl = rayToLocal(r, o.invT);

        float t; vec3 nL; vec2 uv;
        bool ok = false;

        if (o.type == OBJ_SPHERE) {
            ok = intersectSphere(rl, o.p0.y, t, nL, uv);
        } else if (o.type == OBJ_PLANE) {
            ok = intersectPlaneZ0_Bounds(rl, o.p0, t, nL, uv);
        } else if (o.type == OBJ_AABB) {
            ok = intersectAABB(rl, o.p0.xyz, o.p1.xyz, t, nL, uv);
        } else if (o.type == OBJ_CYL_Y) {
            ok = intersectCylinderY(rl, o.p0.x, o.p0.y, o.p0.z, t, nL, uv);
        }

        if (ok && t < best.t) {
            best.hit = true;
            best.t = t;
            best.mtl = o.mtl;
            best.uv = uv;
            best.p = r.o + r.d * t;
            best.n = normalToWorld(nL, o.T);
        }
    }

    return best;
}

// ----------------------------- Light sampling (sphere) ---------------------
struct LightSample {
    vec3 wi;     // direction to light
    float dist;  // distance to first intersection on light (along wi)
    float pdfW;  // solid angle pdf at shading point
    vec3 Le;     // emitted radiance
};

bool isLightId(int mtl) { return mtl >= 100; }

// For our scene, light is object 0 which is a sphere
Object getLightObject() { return getObject(0); }
Material getLightMaterial() { return getMaterial(100); }

LightSample sampleSphereLight(vec3 x, inout RNG rng) {
    Object lightObj = getLightObject();
    Material lightM = getLightMaterial();

    // sphere center in world
    vec3 c = (lightObj.T * vec4(0,0,0,1)).xyz;
    float r = lightObj.p0.x;
    float r2 = lightObj.p0.y;

    vec3 toC = c - x;
    float dc2 = dot(toC,toC);
    float dc  = sqrt(dc2);

    LightSample ls;
    ls.Le = lightM.emission;
    ls.wi = vec3(0);
    ls.dist = 0.0;
    ls.pdfW = 0.0;

    // If inside sphere, fallback to uniform sphere (rare)
    if (dc <= r + 1e-6) {
        // uniform direction on sphere
        float u1 = rnd(rng), u2 = rnd(rng);
        float z = 1.0 - 2.0*u1;
        float a = TWO_PI*u2;
        float s = sqrt(max(0.0, 1.0 - z*z));
        ls.wi = vec3(cos(a)*s, sin(a)*s, z);
        ls.pdfW = 1.0 / (4.0 * PI);
        ls.dist = 0.0;
        return ls;
    }

    // Solid-angle sampling toward sphere (uniform over visible cone)
    float sin2Max = clamp(r2 / dc2, 0.0, 1.0);
    float cosMax = sqrt(1.0 - sin2Max);

    float u1 = rnd(rng);
    float u2 = rnd(rng);

    float cosTheta = mix(cosMax, 1.0, u1);
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta*cosTheta));
    float phi = TWO_PI * u2;

    vec3 w = toC / dc;
    vec3 t,b; makeBasis(w,t,b);
    ls.wi = safeNormalize(t*cos(phi)*sinTheta + b*sin(phi)*sinTheta + w*cosTheta);

    // pdf over solid angle of cone
    float solidAngle = TWO_PI * (1.0 - cosMax);
    ls.pdfW = 1.0 / max(solidAngle, 1e-9);

    // Distance to intersection with sphere along ls.wi:
    // solve |x + t*wi - c|^2 = r^2
    vec3 oc = x - c;
    float B = dot(ls.wi, oc);
    float C = dot(oc, oc) - r2;
    float disc = B*B - C;
    if (disc > 0.0) {
        float tHit = -B - sqrt(disc);
        ls.dist = max(tHit, 0.0);
    } else {
        ls.dist = 0.0;
    }

    return ls;
}

float pdfSphereLightW(vec3 x, vec3 wi) {
    
    // pdf of the same solid-angle sampling scheme for a given direction wi from x
    Object lightObj = getLightObject();
    vec3 c = (lightObj.T * vec4(0,0,0,1)).xyz;
    float r2 = lightObj.p0.y;

    vec3 toC = c - x;
    float dc2 = dot(toC,toC);
    if (dc2 < 1e-9) return 0.0;

    float sin2Max = clamp(r2 / dc2, 0.0, 1.0);
    float cosMax = sqrt(1.0 - sin2Max);
    float solidAngle = TWO_PI * (1.0 - cosMax);

    // only valid if wi points within the cone
    float cosTheta = dot(safeNormalize(toC), safeNormalize(wi));
    if (cosTheta < cosMax) return 0.0;

    return 1.0 / max(solidAngle, 1e-9);
}

// Visibility test to light along direction wi (shadow ray)
bool visibleToLight(vec3 x, vec3 wi, float maxT) {
    Ray sh; sh.o = x; sh.d = wi;
    Hit h = intersectScene(sh);
    if (!h.hit) return false;
    if (!isLightId(h.mtl)) return false;
    return (h.t <= maxT + 1e-3);
}

// ----------------------------- BSDF (Lambert + GGX) -----------------------
struct BSDFSample {
    vec3 wo;
    float pdfW;
    vec3 f;
    bool isDelta;   // we don't have delta here (GGX is not delta), keep for future
};

vec3 bsdfEval(Material m, vec3 n, vec3 wi, vec3 wo, out float pdfW) {
    // wi = incoming to surface (toward camera), wo = outgoing (toward next)
    float NoV = max(0.0, dot(n, wi));
    float NoL = max(0.0, dot(n, wo));
    if (NoV <= 0.0 || NoL <= 0.0) { pdfW = 0.0; return vec3(0.0); }

    float a = max(0.02, m.roughness);
    a = a*a; // perceptual -> alpha^2 style
    vec3 h = safeNormalize(wi + wo);
    float NoH = max(0.0, dot(n, h));
    float VoH = max(0.0, dot(wi, h));

    // Spec
    float D = ggx_D(a, NoH);
    float G = ggx_G(a, NoV, NoL);
    vec3  F = fresnelSchlick(m.F0, VoH);
    vec3  spec = (D * G) * F / max(4.0 * NoV * NoL, 1e-6);

    // Diffuse (simple Lambert, optionally energy-reduced by (1-Favg) is a later upgrade)
    vec3 diff = m.baseColor * (1.0 / PI);

    // Mixture eval (NOT physically perfect, but consistent with sampling below)
    vec3 f = mix(diff, spec, m.specWeight);

    // PDF (mixture)
    // Diff pdf: cosine
    float pdfDiff = pdfCosineHemisphere(NoL);

    // Spec pdf: sample half-vector with GGX NDF -> pdf(wo) = pdf(h)/(4*VoH)
    float pdfH = pdfGGX_H(a, NoH);
    float pdfSpec = pdfH / max(4.0 * VoH, 1e-6);

    pdfW = mix(pdfDiff, pdfSpec, m.specWeight);
    return f;
}

BSDFSample bsdfSample(Material m, vec3 n, vec3 wi, inout RNG rng) {
    BSDFSample s;
    s.wo = vec3(0);
    s.pdfW = 0.0;
    s.f = vec3(0);
    s.isDelta = false;

    float u = rnd(rng);
    float a = max(0.02, m.roughness);
    a = a*a;

    vec3 wiL = worldToLocal(wi, n);

    if (u < m.specWeight) {
        // --- Spec: sample GGX half vector in local space (+Z hemisphere) ---
        float u1 = rnd(rng);
        float u2 = rnd(rng);

        vec3 hL = sampleGGX_H(a, u1, u2);
        if (hL.z <= 0.0) hL.z = abs(hL.z);

        // reflect wi about h
        vec3 woL = reflect(-wiL, hL);
        if (woL.z <= 0.0) return s; // below hemisphere => invalid

        s.wo = localToWorld(woL, n);

        float pdfW;
        s.f = bsdfEval(m, n, wi, s.wo, pdfW);
        s.pdfW = pdfW;
        return s;
    } else {
        // --- Diffuse: cosine hemisphere ---
        float u1 = rnd(rng);
        float u2 = rnd(rng);

        vec3 woL = sampleCosineHemisphere(u1, u2);
        s.wo = localToWorld(woL, n);

        float pdfW;
        s.f = bsdfEval(m, n, wi, s.wo, pdfW);
        s.pdfW = pdfW;
        return s;
    }
}

// MIS power heuristic (beta=2)
float misWeight(float a, float b) {
    float a2 = a*a;
    float b2 = b*b;
    return a2 / max(a2 + b2, 1e-20);
}

// ----------------------------- Camera -------------------------------------
struct Camera {
    vec3 pos;
    vec3 fwd;
    vec3 right;
    vec3 up;
    float fovY;
};

Camera makeCamera(vec3 pos, vec3 target, vec3 upHint, float fovY) {
    Camera c;
    c.pos = pos;
    c.fwd = safeNormalize(target - pos);
    c.right = safeNormalize(cross(c.fwd, upHint));
    c.up = cross(c.right, c.fwd);
    c.fovY = fovY;
    return c;
}

Ray generateRay(Camera cam, vec2 fragCoord, vec2 jitter, inout RNG rng, out float rayPdf) {
    vec2 uv = (fragCoord + jitter) / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float tanHalf = tan(0.5 * cam.fovY);
    vec3 dir = safeNormalize(cam.fwd + p.x * tanHalf * cam.right + p.y * tanHalf * cam.up);

#if USE_DOF
    // Thin lens: sample disk on lens; focus plane at FOCUS_DIST along forward
    float u1 = rnd(rng);
    float u2 = rnd(rng);
    float r = sqrt(u1);
    float a = TWO_PI * u2;
    vec2 lens = LENS_RADIUS * vec2(r*cos(a), r*sin(a));

    vec3 lensPos = cam.pos + cam.right * lens.x + cam.up * lens.y;
    vec3 focusPoint = cam.pos + dir * FOCUS_DIST;
    dir = safeNormalize(focusPoint - lensPos);

    Ray rOut; rOut.o = lensPos; rOut.d = dir;
    rayPdf = 1.0;
    return rOut;
#else
    Ray rOut; rOut.o = cam.pos; rOut.d = dir;
    rayPdf = 1.0;
    return rOut;
#endif
}

// ----------------------------- Integrator ---------------------------------
vec3 trace(Ray ray, inout RNG rng) {
    vec3 L = vec3(0.0);
    vec3 beta = vec3(1.0);

    float prevBsdfPdf = 1.0;     // pdf of last scattering direction
    bool  prevWasSpec = false;   // for delta handling (future)

    for (int bounce=0; bounce<MAX_BOUNCES; bounce++) {
        Hit h = intersectScene(ray);
        if (!h.hit) break; // black background

        Material m = getMaterial(h.mtl);

        // If we hit a light, add emission with MIS (unless previous was delta)
        if (isLightId(h.mtl)) {
            vec3 Le = m.emission;

            if (bounce == 0 || prevWasSpec) {
                L += beta * Le;
            } else {
                // MIS between BSDF sampling and light sampling for "hitting a light"
                float lightPdf = pdfSphereLightW(ray.o, ray.d);
                float w = misWeight(prevBsdfPdf, lightPdf);
                L += beta * Le * w;
            }
            break;
        }

        vec3 x = h.p;
        vec3 n = h.n;

        // Ensure normal faces the incoming direction
        vec3 wi = -ray.d;
        if (dot(n, wi) < 0.0) n = -n;

        // ----------------- Direct lighting with MIS -----------------
        {
            LightSample ls = sampleSphereLight(x + n * EPS, rng);
            float NoL = max(0.0, dot(n, ls.wi));
            if (NoL > 0.0 && ls.pdfW > 0.0) {
                
                // shadow ray visibility to sampled point on light
                bool vis = visibleToLight(x + n*EPS, ls.wi, ls.dist);
                if (vis) {
                    float bsdfPdf;
                    vec3 f = bsdfEval(m, n, wi, ls.wi, bsdfPdf);

                    float w = misWeight(ls.pdfW, bsdfPdf);
                    vec3 contrib = ls.Le * f * NoL * w / ls.pdfW;

                    // optional clamp (bias)
                    contrib = min(contrib, vec3(CLAMP_LI));

                    L += beta * contrib;
                }
            }
        }

        // ----------------- Sample BSDF to continue the path ---------------
        BSDFSample s = bsdfSample(m, n, wi, rng);
        if (s.pdfW <= 0.0 || isNan(s.pdfW) || isInf(s.pdfW)) break;

        float NoL = max(0.0, dot(n, s.wo));
        if (NoL <= 0.0) break;

        // Throughput update: beta *= f * cos / pdf
        vec3 step = s.f * NoL / s.pdfW;
        if (any(isnan(step)) || any(greaterThan(abs(step), vec3(1e6)))) break;

        beta *= step;

        // Russian roulette (optional, after a couple bounces)
        if (bounce >= 2) {
            float q = saturate(1.0 - luminance(beta));
            q = clamp(q, 0.05, 0.95);
            if (rnd(rng) < q) break;
            beta /= (1.0 - q);
        }

        prevBsdfPdf = s.pdfW;
        prevWasSpec = s.isDelta;

        ray.o = x + n * EPS;
        ray.d = safeNormalize(s.wo);
    }

    return L;
}

// ----------------------------- Main ---------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    
    // RNG seed per pixel per frame
    float seed0 = hash12(fragCoord + iTime * 17.13) + 0.1234;
    RNG rng; rng.s = seed0;

    // Camera setup (mouse rotates slightly)
    float mx = (iMouse.x <= 0.0) ? 0.0 : (2.0 * iMouse.x / iResolution.x - 1.0);
    float my = (iMouse.y <= 0.0) ? 0.0 : (2.0 * iMouse.y / iResolution.y - 1.0);

    float yaw = mx * 1.2;
    float pitch = my * 0.6;

    vec3 camTarget = vec3(0.3, 0.4, -5.0);
    vec3 camPos = camTarget + vec3( sin(yaw)*5.0, 2.2 + pitch*3.0, cos(yaw)*5.0 );

    Camera cam = makeCamera(camPos, camTarget, vec3(0,1,0), radians(45.0));

    vec3 col = vec3(0.0);

    for (int si=0; si<SPP; si++) {
        vec2 jitter = vec2(rnd(rng), rnd(rng)); // [0,1)
        float rayPdf;
        Ray r = generateRay(cam, fragCoord, jitter, rng, rayPdf);

        vec3 Li = trace(r, rng);
        Li = min(Li, vec3(CLAMP_LI)); // final clamp
        col += Li;
    }

    col /= float(SPP);

    // Gamma
    col = pow(col, vec3(1.0/2.2));

    fragColor = vec4(col, 1.0);
}