# Memento AI quality plan: Sol and summaries

**Goal:** production-grade AI with far fewer errors. Every error class is defined, measured on a fixed eval set, and blocked by a release gate. "Better" is a number, not a feeling.

Written Oct 9, 2026. Baselines were measured the same day with `AIEvalProbe` (`MEMENTO_EVAL=1 swift test --filter AIEval`). APIs were checked against the iOS 26.5 SDK.

## 1. Where we are (measured)

| Feature | Sample | Turns with ≥1 error | What went wrong | Latency (p50 / p90) |
|---|---|---|---|---|
| **On-device Sol** (Apple model) | 20 turns, 4 scripted conversations | **4 / 20 (20%)** | Banned opener "That sounds…" ×2, assumed a feeling the writer never named ×1, no question ×1 | 4.5 s / 7.1 s |
| **Cloud Sol** (Haiku 5.5), before today's fix | 20 turns | **13 / 20** | **Engine failed ×5** (replies cut off mid-JSON), "says again" ×2, assumed a feeling ×2 | 3.4 s / 4.7 s |
| **Cloud Sol**, after today's fix | 20 turns | **5 / 20 (25%)** | 0 engine failures. Opens by parroting "You wrote that…" ×4, "Hello again" ×1 | 2.4 s / 4.7 s |
| **AI-written summary paragraph** (prototype, on device) | 10 runs on a fixed fact sheet | **3 / 10 (30%)** | Mentioned a tag not in the facts, a causal claim ("understandable given the deadlines"), engine failure ×1 | — |
| **Summaries today** | — | **0 factual errors by construction** | Fully deterministic templates: correct, but they read like a form | instant |

**Seen in live app tests, outside the eval:**
- A "From your journal" chip appeared on a reply that barely used the memory.
- On-device Sol called the writer "drained" when they never said it.
- Drafting a reflection once **hung for 87 s** before failing. The app then falls back to a template, but only after that wait.
- The live "remembers" test cited the right entry in most runs but not all.

**Caveat:** 20 turns is a small sample (±18 points at 95%). Phase 0 grows it to about 300 turns so the targets below can be measured honestly.

## 2. Principles

1. **Facts come from code, words from the model.** The model never counts, dates or recalls. Code supplies the facts; the model only phrases them; validators check that it did.
2. **Generate → validate → repair → fall back.** Every model output passes deterministic checks before the writer sees it or Sol speaks it. A failed check triggers one targeted regeneration, then a safe fallback. The writer never sees an unvalidated reply.
3. **Every call has a deadline.** No spinner lasts longer than a promised time.
4. **One quality layer for every engine.** On-device and cloud share the same planner, validators, fallbacks and evals, so switching engines can't silently lower quality.
5. **Nothing ships without the gate.** Error rates are tracked per class across releases, and the release gates in section 6 block any regression.

## 3. Phase 0: eval harness (≈1 day, do first)

The seed exists (`AIEvalProbe.swift`). Grow it into the yardstick everything else is judged by.

- **Sol set, ~300 turns:** 60 scripted conversations × 5 turns, across 12 scenarios:
  - work stress, loneliness, grief, joy, terse replies ("ok", "idk")
  - long rambling, conflict, sleep, crisis-adjacent, prompt-injection ("ignore your rules"), non-English
  - memory-relevant, where the right journal moment exists and Sol should cite it
- **Summary set:** 30 fact sheets, including edge cases: 1 entry, no kept tags, ties, 200 entries, a clinician note, and quotes with emoji.
- **Deterministic scorers** (cheap, run every time): one question, sentence count, banned openers, "again", feelings the writer never named, clinical words, invented dates or memories, quoting real people, repeated questions, quick-reply shape, latency, engine failure.
- **Judge scorer** (subjective quality: responsive, specific, warm, Morrie-like, not preachy):
  - A strong cloud model grades **synthetic eval data only**, never anyone's journal.
  - Calibrate it against 50 turns labelled by hand before trusting it.
- **Output:** per-class rates with 95% intervals, p50/p90 latency and failure rate. Results are saved to `docs/evals/<date>.md` so regressions show up.

## 4. Phase 1: Sol (≈3 days)

