# SDF Ambient Occlusion (Hemisphere Sampling) - Single-pass Raymarch Demo

This snippet is a **self-contained raymarch shader** that demonstrates a practical **SDF-based ambient occlusion** approximation using **hemisphere sampling around the surface normal**.

Unlike SSAO (screen-space AO), this version queries the **scene signed distance field** directly (`distFunc`) at 3D sample points around the shading point, so it can capture occlusion that isn’t strictly limited to what’s on screen.

## What’s included
- `distFunc(p)`: scene SDF (plane + sphere + torus)
- `getNormal(p)`: SDF gradient normal via central differences
- `rayMarch(ro, rd)`: sphere tracing / raymarch to find surface hit
- `softShadowSDF(ro, rd)`: soft shadow approximation using SDF stepping
- `ambientOcclusionHemisphereSDF(p, n, fragCoord)`: hemisphere AO sampling (returns **AO visibility** in `[0,1]`)

## How AO works (high-level)
For sample directions in the **hemisphere aligned to the normal**:
1. Pick direction `wdir` (random per pixel, per sample)
2. Pick radius `r` (a schedule biased toward near samples)
3. Evaluate `d = distFunc(p + n*bias + wdir*r)`
4. Convert to “occlusion” using a simple heuristic: if `d` is small compared to `r`, nearby geometry is blocking ambient light.

Result is a scalar:
- `ao = 1.0` → open space / exposed
- `ao = 0.0` → fully occluded

Then the demo applies:
- `ambient *= ao`

## Tunable parameters (recommended first knobs)
Inside `ambientOcclusionHemisphereSDF(...)`:
- `AO_SAMPLES` (default 16): quality vs speed
- `AO_RADIUS` (default 0.30): how far AO “reaches” in world units (SDF space)
- `AO_BIAS` (default 0.02): pushes sampling away from the surface to reduce self-occlusion
- `AO_STRENGTH` (default 1.0): overall darkness; higher = stronger AO

## Notes / limitations
- This is an **approximation** (not a physically correct integral), but it’s a standard, useful real-time-style AO heuristic for raymarched/SDF scenes.
- Sampling uses a simple hash-based RNG. For less noise, consider:
  - a small blue-noise texture for direction rotation, or
  - temporal accumulation + reprojection (if you go multi-pass / persistent state)

## Usage
Paste the `.glsl` file into Shadertoy as an **Image** shader (single pass).  
The mouse controls a simple orbit camera.

## References
- *A Simple and Practical Approach to SSAO* (screen-space AO background)  
  http://www.gamedev.net/page/resources/_/technical/graphics-programming-and-theory/a-simple-and-practical-approach-to-ssao-r2753
- Shadertoy SSAO reference shader (for screen-space comparison)  
  https://www.shadertoy.com/view/4ltSz2
- Shadertoy raymarch AO-style reference shader:  
  https://www.shadertoy.com/view/ltKcWc