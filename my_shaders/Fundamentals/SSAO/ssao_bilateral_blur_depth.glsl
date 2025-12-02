// Buffer C: Depth-aware bilateral blur for SSAO
//
// Expected inputs:
//   iChannel0: AO input (grayscale in .r)       (e.g., output of Buffer B)
//   iChannel1: GBuffer with depth01 in .w       (or a dedicated depth texture)
//
// If you pass the same GBuffer in iChannel1, keep DEPTH_FROM_GBUFFER = 1.

#define DEPTH_FROM_GBUFFER 1

#define BLUR_RADIUS    3
#define SIGMA_SPATIAL  2.0
#define SIGMA_DEPTH    0.02

float depth01_at(vec2 uv)
{
#if DEPTH_FROM_GBUFFER
    return texture(iChannel1, uv).w;
#else
    return texture(iChannel1, uv).r;
#endif
}

float gaussian(float x, float sigma)
{
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    float centerAO = texture(iChannel0, uv).r;
    float centerZ  = depth01_at(uv);

    float sum = 0.0;
    float wsum = 0.0;

    for (int y = -BLUR_RADIUS; y <= BLUR_RADIUS; ++y)
    for (int x = -BLUR_RADIUS; x <= BLUR_RADIUS; ++x)
    {
        vec2 duv = vec2(float(x), float(y)) * texel;
        vec2 uvS = uv + duv;

        float aoS = texture(iChannel0, uvS).r;
        float zS  = depth01_at(uvS);

        float wSpatial = gaussian(length(vec2(float(x), float(y))), SIGMA_SPATIAL);
        float wDepth   = gaussian((zS - centerZ), SIGMA_DEPTH);

        float w = wSpatial * wDepth;

        sum  += aoS * w;
        wsum += w;
    }

    float aoBlur = sum / max(wsum, 1e-6);

    fragColor = vec4(vec3(aoBlur), 1.0);
}
