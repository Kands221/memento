// Text shared by every ad, in the browser (scene) and in Node (render, voice):
// the OpenMoji names a timeline may use, the rich-text tokenizer, and the
// variant filter for timelines that cut several hooks from one body.

export const EMOJI = {
  sob: "1F62D",
  owl: "1F989",
  eyes: "1F440",
  bulb: "1F4A1",
  calendar: "1F4C5",
  pray: "1F64F",
  sparkles: "2728",
  fire: "1F525",
  muscle: "1F4AA",
  heart: "1F9E1",
  point_down: "1F447",
  thinking: "1F914",
  sweat_smile: "1F605",
  check: "2705",
  star: "2B50",
  books: "1F4DA",
  target: "1F3AF",
  clap: "1F44F",
  wave: "1F44B",
  party: "1F389",
  cap: "1F393",
  hundred: "1F4AF",
};

export const EMOJI_RE = /:[a-z_]+:/;

// Visible units of a message: one per character, one per emoji, one per break.
// **bold**, *highlight*, :emoji:, and a pilcrow for a paragraph break.
export function tokenize(text) {
  const units = [];
  let style = "plain";
  const re = /(\*\*|\*|:[a-z_]+:|¶)/g;
  let last = 0;
  const pushText = (s) => {
    for (const ch of s) units.push({ kind: "char", ch, style });
  };
  for (const m of text.matchAll(re)) {
    pushText(text.slice(last, m.index));
    const tok = m[0];
    if (tok === "**") style = style === "bold" ? "plain" : "bold";
    else if (tok === "*") style = style === "hl" ? "plain" : "hl";
    else if (tok === "¶") units.push({ kind: "break" });
    else if (EMOJI[tok.slice(1, -1)]) units.push({ kind: "emoji", code: EMOJI[tok.slice(1, -1)], style });
    else pushText(tok);
    last = m.index + tok.length;
  }
  pushText(text.slice(last));
  return units;
}

// Entries without a `variant` belong to every cut.
export const forVariant = (list, variant) => (list ?? []).filter((e) => !e.variant || e.variant === variant);

export const plain = (s) => s.replace(/\*/g, "").replace(/:[a-z_]+:/g, "").trim();
