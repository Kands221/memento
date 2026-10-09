Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Before generating anything, open design-assets/generated/onb-hero.png and
design-assets/generated/sol-mark.png with view_image and match their paper texture, shadow depth,
cut style and palette.

Change: with your built-in image generation tool, create these PNGs, one per asset:
1. onb-notice (1024x1024): a paper magnifier resting on a cream page with three small coloured
   paper tabs (terracotta, umber, sage) peeking from the page edge.
2. onb-find (1024x1024): three cream paper pages fanned out, joined by a single sage thread.
3. empty-journal (1024x1024): an open blank cream notebook with a pencil and a single olive sprig.
4. empty-discover (1024x1024): a row of four small paper sprouts in sage and terracotta tint.
5. empty-search (1024x1024): a few paper leaves under a paper magnifier.
6. ai-unavailable (1024x1024): a sand paper crescent moon resting over a closed cream notebook, calm.
7. sample-ceramics (1536x1024 landscape) — the ONE photographic image (ignore the paper-cut medium
   rule for this one only): warm natural-light film photo of a lopsided handmade speckled ceramic
   bowl on a pale oak table, shallow depth of field, no people, no text.

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
