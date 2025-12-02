// Buffer B: SSAO (Baseline)
// Binary occlusion via depth comparison.
//
// Expected inputs:
//   iChannel0: GBuffer RGBA = normal.xyz ([-1,1]), depth01 in .w (depth01 = t / FAR_CLIP)
//   iChannel1: noise texture (RGB random in [0,1])

#define AO_SAMPLES 16
#define FAR_CLIP   10.0

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec4 gbuf = texture(iChannel0, uv);
    vec3 nrm  = normalize(gbuf.xyz);
    float depth01 = gbuf.w;

    // Recover ray distance t in "view-ish units"
    float viewDepth = depth01 * FAR_CLIP;

    float aoRadius   = 0.10;
    float offsetScale = aoRadius / max(viewDepth, 1e-3);

    float occlusionCount = 0.0;

    for (int i = 0; i < AO_SAMPLES; ++i)
    {
        vec2 noiseUV = (fragCoord + 23.71 * float(i)) / iChannelResolution[1].xy;
        vec3 rnd = texture(iChannel1, noiseUV).xyz * 2.0 - 1.0;

        // Hemisphere align
        if (dot(nrm, rnd) < 0.0) rnd *= -1.0;

        vec2 sampleUV = uv + rnd.xy * offsetScale;

        float sampleDepth01 = texture(iChannel0, sampleUV).w;
        float sampleViewDepth = sampleDepth01 * FAR_CLIP;

        // neighbor closer => occluder
        float depthDelta = viewDepth - sampleViewDepth;

        float isOccluder = step(0.01, depthDelta);
        occlusionCount += isOccluder;
    }

    float ao = occlusionCount / float(AO_SAMPLES); // higher = more occluded

    fragColor = vec4(vec3(ao), 1.0);
}
