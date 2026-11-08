import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const [words, manifest] = await Promise.all([
  readJson(new URL("data/words.json", root)),
  readJson(new URL("data/language-packs/manifest.json", root)),
]);
const wordIds = new Set(words.map((word) => word.id));
const errors = [];

if (!manifest.locales.some((item) => item.locale === manifest.sourceLocale && item.status === "source")) {
  errors.push("Source locale " + manifest.sourceLocale + " must be marked as source.");
}

const coverage = [];
const draftCoverage = [];
for (const locale of manifest.locales) {
  let pack;
  try {
    pack = await readJson(new URL("data/language-packs/" + locale.file, root));
  } catch (error) {
    errors.push(locale.locale + ": " + error.message);
    continue;
  }
  if (pack.locale !== locale.locale) errors.push(locale.locale + ": pack locale does not match manifest.");
  if (pack.direction !== locale.direction) errors.push(locale.locale + ": direction does not match manifest.");
  if (locale.status === "draft") draftCoverage.push({ locale: locale.locale, count: Object.keys(pack.words || {}).length });
  for (const id of wordIds) {
    if (locale.status === "draft") break;
    const entry = pack.words?.[id];
    if (!entry || ["dayTitle", "meaning", "exampleTranslation", "note", "wordFamily"].some((key) => typeof entry[key] !== "string")) {
      errors.push(locale.locale + ": missing required translation fields for " + id + ".");
    }
  }
  for (const [id, entry] of Object.entries(pack.words || {})) {
    if (!wordIds.has(id)) errors.push(locale.locale + ": unknown word id " + id + ".");
    if (!entry || ["dayTitle", "meaning", "exampleTranslation", "note", "wordFamily"].some((key) => typeof entry[key] !== "string" || !entry[key].trim())) {
      errors.push(locale.locale + ": incomplete draft entry for " + id + ".");
    }
  }
  if (locale.status === "ready" && !Object.keys(pack.ui || {}).length) errors.push(locale.locale + ": ready packs need reviewed UI strings.");
  coverage.push(locale.locale + " " + Object.keys(pack.words || {}).length + "/" + wordIds.size);
}

if (draftCoverage.length) {
  const counts = new Set(draftCoverage.map((item) => item.count));
  if (counts.size > 1) errors.push("Draft locales must cover the same number of source word IDs: " + draftCoverage.map((item) => item.locale + "=" + item.count).join(", ") + ".");
  for (const item of draftCoverage) {
    if (item.count !== wordIds.size) errors.push(item.locale + ": draft pack covers " + item.count + "/" + wordIds.size + " source word IDs; draft generation is incomplete.");
  }
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Language pack coverage: " + coverage.join(", ") + ".");
  console.log("Pending localization: " + manifest.locales.filter((item) => item.status === "draft").map((item) => item.locale).join(", ") + ".");
}

async function readJson(url) {
  return JSON.parse(await readFile(url, "utf8"));
}
