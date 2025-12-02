# Shader-Finds
A curated Shadertoy/GLSL shaders collection (that I find interested/helpful), with short notes. Organized by difficulty. Includes a few of my own teaching demos and old water ripple experiments.

Most entries are **links only** (no code copied).  
Some attached code is mine from a long time ago (see `my_shaders/`).

---

## How to use this repo

- Browse by difficulty:
  - [Beginner](#beginner)
  - [Intermediate](#intermediate)
  - [Advanced](#advanced)
  - [Cool Stuff / Inspiration](#cool-stuff--inspiration)
- Each entry has:
  - **Link**
  - **What it teaches**
  - **Tags**
  - Optional **notes / follow-ups**

---

## Beginner

### The Art of Code - Shadertoy Tutorial Playlist
- Link: https://www.youtube.com/playlist?list=PLGmrMu-IwbguU_nY2egTFmlg691DN7uE5
- What it teaches: 2D basics, signed distance intuition, simple patterns, compositing
- Tags: `2d` `basics` `sdf` `uv`

### Pulsing Circles with Noise
- Link: https://www.shadertoy.com/view/wfdXWS
- What it teaches: simple 2D animation + noise modulation
- Tags: `2d` `noise` `animation`

---

## Intermediate

### Ray Tracing in One Weekend
- Link: https://raytracing.github.io/books/RayTracingInOneWeekend.html#diffusematerials/asimplediffusematerial
- What it teaches: fundamentals + diffuse lambertian and various materials + global illumination
- Tags: `pathtracing` `diffuse` `lambertian` `sampling` `fundamentals`

### SDF Tutorial 1: Box & Balloon
- Link: https://www.shadertoy.com/view/Xl2XWt
- What it teaches: SDF construction + raymarching fundamentals (clear + commented)
- Tags: `sdf` `raymarch` `lighting`

### Inigo Quilez - 2D Distance Functions
- Link: https://iquilezles.org/articles/distfunctions2d/
- What it teaches: reference library of common distance functions (with demos)
- Tags: `sdf` `reference` `geometry`

### NoxWings - Raymarching Tutorial
- Link: https://noxwings.com/blog/posts/2021/09/24/step00-intro.html
- What it teaches: structured “from zero” raymarch walkthrough
- Tags: `raymarch` `tutorial` `walkthrough`

### Ray Marching: Basics
- Link: https://www.shadertoy.com/view/l3fcDN
- What it teaches: minimal baseline raymarch loop you can build on
- Tags: `raymarch` `baseline`

---

## Advanced

### The Drive Home (Livecoding series)
- Starting point: https://www.youtube.com/watch?v=tdwXMtnuuXg
- What it teaches: complex scene building, iteration, creative hacks, multi-pass thinking
- Tags: `raymarch` `multipass` `creative`

### Cubemap Debug
- Link: https://www.shadertoy.com/view/tf3XDN
- What it teaches: cubemap mapping sanity checks / debugging
- Tags: `cubemap` `debug` `tooling`

### Raymarching with Dithering
- Link: https://www.shadertoy.com/view/Ntc3R7
- What it teaches: dithering tricks to fight banding / improve perceived quality
- Tags: `raymarch` `dither` `quality`

### Reflective Fabric Tiles
- Link: https://www.shadertoy.com/view/W3Xcz4
- What it teaches: procedural material vibes + reflection tricks
- Tags: `procedural` `materials` `reflection`

---

## Cool Stuff / Inspiration

### Water-Ripple Effect (Multi-buffer)
- Link: https://www.shadertoy.com/view/fsGcWz
- What it teaches: multi-buffer water ripple simulation tricks
- Tags: `multipass` `water` `simulation`

### Seascape
- Link: https://www.shadertoy.com/view/Ms2SD1
- What it teaches: ocean/wave shading, sky + horizon, foam, and “big scene from cheap tricks”
- Tags: `water` `procedural` `lighting` `raymarch-ish` `classic`

### Elevated
- Link: https://www.shadertoy.com/view/MdX3Rr
- What it teaches: procedural terrain generation, fBm, erosion-ish look, distance fog/atmosphere
- Tags: `terrain` `fbm` `procedural` `landscape` `classic`

### Rainforest
- Link: https://www.shadertoy.com/view/4ttSWf
- What it teaches: dense procedural scene construction, layering detail, performance-minded shading
- Tags: `procedural` `scene` `fbm` `raymarch` `iq`

### Helix 1
- Link: https://www.shadertoy.com/view/XsdBW8
- What it teaches: clean SDF form + camera motion + shading on a simple geometric idea
- Tags: `sdf` `raymarch` `geometry` `composition`

### Happy Jumping
- Link: https://www.shadertoy.com/view/3lsSzf
- What it teaches: character-ish animation via SDF + domain warping + timing/pose tricks
- Tags: `sdf` `animation` `character` `raymarch` `iq`

### More spheres
- Link: https://www.shadertoy.com/view/lsX3DH
- What it teaches: realtime path tracing basics, DOF/motion blur, noise + convergence intuition
- Tags: `pathtracing` `sampling` `dof` `motion-blur` `rendering`

### Old watch (RT)
- Link: https://www.shadertoy.com/view/MlyyzW
- What it teaches: a full “hero asset” path-traced scene; materials + lighting integration
- Tags: `pathtracing` `materials` `lighting` `scene`

### Robotic Arm
- Link: https://www.shadertoy.com/view/tlSSDV
- What it teaches: rendering a non-trivial animated 3D scene via ray tracing (not SDF raymarch), plus procedural animation/IK vibes
- Tags: `raytracing` `animation` `procedural` `scene`

### RIOW 2.06: Rectangles and lights
- Link: https://www.shadertoy.com/view/4tGcWD
- What it teaches: area lights / rectangles, sampling considerations, “rendering theory in shader form”
- Tags: `raytracing` `sampling` `area-lights` `lighting`

### Interleave sampling
- Link: https://www.shadertoy.com/view/NdlGRN
- What it teaches: sampling pattern ideas / interleaving for noise reduction (great “why does this work?” study)
- Tags: `sampling` `noise` `integration` `technique`

---

## My shaders

See [`my_shaders/`](my_shaders/) for:
- teaching demos I prepared for some friends
- old water ripple experiments

---

## Contributing / Notes

- If you suggest a shader, add:
  - link + author
  - 1–2 lines on why it’s interesting
  - tags

---

## License & attribution

- This repository is primarily a **curated set of links + commentary**.
- If any third-party code is ever included, it will be clearly attributed and include the original license/terms.
