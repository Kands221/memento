Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Before generating anything, open design-assets/generated/onb-hero.png and
design-assets/generated/sol-mark.png with view_image and match their paper texture, shadow depth,
cut style and palette.

Change: with your built-in image generation tool, create these PNGs, one per asset. Icons and
emblems (1–10) are a single bold paper shape filling the central 60% so they read at 28–40 pt.
1. mode-free (1024x1024): rounded terracotta-tint (#F2E1D4) paper square with a folded corner.
2. mode-dump (1024x1024): terracotta paper ring with a small swirl inside.
3. mode-guided (1024x1024): terracotta paper diamond with a tiny cream compass star.
4. mode-photo (1024x1024): cream paper frame with a small terracotta paper sun inside.
5. kind-feeling (1024x1024): terracotta heart-shaped paper leaf.
6. kind-situation (1024x1024): umber paper house with one lit (sand) window.
7. kind-helped (1024x1024): sage paper sprig with three leaves.
8. kind-topic (1024x1024): slate folded paper note.
9. streak-sprout (1024x1024): a small paper sprout with three leaves in a terracotta-tint pot.
10. tonight-ornament (1024x1024): a sand paper crescent moon with two tiny cream stars.
11. reminder-scene (1024x1536 portrait): paper-cut dusk landscape — layered sand and umber paper
    hills under a low terracotta sun; the upper third is plain soft sky (a clock goes there).
    Fills the whole frame (no cream border).
12. paper-grain (1024x1024): seamless, very low-contrast cream paper fibre texture, no objects;
    must tile without visible seams.

After each generation copy the PNG from the path the image tool reports (normally under
~/.codex/generated_images/) to design-assets/generated/<name>.png and write
design-assets/generated/<name>.prompt.md containing the exact final prompt you used.
If an image contains any text/letters or breaks STYLE.md, regenerate it (max 3 tries each).

Constraints: follow STYLE.md; no text of any kind in images.
Ownership: create files ONLY under design-assets/generated/. Do not edit Swift code, the Xcode
project, docs, or any other file. Do not run git commands.
Observable acceptance: every listed PNG + its .prompt.md exist in design-assets/generated/;
`sips -g pixelWidth -g pixelHeight design-assets/generated/*.png` shows >=1024 px on the short
side; you viewed every final image and confirmed it has no text. List the files in worker_done.
If image generation is unavailable, send worker_done with --outcome failed and say why.
