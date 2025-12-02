// Buffer B (alternative): SSAO (Weighted)
// Hemisphere sampling + normal alignment + distance falloff.
//
// Expected inputs:
//   iChannel0: GBuffer RGBA = normal.xyz ([-1,1]), depth01 in .w (depth01 = t / FAR_CLIP)
//   iChannel1: noise texture (RGB random in [0,1])

#define AO_SAMPLES 16
#define FAR_CLIP   10.0
#define AO_BIAS    0.30   // higher = less self-occlusion

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec4 gbuf = texture(iChannel0, uv);
    vec3 nrm  = normalize(gbuf.xyz);
    float depth01 = gbuf.w;

    float viewDepth = depth01 * FAR_CLIP;

    float aoRadius   = 0.10;
    float offsetScale = aoRadius / max(viewDepth, 1e-3);

    float aoAccum = 0.0;

    for (int i = 0; i < AO_SAMPLES; ++i)
    {
        vec2 noiseUV = (fragCoord + 23.71 * float(i)) / iChannelResolution[1].xy;
        vec3 hemiDir = texture(iChannel1, noiseUV).xyz * 2.0 - 1.0;

        // Hemisphere align
        if (dot(nrm, hemiDir) < 0.0) hemiDir *= -1.0;

        vec2 sampleUV = uv + hemiDir.xy * offsetScale;

        float sampleViewDepth = texture(iChannel0, sampleUV).w * FAR_CLIP;
        float depthDelta = viewDepth - sampleViewDepth;

        // Crude view-ish vector to sample
        vec3 sampleVec = vec3(hemiDir.xy * aoRadius, depthDelta);

        float dist = length(sampleVec);
        vec3 dir = sampleVec / max(dist, 1e-4);

        float alignment = max(0.0, dot(nrm, dir) - AO_BIAS);
        float falloff   = 1.0 / (dist + 1.0);

        float occ = alignment * falloff;

        // Invert so "more occlusion" means darker output
        aoAccum += 1.0 - occ;
    }

    float ao = aoAccum / float(AO_SAMPLES);

    fragColor = vec4(vec3(ao), 1.0);
}
