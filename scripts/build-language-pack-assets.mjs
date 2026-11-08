import { readFile, writeFile } from "node:fs/promises";

const directory = new URL("../data/language-packs/", import.meta.url);
const manifest = JSON.parse(await readFile(new URL("manifest.json", directory), "utf8"));
await writeFile(new URL("manifest.js", directory), "window.IELTS_LANGUAGE_MANIFEST = " + safeJson(manifest) + ";\n");

for (const locale of manifest.locales) {
  const pack = JSON.parse(await readFile(new URL(locale.file, directory), "utf8"));
  if (pack.locale !== locale.locale) throw new Error("Locale mismatch in " + locale.file);
  const script = "window.IELTS_LANGUAGE_PACKS = window.IELTS_LANGUAGE_PACKS || {}; window.IELTS_LANGUAGE_PACKS[" +
    JSON.stringify(locale.locale) + "] = " + safeJson(pack) + ";\n";
  await writeFile(new URL(locale.locale + ".js", directory), script);
}

console.log("Built " + manifest.locales.length + " offline language pack assets.");

function safeJson(value) {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}
