# Shader-Finds
A curated Shadertoy/GLSL shaders collection (that I find interested/helpful), with short notes. Organized by difficulty. Includes a few of my own teaching demos and old water ripple experiments.

Most entries are **links only** (no code copied).  
When code is included, it’s either **mine** (see `my_shaders/`) or included with explicit permission/license + attribution.

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

### SDF Tutorial 1: Box & Balloon
- Link: https://www.shadertoy.com/view/Xl2XWt
- What it teaches: SDF construction + raymarching fundamentals (clear + commented)
- Tags: `sdf` `raymarch` `lighting`

### Inigo Quilez - 2D Distance Functions
- Link: https://iquilezles.org/articles/distfunctions2d/
- What it teaches: reference library of common distance functions (with demos)
- Tags: `sdf` `reference` `geometry`

### NoxWings - Raymarching Tutorial Step 00
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
- Shader ID referenced: `4djfR1`
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

### Reflective Fabric Tiles [142]
- Link: https://www.shadertoy.com/view/W3Xcz4
- What it teaches: procedural material vibes + reflection tricks
- Tags: `procedural` `materials` `reflection`

---

## Cool Stuff / Inspiration

### Shadertoy Tag: Ripple (Hot)
- Link: https://www.shadertoy.com/results?query=tag%3Dripple&sort=hot
- Tags: `water` `ripples` `fx`

### Shadertoy Tag: Ripple Effect (Popular)
- Link: https://www.shadertoy.com/results?filter=&query=tag%3Drippleeffect&sort=popular
- Tags: `water` `ripples` `fx`

### Water-Ripple Effect (Multi-buffer)
- Link: https://www.shadertoy.com/view/fsGcWz
- What it teaches: multi-buffer water ripple simulation tricks
- Tags: `multipass` `water` `simulation`

---

## My shaders

See [`my_shaders/`](my_shaders/) for:
- teaching demos (clean, small shaders)
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
