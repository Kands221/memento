Target: Memento iPhone app illustration kit — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it, with ONE exception for this character only:
Sol may have two small simple dot eyes (ink #2B2723). No mouth, no eyebrows, no cartoon expressions —
character comes from pose and posture.

Context: "Sol" (short for Solomon) is Memento's on-device AI companion: a wise, warm, unhurried OLD
TORTOISE, like a beloved retired professor. He replaces the old paper-sun character. Open
design-assets/generated/onb-hero.png with view_image first and match its cut-paper medium, paper
fibre, soft layered shadows and palette.

Character sheet (must be identical in every image): a small, round, gentle tortoise made of layered
cut paper. Shell: sage #56724F with a lighter sage #DFE7D8 hexagon pattern and an umber #765F4A rim.
Head, neck and feet: warm sand #C8B186. Small round spectacles in thin ink #2B2723 wire. A tiny
terracotta #A85A38 knitted scarf around the neck. Kind, calm, a little playful.

Change: with your built-in image generation tool, create these PNGs (1024x1024, flat #FFFCF6
background, character in the central 65%), one per asset. Make sol-mark FIRST as the anchor and
view it before making the others; keep the same tortoise in all of them:
1. sol-mark: head-and-shoulders portrait, three-quarter view, spectacles and scarf clearly visible,
   bold and simple so it reads at 22-40 pt (this is the avatar).
2. sol-hello: full body, one front foot raised in a small wave, head up — a warm greeting.
3. sol-listening: full body, head tilted, leaning slightly forward, attentive.
4. sol-thinking: full body, eyes closed, head slightly lowered, one front foot near the chin, a single
   small terracotta paper swirl floating above the head (no text).
5. sol-reflect: Sol sitting beside an open cream notebook, looking at the page, spectacles on.
6. sol-resting: head and feet tucked into the shell, eyes closed, sleeping peacefully on a small sand
   paper patch of ground.

After each generation copy the PNG from the path the image tool reports (normally under
~/.codex/generated_images/) to design-assets/generated/tortoise/<name>.png and write
design-assets/generated/tortoise/<name>.prompt.md with the exact final prompt.
Regenerate (max 3 tries each) if an image has text, a mouth or exaggerated cartoon face, or a
tortoise that doesn't match the character sheet / sol-mark.

Constraints: follow STYLE.md (with the eyes exception above); no text of any kind.
Ownership: create files ONLY under design-assets/generated/tortoise/. Do not edit any other file. No git.
Observable acceptance: 6 PNGs + 6 .prompt.md files exist; you viewed each final image (also scaled
to ~80 px) and confirmed it reads as the same tortoise. List files in worker_done.
If image generation is unavailable, send worker_done with --outcome failed and say why.
