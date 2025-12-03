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
  - **Why it's interesting**
  - Optional **notes / follow-ups**

---

## Beginner

### The Art of Code - Shadertoy Tutorial Playlist
- Link: https://www.youtube.com/playlist?list=PLGmrMu-IwbguU_nY2egTFmlg691DN7uE5
- 2D basics, signed distance geomtery, simple patterns, compositing

### Pulsing Circles with Noise
- Link: https://www.shadertoy.com/view/wfdXWS
- simple 2D animation, noise modulation

---

## Intermediate

### Ray Tracing in One Weekend
- Link: https://raytracing.github.io/books/RayTracingInOneWeekend.html#diffusematerials/asimplediffusematerial
- fundamentals, diffuse lambertian and various materials, global illumination

### SDF Tutorial 1: Box & Balloon
- Link: https://www.shadertoy.com/view/Xl2XWt
- SDF construction, raymarching fundamentals

### Inigo Quilez - 2D Distance Functions
- Link: https://iquilezles.org/articles/distfunctions2d/
- reference library of common distance functions (with demos and some code for reference)

### NoxWings - Raymarching Tutorial
- Link: https://noxwings.com/blog/posts/2021/09/24/step00-intro.html
- structured 'from scratch' raymarch walkthrough

### Ray Marching: Basics
- Link: https://www.shadertoy.com/view/l3fcDN
- minimal baseline raymarch loop that's easy to extend

---

## Advanced

### The Drive Home (Livecoding series)
- Starting point: https://www.youtube.com/watch?v=tdwXMtnuuXg
- complex scene building, multi-pass buffering

### Cubemap Debug
- Link: https://www.shadertoy.com/view/tf3XDN
- cubemap mapping sanity checks, debugging

### Raymarching with Dithering
- Link: https://www.shadertoy.com/view/Ntc3R7
- dithering tricks to fight banding

### Reflective Fabric Tiles
- Link: https://www.shadertoy.com/view/W3Xcz4
- procedural materials, reflection tricks

---

## Cool Stuff / Inspiration

### Water-Ripple Effect (Multi-buffer)
- Link: https://www.shadertoy.com/view/fsGcWz
- multi-buffer water ripple simulation tricks

### Seascape
- Link: https://www.shadertoy.com/view/Ms2SD1
- ocean/wave shading, sky + horizon, foam, and “big scene from cheap tricks”

### Elevated
- Link: https://www.shadertoy.com/view/MdX3Rr
- procedural terrain generation, fBm, erosion-ish look, distance fog/atmosphere

### Rainforest
- Link: https://www.shadertoy.com/view/4ttSWf
- dense procedural scene construction, layering detail, performance-minded shading

### Helix 1
- Link: https://www.shadertoy.com/view/XsdBW8
- clean SDF form + camera motion, shading on a simple geometric idea

### Happy Jumping
- Link: https://www.shadertoy.com/view/3lsSzf
- character-ish animation via SDF, domain warping, timing/pose tricks

### More spheres
- Link: https://www.shadertoy.com/view/lsX3DH
- realtime path tracing basics, DOF/motion blur, noise + convergence intuition

### Old watch (RT)
- Link: https://www.shadertoy.com/view/MlyyzW
- a full “hero asset” path-traced scene - materials and lighting integration

### Robotic Arm
- Link: https://www.shadertoy.com/view/tlSSDV
- rendering a non-trivial animated 3D scene via ray tracing (not SDF raymarch), plus procedural animation/IK vibes

### RIOW 2.06: Rectangles and lights
- Link: https://www.shadertoy.com/view/4tGcWD
- area lights, sampling considerations, “rendering theory in shader form”

### Interleave sampling
- Link: https://www.shadertoy.com/view/NdlGRN
- sampling pattern ideas, interleaving for noise reduction (“why does this work?” - I don't fully understand either)

---

## My shaders

See [`my_shaders/`](my_shaders/) for:
- teaching demos I prepared for some friends
- old water ripple experiments

---

## Contributing / Notes

- If you suggest a shader, add:
  - link and author
  - 1-2 lines on why it’s interesting

---

## License & attribution

- This repository is primarily a **curated set of links + commentary**.
- If any third-party code is ever included, it will be clearly attributed and include the original license/terms.
