# Orca run — Memento asset kit (images only)

Run: `run_a9cf74431017`

| Wave | Task | Dispatch | Status |
|---|---|---|---|
| 1 (attempt 1) | task_4fdb38843d41 | ctx_eba214c57b21 | failed at agent_readiness (Codex workspace-trust prompt); trust accepted in Codex UI; released |
| 1 | task_3907b104bca0 | ctx_77b4152dcfc3 | succeeded; released |
| 2A covers | — | ctx_0312373c9fe5 | succeeded; released |
| 2B spots + empty states | — | ctx_071ce224ae10 | succeeded; release reported `retained` (recheck at close-out) |
| 2C UI accents | — | ctx_f386773402bb | succeeded; release reported `retained` (recheck at close-out) |
| 1 redo: sol-mark-v2 | — | ctx_1b6e9f7cdbb3 | succeeded; released |

| 3 Sol character | — | ctx_4f1525d16a9d | succeeded (answered 1 question: no post-processing needed) |
| 4 Sol as an old tortoise | — | ctx_3c0f1e807aea | succeeded; released (user: "i dont like sun") |

## Verdicts
- onb-hero: accepted (style anchor; paper fibre, palette, no text)
- onb-private: accepted
- app-icon: accepted (full-bleed terracotta, no alpha)
- sol-mark: accepted as fallback; too pale at 40 pt → redo requested as sol-mark-v2
- sol-mark-v2: accepted — terracotta core reads clearly at 40 pt; ships as `sol-mark`
- cover-daily / cover-work / cover-gratitude / cover-reflections: accepted (bookcloth, lower-third emblems, plain label area)
- onb-notice / onb-find / empty-journal / empty-discover / empty-search / ai-unavailable: accepted (consistent with anchor)
- sample-ceramics: accepted (photo, sample journal only)
- mode-free / mode-dump / mode-guided / mode-photo / kind-feeling / kind-situation / kind-helped / kind-topic / streak-sprout / tonight-ornament: accepted (bold single shapes, read at 28–40 pt)
- reminder-scene: accepted (quiet upper third for the clock)
- paper-grain: dropped — so low-contrast it adds nothing at 25% opacity (spec §8 allows dropping)
- sol-hello / sol-thinking / sol-listening / sol-reflect / sol-resting: accepted — same sun, character through pose only, reads at small size
- Wave 4 tortoise (sol-mark, sol-hello, sol-listening, sol-thinking, sol-reflect, sol-resting): accepted — one consistent character (spectacles, terracotta scarf, sage shell); sol-mark cropped to head-and-scarf for avatar legibility; replaces the paper-sun set

## Wave 5: story video scenes

Run: `run_e4f72b2bf65d`

| Wave | Task | Dispatch | Status |
|---|---|---|---|
| 5 story scenes | task_ebc4b357f028 | ctx_168455ae85cf | succeeded; release reported `retained` (user_takeover) |

Verdicts (each checked on a contact sheet with the 16:9 crop and the phone's right third marked):
- story-night: accepted variant a. Moon, blank clock face, closed journal, phone glow on the duvet; faceless figure; right third plain wall.
- story-writing: accepted variant a. Same room, open journal with space above it; she sits up with the phone.
- story-dawn: accepted variant a. Same room, bed made and empty, peach light through the window.
- Room match: a 50% blend of night-a with writing-a and with dawn-a shows window, nightstand, clock and bed on the same pixels (no doubling), so the dissolves are clean.
- story-dusk: accepted variant a. Two faceless women walking right under paper trees, sunset band, figures inside the left two-thirds.
- story-morning: accepted variant a. The two women walk right at x ≈ 590–890; the path behind them at the left (x 120–420, y 820–880) is empty for Sol; wildflowers; right third is meadow and sky.
- Variants b were near-identical in composition; a was chosen as one consistent set.
