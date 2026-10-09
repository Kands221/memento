Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Before generating anything, open design-assets/generated/onb-hero.png and
design-assets/generated/sol-mark.png with view_image and match their paper texture, shadow depth,
cut style and palette.

Change: with your built-in image generation tool, create these PNGs (1024x1536 portrait), one per asset.
Each is a notebook cover: bookcloth texture filling the WHOLE frame (the cloth is the background,
not cream), subtle woven texture, a small paper-cut emblem in the lower third, the upper 55% plain
cloth (a label plate will be overlaid there in the app). Nothing else in frame.
1. cover-daily: terracotta-red cloth #B4633F; emblem = cream paper sun-and-moon.
2. cover-work: charcoal cloth #3B3733; emblem = cream paper plane.
3. cover-gratitude: sage cloth #7F9679; emblem = cream olive branch.
4. cover-reflections: sand cloth #C8B186; emblem = slate crescent moon over two wave strips.

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
