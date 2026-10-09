// Invariants every ad timeline must hold, checked by check.test.mjs and before a render:
// scenes cover the whole video without gaps, footage segments are contiguous, voice lines don't overlap and
// have known speakers, and every cue lies inside the video.

const EPS = 0.001;

export function checkTimeline(tl) {
  const problems = [];
  const D = tl.DURATION;
  const inside = (t) => t >= -EPS && t <= D + EPS;

  const scenes = [...(tl.SCENES ?? [])].sort((a, b) => a.from - b.from);
  if (scenes.length) {
    if (scenes[0].from > EPS) problems.push(`SCENES start at ${scenes[0].from}s, not 0`);
    const end = Math.max(...scenes.map((s) => s.to));
    if (end < D - EPS) problems.push(`SCENES end at ${end}s, before the video's end (${D}s)`);
    scenes.forEach((s, i) => {
      if (!(s.to > s.from)) problems.push(`scene ${s.id}: to must be after from`);
      const next = scenes[i + 1];
      const covered = Math.max(...scenes.slice(0, i + 1).map((x) => x.to));
      if (next && next.from > covered + EPS) problems.push(`gap between scenes before ${next.id} (${covered}s to ${next.from}s)`);
    });
  }

  const segs = [...(tl.SEGMENTS ?? [])].sort((a, b) => a.at - b.at);
  segs.forEach((s, i) => {
    if (!(s.to > s.at)) problems.push(`segment ${s.id}: to must be after at`);
    if (!inside(s.at) || !inside(s.to)) problems.push(`segment ${s.id}: outside 0 to ${D}s`);
    if (!(s.rate > 0)) problems.push(`segment ${s.id}: rate must be positive`);
    const next = segs[i + 1];
    if (next && Math.abs(next.at - s.to) > EPS) problems.push(`segments ${s.id}/${next.id} are not contiguous (${s.to}s vs ${next.at}s)`);
  });

  const vo = tl.VO ?? [];
  vo.forEach((v, i) => {
    if (!tl.VOICES?.[v.who]) problems.push(`VO line ${i + 1}: unknown speaker ${v.who}`);
    if (!(v.to > v.from)) problems.push(`VO line ${i + 1}: to must be after from`);
    if (!inside(v.from) || !inside(v.to)) problems.push(`VO line ${i + 1}: outside 0 to ${D}s`);
    const next = vo[i + 1];
    if (next && next.from < v.to - EPS) problems.push(`VO lines ${i + 1} and ${i + 2} overlap`);
  });

  for (const [name, list, key] of [["SFX", tl.SFX, "t"], ["CHIPS", tl.CHIPS, "from"], ["CAPTIONS", tl.CAPTIONS, "from"]]) {
    for (const cue of list ?? []) if (!inside(cue[key])) problems.push(`${name} cue at ${cue[key]}s is outside the video`);
  }
  return problems;
}
