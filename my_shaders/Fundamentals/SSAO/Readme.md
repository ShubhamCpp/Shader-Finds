# SSAO (Screen-Space Ambient Occlusion) — Shadertoy-style snippets

This folder contains a small, self-contained SSAO study setup in Shadertoy-style GLSL:
- **Buffer A** builds a tiny GBuffer (SDF scene raymarch) and outputs **view-space-ish normals** + **normalized depth**.
- **Buffer B** implements two SSAO variants:
  - `ssao_binary.glsl` (baseline depth-delta “is it closer?” occlusion)
  - `ssao_weighted.glsl` (normal-alignment + distance falloff)
- **Buffer C** applies a **depth-aware bilateral blur** to reduce noise while preserving edges.

The goal is clarity and hackability, not production SSAO.

## References
- *A Simple and Practical Approach to SSAO* (GameDev.net)  
  http://www.gamedev.net/page/resources/_/technical/graphics-programming-and-theory/a-simple-and-practical-approach-to-ssao-r2753
- Shadertoy reference shader:  
  https://www.shadertoy.com/view/4ltSz2

## Suggested Shadertoy wiring
- **Buffer A:** `buffer_a_gbuffer.glsl`
- **Buffer B:** `ssao_binary.glsl` **or** `ssao_weighted.glsl`
  - `iChannel0 = Buffer A` (normal.xyz, depth01 in .w)
  - `iChannel1 = noise texture` (random RGB in [0,1])
- **Buffer C:** `ssao_bilateral_blur_depth.glsl`
  - `iChannel0 = Buffer B` (AO)
  - `iChannel1 = Buffer A` (depth in .w)
- **Image:** display Buffer C (or multiply AO into a base shading pass)

## Notes / knobs
- `AO_SAMPLES`: quality vs speed
- `aoRadius`: screen-space radius (scaled by depth in the shader)
- `AO_BIAS`: reduces self-occlusion (“acne”) in the weighted version
- `SIGMA_DEPTH`: smaller preserves edges more aggressively in the bilateral blur
