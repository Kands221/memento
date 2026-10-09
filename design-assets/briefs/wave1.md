Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it exactly.

Change: with your built-in image generation tool, create these PNGs, one generation per asset:
1. onb-hero (1024x1024): an olive sprig with five or six sage leaves laid diagonally across an
   open cream notebook seen from above; a small terracotta paper bookmark ribbon. STYLE ANCHOR —
   do this first and make it excellent.
2. onb-private (1024x1024): a closed cream notebook held shut by a band made of sage paper olive
   leaves, with a tiny terracotta paper padlock on the band.
3. sol-mark (1024x1024): a small round paper sun — layered terracotta-tint and sand discs with
   eight short soft rays — centred with wide margin. Must stay legible scaled down to 40 pt.
4. app-icon (1024x1024): FULL-BLEED terracotta #A85A38 paper background (no cream, no border,
   no rounded corners); a cream paper-cut olive sprig curving across the centre, two sage leaves.
Before generating 2–4, open design-assets/generated/onb-hero.png with view_image and match its
paper texture, shadow depth, cut style and palette.

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
