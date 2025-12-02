// Water ripple refraction (heightfield -> normal -> UV distortion)
//
// Expected inputs:
//   iChannel0: background texture (e.g., any image)
//
// Controls:
//   RIPPLE_FREQ   : how many ripples
//   RIPPLE_SPEED  : animation speed
//   DISTORTION    : refraction strength (UV offset)
//   NORMAL_EPS    : finite-diff step for normal

const float RIPPLE_FREQ  = 30.0;
const float RIPPLE_SPEED = 10.0;

const float DISTORTION   = 0.06;
const float NORMAL_EPS   = 0.01;

// A simple radial ripple composition.
// uv is centered coords in roughly [-1,1] range.
float heightField(vec2 uv)
{
    float r = length(uv);

    // Three sources with different offsets/speeds to break symmetry.
    float w1 = sin(length(uv + vec2( 0.10)) * RIPPLE_FREQ - iTime * RIPPLE_SPEED);
    float w2 = sin(length(uv + vec2( 0.40)) * RIPPLE_FREQ - iTime * RIPPLE_SPEED);
    float w3 = sin(length(uv + vec2(-0.80)) * RIPPLE_FREQ - iTime * (RIPPLE_SPEED * 0.5) + 1.0);

    // Fade toward edges to avoid hard cutoff artifacts.
    float fade = clamp(1.0 - r, 0.0, 1.0);
    fade = fade * fade;

    return (w1 + w2 + w3) * fade;
}

// Finite-difference normal from heightfield.
// Treat height as Y, and (x,z) as the plane. (Classic heightmap normal.)
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

    // Tangents in (x,y,z) space.
    vec3 tx = vec3(1.0, dhdx, 0.0);
    vec3 tz = vec3(0.0, dhdz, 1.0);

    // Normal points "up" in +Y.
    return normalize(cross(tz, tx));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Centered coords; make them aspect-correct so ripples are circular.
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Normal from heightfield
    vec3 n = heightNormal(p);

    // Convert back to texture UVs (0..1)
    vec2 uv = fragCoord / iResolution.xy;

    // Distort UV using the horizontal components of the normal
    uv += n.xz * DISTORTION;

    // Optional: keep samples valid (avoids wrap if texture is clamp)
    uv = clamp(uv, 0.001, 0.999);

    fragColor = texture(iChannel0, uv);
}
