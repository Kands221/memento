// Same art and footage frames as the 9:16 cut, built into this cut's build/ from memento-demo's recordings.
import path from "node:path";
import prep from "../memento-demo/prep.mjs";

export default (ad) => prep({ ...ad, dir: ad.dir, footage: path.join(ad.dir, "..", "memento-demo", "footage") });
