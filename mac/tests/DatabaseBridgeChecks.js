const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const initializeSqlJs = require("../../vendor/sql-wasm.js");

async function main() {
  const root = path.resolve(__dirname, "../..");
  const SQL = await initializeSqlJs({ locateFile: (file) => path.join(root, "vendor", file) });
  const seed = new Uint8Array(fs.readFileSync(path.join(root, "data/ielts-vocab.sqlite")));
  const words = JSON.parse(fs.readFileSync(path.join(root, "data/words.json"), "utf8"));
  let snapshot = seed;
  let exportedFile = null;
  const databaseHandler = {
    async postMessage(message) {
      if (message.action === "load") {
        return { ok: true, base64: Buffer.from(snapshot).toString("base64") };
      }
      if (message.action === "save") {
        snapshot = Uint8Array.from(Buffer.from(message.base64, "base64"));
        return { ok: true };
      }
      return { ok: false, error: "Unknown database action" };
    },
  };
  const fileHandler = {
    async postMessage(message) {
      exportedFile = message;
      return { ok: true };
    },
  };
  const document = {
    baseURI: "file:///IELTSVocabularyLab/",
    visibilityState: "visible",
    addEventListener() {},
    querySelector() { return null; },
    createElement() { return { setAttribute() {}, style: {}, remove() {} }; },
    body: { prepend() {} },
  };
  const window = {
    IELTS_WORDS: words,
    initSqlJs: () => Promise.resolve(SQL),
    indexedDB: null,
    webkit: { messageHandlers: { ieltsDatabase: databaseHandler, ieltsFiles: fileHandler } },
    addEventListener() {},
  };
  const context = {
    window, document, URL, Uint8Array, ArrayBuffer, Date, Math, JSON, Object, Number, String,
    Promise, Error, console, setTimeout, clearTimeout,
    localStorage: { getItem() { return null; }, removeItem() {} },
    atob: (value) => Buffer.from(value, "base64").toString("binary"),
    btoa: (value) => Buffer.from(value, "binary").toString("base64"),
  };
  vm.runInNewContext(fs.readFileSync(path.join(root, "db.js"), "utf8"), context, { filename: "db.js" });
  const database = await window.IELTSDatabaseReady;
  assert.equal(database.backend, "sqlite-wasm");
  assert.equal(database.getStats().totalWords, 6000);

  database.saveProgressMap({ [words[0].id]: {
    attempts: 2, correct: 1, wrong: 1, streak: 0, level: 2,
    lastReviewedAt: "2026-10-31T00:00:00.000Z", nextReviewAt: "2026-11-01T00:00:00.000Z", history: [],
  } });
  database.addExamRecord({ id: "bridge-test", score: 50, total: 2, correct: 1, results: [], config: {} });
  database.addPracticeRecord({ mode: "speaking", prompt: "test", response: "test", rating: 3 });
  assert.equal(await database.flush(), true);

  let persisted = new SQL.Database(snapshot);
  assert.equal(persisted.exec("SELECT level FROM word_progress")[0].values[0][0], 2);
  assert.equal(persisted.exec("SELECT COUNT(*) FROM exams")[0].values[0][0], 1);
  assert.equal(persisted.exec("SELECT COUNT(*) FROM practice_records")[0].values[0][0], 1);
  persisted.close();

  await assert.rejects(database.importBytes(new Uint8Array([1, 2, 3])));
  assert.equal(database.getProgressMap()[words[0].id].level, 2);
  await database.download();
  assert.equal(exportedFile.action, "saveDatabase");
  await database.importBytes(seed);
  assert.equal(database.getProgressMap()[words[0].id], undefined);

  persisted = new SQL.Database(snapshot);
  assert.equal(persisted.exec("PRAGMA integrity_check")[0].values[0][0], "ok");
  assert.equal(persisted.exec("SELECT COUNT(*) FROM words")[0].values[0][0], 6000);
  assert.match(persisted.exec("SELECT example_source FROM words WHERE id = 'w11-d71-01'")[0].values[0][0], /Tatoeba/);
  assert.match(persisted.exec("SELECT exam_tags_json FROM words WHERE id = 'w11-d71-01'")[0].values[0][0], /IELTS/);
  persisted.close();
  console.log("Database bridge checks passed: 6000-word seed, attribution migration, atomic persistence, import rollback and export.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
