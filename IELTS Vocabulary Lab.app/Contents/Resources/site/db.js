(() => {
  "use strict";

  const DB_NAME = "ielts-vocabulary-lab-sqlite-v1";
  const DB_STORE = "snapshots";
  const SNAPSHOT_KEY = "main";
  const LEGACY_KEYS = [
    "ielts-vocabulary-lab-records-v1",
    "ielts-vocabulary-lab-progress-v1",
    "ielts-vocabulary-lab-practice-v1",
  ];
  const words = Array.isArray(window.IELTS_WORDS) ? window.IELTS_WORDS : [];

  const schemaSql = `
    PRAGMA foreign_keys = ON;
    CREATE TABLE IF NOT EXISTS metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS words (
      id TEXT PRIMARY KEY,
      week INTEGER NOT NULL,
      day INTEGER NOT NULL,
      day_title TEXT NOT NULL,
      term TEXT NOT NULL,
      ipa TEXT NOT NULL,
      part_of_speech TEXT NOT NULL,
      meaning_zh TEXT NOT NULL,
      collocations_json TEXT NOT NULL,
      example_en TEXT NOT NULL,
      example_zh TEXT NOT NULL,
      word_family TEXT NOT NULL,
      note TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS word_progress (
      word_id TEXT PRIMARY KEY,
      attempts INTEGER NOT NULL DEFAULT 0,
      correct INTEGER NOT NULL DEFAULT 0,
      wrong INTEGER NOT NULL DEFAULT 0,
      streak INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at TEXT,
      next_review_at TEXT,
      history_json TEXT NOT NULL DEFAULT '[]',
      FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS exams (
      id TEXT PRIMARY KEY,
      score INTEGER NOT NULL,
      total INTEGER NOT NULL,
      correct INTEGER NOT NULL,
      results_json TEXT NOT NULL,
      config_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS practice_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mode TEXT NOT NULL,
      prompt TEXT NOT NULL,
      response TEXT NOT NULL,
      rating INTEGER NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_word_progress_next_review ON word_progress(next_review_at);
    CREATE INDEX IF NOT EXISTS idx_exams_created_at ON exams(created_at);
    CREATE INDEX IF NOT EXISTS idx_practice_created_at ON practice_records(created_at);
  `;

  const defaults = () => ({
    attempts: 0,
    correct: 0,
    wrong: 0,
    streak: 0,
    level: 0,
    lastReviewedAt: null,
    nextReviewAt: null,
    history: [],
  });

  function parseJson(value, fallback) {
    try {
      const parsed = JSON.parse(value);
      return parsed ?? fallback;
    } catch {
      return fallback;
    }
  }

  function readLegacy(key, fallback) {
    try { return parseJson(localStorage.getItem(key) || "", fallback); } catch { return fallback; }
  }

  function openIndexedDb() {
    if (!window.indexedDB) return Promise.resolve(null);
    return new Promise((resolve) => {
      let request;
      try { request = indexedDB.open(DB_NAME, 1); } catch { resolve(null); return; }
      request.onupgradeneeded = () => {
        if (!request.result.objectStoreNames.contains(DB_STORE)) request.result.createObjectStore(DB_STORE);
      };
      request.onerror = () => resolve(null);
      request.onsuccess = () => resolve(request.result);
    });
  }

  function readSnapshot(idb) {
    if (!idb) return Promise.resolve(null);
    return new Promise((resolve) => {
      try {
        const request = idb.transaction(DB_STORE, "readonly").objectStore(DB_STORE).get(SNAPSHOT_KEY);
        request.onerror = () => resolve(null);
        request.onsuccess = () => resolve(request.result ? new Uint8Array(request.result) : null);
      } catch { resolve(null); }
    });
  }

  function saveSnapshot(idb, bytes) {
    if (!idb) return Promise.resolve(false);
    return new Promise((resolve) => {
      try {
        const request = idb.transaction(DB_STORE, "readwrite").objectStore(DB_STORE).put(bytes, SNAPSHOT_KEY);
        request.onerror = () => resolve(false);
        request.onsuccess = () => resolve(true);
      } catch { resolve(false); }
    });
  }

  function tableCount(db, table) {
    try { return db.exec(`SELECT COUNT(*) AS count FROM ${table}`)[0]?.values[0][0] || 0; } catch { return 0; }
  }

  function seedWords(db) {
    if (!words.length) return;
    db.run("BEGIN TRANSACTION");
    try {
      for (const word of words) {
        db.run(
          `INSERT OR IGNORE INTO words
            (id, week, day, day_title, term, ipa, part_of_speech, meaning_zh, collocations_json, example_en, example_zh, word_family, note)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [word.id, word.week, word.day, word.dayTitle, word.term, word.ipa, word.partOfSpeech, word.meaningZh, JSON.stringify(word.collocations || []), word.exampleEn, word.exampleZh, word.wordFamily || "", word.note || ""],
        );
      }
      db.run("COMMIT");
    } catch (error) {
      db.run("ROLLBACK");
      throw error;
    }
  }

  function progressMapFromDb(db) {
    const progress = {};
    const result = db.exec("SELECT word_id, attempts, correct, wrong, streak, level, last_reviewed_at, next_review_at, history_json FROM word_progress");
    for (const row of result[0]?.values || []) {
      progress[row[0]] = {
        attempts: Number(row[1]) || 0,
        correct: Number(row[2]) || 0,
        wrong: Number(row[3]) || 0,
        streak: Number(row[4]) || 0,
        level: Number(row[5]) || 0,
        lastReviewedAt: row[6] || null,
        nextReviewAt: row[7] || null,
        history: parseJson(row[8], []),
      };
    }
    return progress;
  }

  function writeProgressMap(db, progress) {
    db.run("BEGIN TRANSACTION");
    try {
      for (const [wordId, raw] of Object.entries(progress || {})) {
        const item = { ...defaults(), ...raw };
        db.run(
          `INSERT OR REPLACE INTO word_progress
            (word_id, attempts, correct, wrong, streak, level, last_reviewed_at, next_review_at, history_json)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [wordId, item.attempts, item.correct, item.wrong, item.streak, item.level, item.lastReviewedAt, item.nextReviewAt, JSON.stringify(item.history || [])],
        );
      }
      db.run("COMMIT");
    } catch (error) {
      db.run("ROLLBACK");
      throw error;
    }
  }

  function recordsFromDb(db) {
    const result = db.exec("SELECT id, score, total, correct, results_json, config_json, created_at FROM exams ORDER BY created_at DESC");
    return (result[0]?.values || []).map((row) => ({
      id: row[0], score: Number(row[1]) || 0, total: Number(row[2]) || 0, correct: Number(row[3]) || 0,
      results: parseJson(row[4], []), config: parseJson(row[5], {}), createdAt: row[6],
    }));
  }

  function practiceFromDb(db) {
    const result = db.exec("SELECT mode, prompt, response, rating, created_at FROM practice_records ORDER BY created_at DESC");
    return (result[0]?.values || []).map((row) => ({ mode: row[0], prompt: row[1], response: row[2], rating: Number(row[3]) || 0, createdAt: row[4] }));
  }

  function makeFallback() {
    const progressKey = "ielts-vocabulary-lab-progress-v1";
    const recordsKey = "ielts-vocabulary-lab-records-v1";
    const practiceKey = "ielts-vocabulary-lab-practice-v1";
    const fallback = {
      backend: "memory-fallback",
      getProgressMap: () => readLegacy(progressKey, {}),
      saveProgressMap: (progress) => { try { localStorage.setItem(progressKey, JSON.stringify(progress)); } catch {} },
      getExamRecords: () => readLegacy(recordsKey, []),
      addExamRecord: (record) => { const records = readLegacy(recordsKey, []); records.unshift(record); try { localStorage.setItem(recordsKey, JSON.stringify(records.slice(0, 20))); } catch {} },
      getPracticeRecords: () => readLegacy(practiceKey, []),
      addPracticeRecord: (record) => { const records = readLegacy(practiceKey, []); records.unshift(record); try { localStorage.setItem(practiceKey, JSON.stringify(records.slice(0, 50))); } catch {} },
      exportBytes: () => null,
      importBytes: async () => false,
      download: () => false,
      getStats: (allWords) => summarize(fallback.getProgressMap(), fallback.getExamRecords(), fallback.getPracticeRecords(), allWords),
    };
    return fallback;
  }

  function summarize(progress, exams, practice, allWords) {
    const now = new Date();
    const wordsByWeek = {};
    for (const word of allWords || []) {
      const item = progress[word.id];
      const bucket = wordsByWeek[word.week] ||= { week: word.week, total: 0, learned: 0, mastered: 0, due: 0 };
      bucket.total += 1;
      if (item?.lastReviewedAt) bucket.learned += 1;
      if ((item?.level || 0) >= 4) bucket.mastered += 1;
      if (!item?.nextReviewAt || new Date(item.nextReviewAt) <= now) bucket.due += 1;
    }
    const scores = (exams || []).map((record) => Number(record.score) || 0);
    return {
      totalWords: (allWords || []).length,
      learned: Object.values(progress || {}).filter((item) => item.lastReviewedAt).length,
      mastered: Object.values(progress || {}).filter((item) => item.level >= 4).length,
      due: (allWords || []).filter((word) => !progress[word.id]?.nextReviewAt || new Date(progress[word.id].nextReviewAt) <= now).length,
      exams: (exams || []).length,
      attempts: (exams || []).reduce((sum, record) => sum + (Number(record.total) || 0), 0),
      averageScore: scores.length ? Math.round(scores.reduce((sum, score) => sum + score, 0) / scores.length) : null,
      bestScore: scores.length ? Math.max(...scores) : null,
      practice: (practice || []).length,
      weeks: Object.values(wordsByWeek),
    };
  }

  async function initialize() {
    if (typeof window.initSqlJs !== "function") return makeFallback();
    const idb = await openIndexedDb();
    // SQLite snapshots need IndexedDB for persistence. Keep the legacy backend
    // when it is unavailable so a private/blocked browser cannot lose progress.
    if (!idb) return makeFallback();
    const SQL = await window.initSqlJs({
      locateFile: (file) => new URL(file, new URL("vendor/", document.baseURI)).toString(),
    });
    const stored = await readSnapshot(idb);
    let db;
    if (stored) {
      db = new SQL.Database(stored);
    } else {
      try {
        const response = await fetch("data/ielts-vocab.sqlite", { cache: "no-store" });
        if (!response.ok) throw new Error(`Seed database returned ${response.status}`);
        db = new SQL.Database(new Uint8Array(await response.arrayBuffer()));
      } catch {
        db = new SQL.Database();
      }
    }
    db.exec(schemaSql);
    seedWords(db);

    const hasMigrated = db.exec("SELECT value FROM metadata WHERE key = 'legacy_migration_v1'")[0]?.values[0]?.[0] === "done";
    let migratedLegacy = false;
    if (!hasMigrated) {
      const legacyProgress = readLegacy(LEGACY_KEYS[1], {});
      const legacyRecords = readLegacy(LEGACY_KEYS[0], []);
      const legacyPractice = readLegacy(LEGACY_KEYS[2], []);
      if (!tableCount(db, "word_progress") && Object.keys(legacyProgress).length) writeProgressMap(db, legacyProgress);
      if (!tableCount(db, "exams") && legacyRecords.length) {
        for (const record of legacyRecords) insertExam(db, record);
      }
      if (!tableCount(db, "practice_records") && legacyPractice.length) {
        for (const record of legacyPractice) insertPractice(db, record);
      }
      db.run("INSERT OR REPLACE INTO metadata (key, value) VALUES ('legacy_migration_v1', 'done')");
      migratedLegacy = true;
    }
    const api = {
      backend: "sqlite-wasm",
      getProgressMap: () => progressMapFromDb(db),
      saveProgressMap: (progress) => { writeProgressMap(db, progress); queuePersist(); },
      getExamRecords: () => recordsFromDb(db),
      addExamRecord: (record) => { insertExam(db, record); queuePersist(); },
      getPracticeRecords: () => practiceFromDb(db),
      addPracticeRecord: (record) => { insertPractice(db, record); queuePersist(); },
      exportBytes: () => db.export(),
      importBytes: async (bytes) => {
        const imported = new SQL.Database(bytes);
        imported.exec(schemaSql);
        seedWords(imported);
        const previous = db;
        clearTimeout(persistTimer);
        db = imported;
        const persisted = await persist();
        if (!persisted) {
          db = previous;
          imported.close();
          throw new Error("Unable to persist imported database snapshot");
        }
        previous.close();
        return true;
      },
      download: () => {
        const blob = new Blob([db.export()], { type: "application/vnd.sqlite3" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `ielts-vocab-${new Date().toISOString().slice(0, 10)}.sqlite`;
        link.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        return true;
      },
      getStats: () => summarize(progressMapFromDb(db), recordsFromDb(db), practiceFromDb(db), words),
    };
    let persistTimer = null;
    let persistChain = Promise.resolve();
    function persist() {
      if (!idb) return Promise.resolve(false);
      const bytes = db.export();
      persistChain = persistChain.then(() => saveSnapshot(idb, bytes));
      return persistChain;
    }
    function queuePersist() {
      clearTimeout(persistTimer);
      persistTimer = setTimeout(() => { persist(); }, 20);
    }
    window.addEventListener("pagehide", () => { persist(); }, { once: false });
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") persist();
    });
    const persisted = await persist();
    if (!persisted) {
      // Do not delete the source data unless the SQLite snapshot is durable.
      return makeFallback();
    }
    if (migratedLegacy) {
      for (const key of LEGACY_KEYS) { try { localStorage.removeItem(key); } catch {} }
    }
    return api;
  }

  function insertExam(db, record) {
    const id = record.id || `exam-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    db.run(
      `INSERT OR REPLACE INTO exams (id, score, total, correct, results_json, config_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, record.score, record.total, record.correct, JSON.stringify(record.results || []), JSON.stringify(record.config || {}), record.createdAt || new Date().toISOString()],
    );
  }

  function insertPractice(db, record) {
    db.run(
      `INSERT INTO practice_records (mode, prompt, response, rating, created_at) VALUES (?, ?, ?, ?, ?)`,
      [record.mode, record.prompt, record.response, record.rating, record.createdAt || new Date().toISOString()],
    );
  }

  window.IELTSDatabaseReady = initialize().catch((error) => {
    console.error("SQLite initialization failed; using browser fallback.", error);
    return makeFallback();
  });
})();