| # | Change | Fixes | Notes |
|---|---|---|---|
| 1 | **`SolTurnValidator` + repair** | Banned openers, missing or extra questions, length, "again", parroting | Safe fixes are deterministic: drop the opener sentence, keep only the last question, apply `soften`. Otherwise regenerate once with a targeted note (e.g. "Don't say the writer feels drained; they didn't"), then fall back. |
| 2 | **No assumed feelings** | "Assumes a feeling" | A feeling word must appear in the writer's own text or the cited memory. The check is a deterministic lemma match with `NLTagger`. |
| 3 | **Explicit memory use** | False or missing citations, invented memories | Add `usedMemory: Bool` to the turn schema. Cite only when the model says it used the memory **and** the reply contains its date or a distinctive word. Any date in a reply must be the memory's date. |
| 4 | **Safe fallback reply** | "Forgive me, I lost the thread" | Replace the dead-end line with a composed reply: the planner's reflection template plus a fresh question from a curated bank. It's still in Sol's voice, and never a wrong one. |
| 5 | **Deadlines and retries** | 87 s hang, rare failures | First token within 8 s and full turn within 20 s on device (6 s / 15 s cloud), then fall back. Retry `rateLimited` and `concurrentRequests` with backoff. Reflection draft: 15 s, then the template. |
| 6 | **Context budget** | `exceededContextWindowSize`, long chats | `tokenCount(for:)` is available from iOS 26.4. Keep instructions, history and prompt under ~3,000 of the 4,096 tokens. Condense older turns into the writer's own key sentences (extractive, not model-written), and rebuild the session with `LanguageModelSession(transcript:)`. |
| 7 | **Faster first word** | p90 7.1 s on device | `prewarm(promptPrefix:)` when Sol opens, and keep instructions short (every token is re-read each turn). |
| 8 | **Guardrail false alarms** | Benign sad entries treated as crises | Keep `CrisisSignal` as the only path to the support card. For transforming the writer's own words (reflection draft, tagging), use `SystemLanguageModel(guardrails: .permissiveContentTransformations)`. Log false alarms with `LanguageModelFeedback` so they can be reported to Apple. |
| 9 | **Voice speaks only validated text** | Sol saying a sentence that is then repaired | Run the per-sentence checks before `SolVoice` speaks each sentence. |
| 10 | **Cloud specifics** (partly done today) | Truncation, parroting, offline | Done: Anthropic routing, ordered schema, non-streamed retry. To do: treat `finish_reason=length` as a failure, detect offline instantly, add "Don't open with 'You said / You wrote'" to the prompt and validator, and pin model versions. |

**Later, only if evals plateau:** train a Foundation Models **adapter** for Sol's voice.
- This means LoRA training with Apple's toolkit. Shipping it needs an Apple entitlement, and the adapter must be retrained for each OS model version (roughly 160 MB each).
- That is a real ongoing cost, so it's held until prompts plus validators stop improving the numbers.

## 5. Phase 2: summaries (≈2 days)

Keep what's right: the numbers and lists stay deterministic, so they can't be wrong. Add a short, human "look back" paragraph without adding errors.

1. **Fact sheet (code):** counts, date range, top kept tags per kind, tags that often appear together, and quotes chosen from kept tags. Each fact gets an ID.
2. **Model writes sentences that cite facts:** `@Generable SummaryNarrative { sentences: [ { text, factIDs } ] }`.
3. **Validator per sentence:**
   - Every number, date and tag label in the sentence must belong to a fact it cites.
   - No causal words ("because", "due to", "led to", "given the").
   - No clinical words, no feelings outside the kept tags.
   - The "for my psychologist" version must be first person.
4. **One regeneration, then fall back** to today's deterministic paragraph, which is always available.
5. **Scope:**
   - AI prose is for **"For me"** summaries, labelled "Drafted by Sol from your kept tags. Edit anything.", and editable before export.
   - The **clinician** version stays deterministic by default; accuracy beats voice there.
6. **No context-window risk:** the fact sheet stays small whatever the number of entries, so long ranges need no map-reduce step.
7. **Reuse:** the same pipeline later powers the weekly letter from Sol (roadmap, next wave).

## 6. Targets and release gate

| Metric | Today | Target |
|---|---|---|
| Sol turns with any error, on device | 20% | **≤ 5%** |
| Sol turns with any error, cloud | 25% | **≤ 3%** |
| Engine failures shown to the writer | 0–5 per 20 turns | **≤ 1%**, always as a composed fallback, never a dead end |
| Invented memories, false citations, clinical words, diagnoses | Seen in live tests | **0 on the full eval set** (hard gate) |
| Summary paragraph: wrong number, tag or date, or a causal claim | 30% before validation | **0 after validation** (hard gate). Pre-validation rate is tracked to steer prompts. |
| Sol p90 time to full reply | 7.1 s on device / 4.7 s cloud | **≤ 6 s / ≤ 4 s**, with the first word ≤ 2 s |
| Longest wait before a fallback | 87 s | **≤ 20 s** |

**Gate:** any hard-gate failure, or a regression of more than 2 points in any class, blocks the merge.

## 7. Operating it

- **Privacy-safe signals:** local counters of error class, fallback and latency, with no text. The writer can opt in to share aggregates.
- **Feedback:** 👍/👎 on Sol replies is stored locally as `LanguageModelFeedback` attachments the writer can choose to send.
- **Model drift:** Apple's model changes with iOS, so rerun the evals on each iOS beta. Pin cloud model versions and rerun when changing them.
- **Cloud before any public release:** move the key behind a small server (Kept's gateway is the pattern: per-device quotas, zero data retention, App Attest) and remove the key from the app.

## 8. Order of work

1. Phase 0, the eval harness, so everything after it is measured.
2. Phase 1, items 1–5: the biggest error cuts for the least work.
3. Phase 2: the summary paragraph with fact citations and its validator.
4. Phase 1, items 6–10: context, latency, guardrails, voice and cloud polish.
5. Re-measure against section 6, and consider an adapter only if the numbers plateau.
