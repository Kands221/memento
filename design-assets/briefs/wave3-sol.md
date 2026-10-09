Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Context: "Sol" is Memento's on-device AI companion — a small paper sun. These images give Sol a
character through POSE and STATE (no faces, no eyes, no mouths). Before generating anything, open
design-assets/generated/sol-mark-v2.png and design-assets/generated/onb-hero.png with view_image:
every image below must show the SAME sun as sol-mark-v2 (terracotta #A85A38 disc core on a
terracotta-tint #F2E1D4 ring, eight short rounded terracotta rays), same paper texture and shadows.

Change: with your built-in image generation tool, create these PNGs (1024x1024, flat #FFFCF6
background, subject in the central 65%), one per asset:
1. sol-hello: the sun rising halfway above a single cream-and-sand paper horizon strip, rays fanned
   upward and slightly longer — a greeting.
2. sol-thinking: the same sun with its eight rays curled into soft paper spirals, as if mulling
   something over.
3. sol-listening: the same sun with two thin concentric terracotta-tint paper rings around it, like
   gentle ripples.
4. sol-reflect: the same sun, smaller, resting on the gutter of an open cream notebook, casting a
   soft warm sand-coloured glow strip across the page.
5. sol-resting: the same sun half tucked behind a soft sand paper cloud, rays on the hidden side
   folded away — calm, sleepy.

After each generation copy the PNG from the path the image tool reports (normally under
~/.codex/generated_images/) to design-assets/generated/<name>.png and write
design-assets/generated/<name>.prompt.md with the exact final prompt. Regenerate (max 3 tries)
if an image has text, a face, or a sun that doesn't match sol-mark-v2.

Constraints: follow STYLE.md; no text; NO faces/eyes/mouths.
Ownership: create files ONLY under design-assets/generated/. Do not edit any other file. No git.
Observable acceptance: 5 PNGs + 5 .prompt.md files exist; you viewed each final image (also scaled
to ~80 px) and confirmed it reads as the same Sol character. List files in worker_done.
If image generation is unavailable, send worker_done with --outcome failed and say why.
