const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const manifest = require("../../data/language-packs/manifest.json");
const sourcePack = require("../../data/language-packs/zh-CN.json");
const values = new Map();
const context = {
  window: {},
  localStorage: {
    getItem: (key) => values.get(key) || null,
    setItem: (key, value) => values.set(key, value),
  },
};

vm.runInNewContext(fs.readFileSync("data/language-packs/manifest.js", "utf8"), context);
for (const locale of manifest.locales) {
  vm.runInNewContext(fs.readFileSync("data/language-packs/" + locale.locale + ".js", "utf8"), context);
}
vm.runInNewContext(fs.readFileSync("data/language-packs.js", "utf8"), context);
const localeApi = context.window.IELTSLocale;
assert.equal(JSON.stringify(localeApi.availableLocales().map((item) => item.locale)), JSON.stringify(["zh-CN"]));
const draftCounts = manifest.locales.filter((item) => item.status === "draft")
  .map((item) => Object.keys(context.window.IELTS_LANGUAGE_PACKS[item.locale].words).length);
assert.equal(new Set(draftCounts).size, 1, "all draft locales should have the same vocabulary coverage");
assert.equal(draftCounts[0], require("../../data/words.json").length, "every draft locale should cover every source word ID");
assert.equal(localeApi.setLocale("ja"), false, "draft packs cannot be enabled");
assert.equal(localeApi.currentLocale(), "zh-CN");
assert.equal(localeApi.setLocale("zh-CN"), true);
assert.equal(localeApi.currentLocale(), "zh-CN");

const rawWord = require("../../data/words.json")[0];
const localized = localeApi.localizeWord(rawWord);
assert.equal(localized.meaningZh, sourcePack.words[rawWord.id].meaning);
assert.equal(localized.exampleZh, sourcePack.words[rawWord.id].exampleTranslation);
assert.equal(localized.term, rawWord.term);
assert.equal(localized.id, rawWord.id);
assert.equal(manifest.locales.filter((item) => item.status === "draft").map((item) => item.locale).join(","), "ja,ko,fr,es,ar");
assert.equal(manifest.locales.find((item) => item.locale === "ar").direction, "rtl");

console.log("Language pack checks passed: source coverage, stable English IDs, draft gating, and Arabic direction.");
