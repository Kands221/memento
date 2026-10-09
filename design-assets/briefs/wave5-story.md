Target: Memento story video — IMAGES ONLY. Working directory: this worktree.
Read design-assets/STYLE.md first and follow it, with the exceptions listed below for this wave only.
Open design-assets/generated/onb-hero.png and design-assets/generated/tortoise/sol-hello.png with view_image
first and match their cut-paper medium, paper fibre, soft layered shadows and palette.

# Wave 5: the story video's paper world (5 images)

Style: follow design-assets/STYLE.md (layered cut paper, visible fibre, soft contact shadows, matte light),
with these exceptions for this wave only:
- Faceless paper-cut people are allowed: simple head shapes, no eyes/nose/mouth, simplified mitten hands.
- Full scenes edge to edge (no flat cream background).
- Night images may use deep slate-indigo paper (#2E3550 to #3E4766) and a pale moon (#F2EEE2).
Everything else in STYLE.md still holds: palette, no text, no numbers, no letters, no UI, no logos, no photorealism.
Do NOT draw the tortoise (Sol is added separately in the video).

Format: landscape 1536×1024. The video crops to 16:9 (1536×864, centred), so keep everything important between
y = 80 and y = 944. Keep the RIGHT THIRD (x > 1024) quiet: plain wall / sky / meadow only. A phone is placed there.

The same bedroom appears in images 1, 2 and 4: same camera, same furniture in the same places.

1. story-night: night bedroom. A woman (late 20s, faceless paper figure, dark hair) lies awake in bed, head on the
   pillow at about (430, 590), turned toward the ceiling. A small nightstand at the left (x 110–300, y 620–880) holds a
   closed cloth journal at about (230, 640) and a small round paper clock with a BLANK face at about (290, 605). A window
   at upper left shows a pale crescent moon at about (460, 180). A soft warm glow from a phone lying on the duvet.
2. story-writing: the same room and camera. She sits up against the headboard, head at about (480, 430), holding a
   glowing phone. The journal lies OPEN on the nightstand at about (230, 650), pages up, with empty space above it.
3. story-dusk: a dusk walk. Two faceless women walk side by side along a paper path under autumn trees, at about
   x 380–620, y 520–900, facing right. Low sunset band in terracotta and sand, long soft shadows.
4. story-dawn: the same bedroom and camera as 1–2 at sunrise. The bed is made and empty; warm peach light pours through
   the window; the journal is closed on the nightstand.
5. story-morning: a morning path across the lower third from left to right. The same two women walk away to the
   right, at about x 640–820, y 470–880. Open path behind them at the left (x 120–420, y 820–880) with nothing on it.
   Fresh sage meadow, small paper wildflowers, soft morning sun.

Change: with your built-in image generation tool, create TWO variants of each image at 1536x1024. Make story-night FIRST
as the room anchor and view it before making story-writing and story-dawn, keeping the same room. After each generation
copy the PNG from the path the image tool reports (normally under ~/.codex/generated_images/) to
design-assets/generated/story/<name>-a.png and <name>-b.png, and write design-assets/generated/story/<name>.prompt.md
with the exact final prompts.
Regenerate (max 3 tries each) if an image has text, numbers, a face with features, a tortoise, a busy right third, or a
bedroom that doesn't match story-night.

Constraints: follow STYLE.md with the exceptions above; no text of any kind.
Ownership: create files ONLY under design-assets/generated/story/. Do not edit any other file. No git.
Observable acceptance: 10 PNGs (5 images × variants a and b) + 5 .prompt.md files exist; you viewed each final image
and confirmed the composition matches its numbered description (positions within about ±60 px) and that images 1, 2
and 4 show the same room. List files in worker_done.
If image generation is unavailable, send worker_done with --outcome failed and say why.
