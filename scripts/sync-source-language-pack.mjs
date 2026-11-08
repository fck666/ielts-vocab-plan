import { readFile, writeFile } from "node:fs/promises";

const words = JSON.parse(await readFile(new URL("../data/words.json", import.meta.url), "utf8"));
const pack = {
  locale: "zh-CN",
  version: 1,
  direction: "ltr",
  words: Object.fromEntries(words.map((word) => [word.id, {
    dayTitle: word.dayTitle,
    meaning: word.meaningZh,
    exampleTranslation: word.exampleZh,
    note: word.note,
    wordFamily: word.wordFamily || "",
  }])),
  ui: {},
};

await writeFile(new URL("../data/language-packs/zh-CN.json", import.meta.url), JSON.stringify(pack, null, 2) + "\n");
await import("./build-language-pack-assets.mjs");
console.log("Wrote " + Object.keys(pack.words).length + " source-language entries.");
