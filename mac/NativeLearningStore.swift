import Foundation
import Combine
import SQLite3

struct NativeWord: Decodable, Identifiable, Hashable {
    let id: String
    let week: Int
    let day: Int
    let dayTitle: String
    let term: String
    let ipa: String
    let partOfSpeech: String
    let meaningZh: String
    let collocations: [String]
    let exampleEn: String
    let exampleZh: String
    let wordFamily: String
    let note: String
    let index: Int
    let maskedExample: String?
    let examTags: [String]?

    var track: NativeVocabularyTrack {
        if week <= 10 { return .topicCore }
        return examTags?.contains("IELTS") == true ? .ieltsTagged : .otherExam
    }
}

enum NativeVocabularyTrack: String, CaseIterable, Identifiable {
    case topicCore, ieltsTagged, otherExam

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topicCore: "主题核心"
        case .ieltsTagged: "IELTS 标签扩展"
        case .otherExam: "跨考试拓展"
        }
    }

    var detail: String {
        switch self {
        case .topicCore: "按常见雅思主题编排，未逐词对应官方词表。"
        case .ieltsTagged: "来自第三方词库的 IELTS 标签，不代表官方认证。"
        case .otherExam: "带 CET-6、TOEFL 或 GRE 标签，保留作拓展查阅。"
        }
    }
}

struct NativeLearningLocation: Equatable {
    let week: Int
    let day: Int
}

struct NativeProgress: Decodable {
    var attempts: Int
    var correct: Int
    var wrong: Int
    var streak: Int
    var level: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
}

struct NativeTranslationPack: Decodable {
    struct Entry: Decodable {
        let meaning: String?
        let exampleTranslation: String?
        let note: String?
        let wordFamily: String?
    }
    let locale: String
    let words: [String: Entry]
}

struct NativeExpressionRecord: Identifiable {
    let id: Int64
    let kind: String
    let prompt: String
    let response: String
    let rating: Int
    let createdAt: Date
}

struct NativeWritingDraft: Identifiable {
    let id: String
    let week: Int
    let task: String
    let prompt: String
    var response: String
    var notes: String
    let updatedAt: Date
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@MainActor
final class NativeLearningStore: ObservableObject {
    @Published private(set) var words: [NativeWord] = []
    @Published private(set) var progress: [String: NativeProgress] = [:]
    @Published private(set) var studiedWordIDs: Set<String> = []
    @Published private(set) var expressionRecords: [NativeExpressionRecord] = []
    @Published private(set) var writingDrafts: [NativeWritingDraft] = []
    @Published private(set) var locale = UserDefaults.standard.string(forKey: "native.learning.locale") ?? "zh-CN"
    @Published private(set) var storageError: String?

    private var database: OpaquePointer?
    private var databaseURL: URL?
    private var translations: NativeTranslationPack?
    private var learningLocations: [String: NativeLearningLocation] = [:]
    private var recommendedWords: [NativeWord] = []

    init(databaseURLOverride: URL? = nil, wordsURLOverride: URL? = nil) {
        do {
            try openDatabase(urlOverride: databaseURLOverride)
            try loadCatalog(urlOverride: wordsURLOverride)
            buildLearningPath()
            try seedWords()
            try loadProgress()
            try loadStudyMarks()
            try loadExpressionRecords()
            try loadWritingDrafts()
            loadTranslations(locale)
        } catch {
            storageError = error.localizedDescription
            if words.isEmpty { words = Self.bundledWords() }
        }
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    var dueWords: [NativeWord] {
        let now = Date()
        return words.filter { word in
            guard progress[word.id]?.lastReviewedAt != nil else { return false }
            guard let date = progress[word.id]?.nextReviewAt else { return true }
            return date <= now
        }
    }

    var studiedWordCount: Int {
        studiedWordIDs.union(progress.filter { $0.value.lastReviewedAt != nil }.map(\.key)).count
    }
    var masteredWordCount: Int { progress.values.filter { $0.level >= 4 }.count }
    var totalAttempts: Int { progress.values.reduce(0) { $0 + $1.attempts } }
    var totalCorrect: Int { progress.values.reduce(0) { $0 + $1.correct } }

    var recommendedWeekCount: Int { max(1, (recommendedWords.count + 119) / 120) }

    func learningLocation(for word: NativeWord) -> NativeLearningLocation? {
        learningLocations[word.id]
    }

    func learningDays(forWeek week: Int) -> [Int] {
        let days: [Int] = recommendedWords.compactMap { word -> Int? in
            guard let location = learningLocations[word.id], location.week == week else { return nil }
            return location.day
        }
        return Array(Set(days)).sorted()
    }

    func learningDay(for word: NativeWord) -> Int {
        learningLocations[word.id]?.day ?? word.day - (word.week - 1) * 7
    }

    func words(week: Int, day: Int) -> [NativeWord] {
        recommendedWords.filter { learningLocations[$0.id] == NativeLearningLocation(week: week, day: day) }
    }

    func isWordStudied(_ word: NativeWord) -> Bool {
        studiedWordIDs.contains(word.id) || progress[word.id]?.lastReviewedAt != nil
    }

    @discardableResult
    func markWordStudied(_ word: NativeWord) -> Bool {
        guard !studiedWordIDs.contains(word.id) else { return true }
        let now = Date.now
        let reviewDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        do {
            try execute("BEGIN IMMEDIATE")
            try run("INSERT OR IGNORE INTO study_marks (word_id, studied_at) VALUES (?, ?)",
                    bindings: [word.id, now.ISO8601Format()])
            try run("""
                INSERT OR IGNORE INTO word_progress
                    (word_id, attempts, correct, wrong, streak, level, last_reviewed_at, next_review_at, history_json)
                VALUES (?, 0, 0, 0, 0, 0, ?, ?, '[]')
                """, bindings: [word.id, now.ISO8601Format(), reviewDate.ISO8601Format()])
            try execute("COMMIT")
            studiedWordIDs.insert(word.id)
            if progress[word.id] == nil {
                progress[word.id] = NativeProgress(attempts: 0, correct: 0, wrong: 0, streak: 0, level: 0,
                                                  lastReviewedAt: now, nextReviewAt: reviewDate)
            }
            return true
        } catch {
            try? execute("ROLLBACK")
            storageError = error.localizedDescription
            return false
        }
    }

    func studyPosition(week: Int, day: Int) -> String? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "SELECT word_id FROM study_sessions WHERE week=? AND day=?", -1, &statement, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(statement, 1, Int32(week))
        sqlite3_bind_int(statement, 2, Int32((week - 1) * 7 + day))
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return text(statement, 0)
    }

    func saveStudyPosition(_ word: NativeWord) {
        do {
            try run("""
                INSERT INTO study_sessions (week, day, word_id, updated_at) VALUES (?, ?, ?, ?)
                ON CONFLICT(week, day) DO UPDATE SET word_id=excluded.word_id, updated_at=excluded.updated_at
                """, bindings: [word.week, word.day, word.id, Date.now.ISO8601Format()])
        } catch {
            storageError = error.localizedDescription
        }
    }

    func meaning(for word: NativeWord) -> String {
        translations?.words[word.id]?.meaning ?? word.meaningZh
    }

    func exampleTranslation(for word: NativeWord) -> String {
        translations?.words[word.id]?.exampleTranslation ?? word.exampleZh
    }

    func note(for word: NativeWord) -> String {
        translations?.words[word.id]?.note ?? word.note
    }

    func family(for word: NativeWord) -> String {
        translations?.words[word.id]?.wordFamily ?? word.wordFamily
    }

    func setLocale(_ locale: String) {
        guard ["zh-CN", "ja", "ko", "fr", "es", "ar"].contains(locale) else { return }
        self.locale = locale
        UserDefaults.standard.set(locale, forKey: "native.learning.locale")
        loadTranslations(locale)
    }

    func recordAnswer(word: NativeWord, mode: String, response: String, correct: Bool) {
        let previous = progress[word.id] ?? NativeProgress(attempts: 0, correct: 0, wrong: 0, streak: 0,
                                                           level: 0, lastReviewedAt: nil, nextReviewAt: nil)
        var next = previous
        next.attempts += 1
        next.correct += correct ? 1 : 0
        next.wrong += correct ? 0 : 1
        next.streak = correct ? previous.streak + 1 : 0
        next.level = correct ? min(previous.level + 1, 5) : max(previous.level - 1, 0)
        next.lastReviewedAt = .now
        let intervals = [1, 3, 7, 14, 30]
        let interval = correct ? intervals[min(max(next.level - 1, 0), intervals.count - 1)] : 1
        next.nextReviewAt = Calendar.current.date(byAdding: .day, value: interval, to: .now)

        do {
            try execute("BEGIN IMMEDIATE")
            try run("""
                INSERT INTO word_progress
                    (word_id, attempts, correct, wrong, streak, level, last_reviewed_at, next_review_at, history_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, '[]')
                ON CONFLICT(word_id) DO UPDATE SET
                    attempts=excluded.attempts, correct=excluded.correct, wrong=excluded.wrong,
                    streak=excluded.streak, level=excluded.level,
                    last_reviewed_at=excluded.last_reviewed_at, next_review_at=excluded.next_review_at
                """, bindings: [word.id, next.attempts, next.correct, next.wrong, next.streak, next.level,
                              next.lastReviewedAt?.ISO8601Format() ?? "", next.nextReviewAt?.ISO8601Format() ?? ""])
            try run("INSERT INTO practice_records (mode, prompt, response, rating, created_at) VALUES (?, ?, ?, ?, ?)",
                    bindings: [mode, word.id, response, correct ? 1 : 0, Date.now.ISO8601Format()])
            try execute("COMMIT")
            progress[word.id] = next
        } catch {
            try? execute("ROLLBACK")
            storageError = error.localizedDescription
        }
    }

    func recordExpression(kind: String, prompt: String, response: String, rating: Int, duration: Int, notes: String) {
        do {
            try run("""
                INSERT INTO expression_records (kind, prompt, response, rating, duration_seconds, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, bindings: [kind, prompt, response, rating, duration, notes, Date.now.ISO8601Format()])
            try loadExpressionRecords()
        } catch {
            storageError = error.localizedDescription
        }
    }

    func saveWritingDraft(_ draft: NativeWritingDraft) {
        do {
            try run("""
                INSERT INTO writing_drafts (id, week, task, prompt, response, notes, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET response=excluded.response, notes=excluded.notes,
                    updated_at=excluded.updated_at
                """, bindings: [draft.id, draft.week, draft.task, draft.prompt, draft.response, draft.notes,
                              Date.now.ISO8601Format()])
            try loadWritingDrafts()
        } catch {
            storageError = error.localizedDescription
        }
    }

    func deleteWritingDraft(_ id: String) {
        do {
            try run("DELETE FROM writing_drafts WHERE id = ?", bindings: [id])
            try loadWritingDrafts()
        } catch {
            storageError = error.localizedDescription
        }
    }

    func changeLocaleAndResetProgress(_ locale: String) {
        do {
            try execute("BEGIN IMMEDIATE")
            try execute("DELETE FROM word_progress; DELETE FROM study_marks; DELETE FROM study_sessions; DELETE FROM exams; DELETE FROM practice_records; DELETE FROM expression_records; DELETE FROM writing_drafts;")
            try execute("COMMIT")
            progress = [:]
            studiedWordIDs = []
            expressionRecords = []
            writingDrafts = []
            setLocale(locale)
        } catch {
            try? execute("ROLLBACK")
            storageError = error.localizedDescription
        }
    }

    func flush() -> Bool {
        guard database != nil else { return storageError == nil }
        do {
            try execute("PRAGMA wal_checkpoint(FULL)")
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func clearStorageError() { storageError = nil }

    func exportDatabaseData() -> Data? {
        guard flush(), let database else { return nil }
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ielts-learning-export-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        var snapshot: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(snapshotURL.path, &snapshot, flags, nil) == SQLITE_OK else {
            if let snapshot { sqlite3_close(snapshot) }
            return nil
        }
        guard let snapshotHandle = snapshot else { return nil }
        defer { if let snapshot { sqlite3_close(snapshot) } }

        guard let backup = sqlite3_backup_init(snapshotHandle, "main", database, "main") else { return nil }
        var step = sqlite3_backup_step(backup, -1)
        var retries = 0
        while (step == SQLITE_BUSY || step == SQLITE_LOCKED) && retries < 200 {
            sqlite3_sleep(25)
            step = sqlite3_backup_step(backup, -1)
            retries += 1
        }
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else { return nil }
        guard sqlite3_exec(snapshotHandle, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else { return nil }
        guard Self.hasTable(snapshotHandle, name: "words"), Self.quickCheck(snapshotHandle),
              sqlite3_close(snapshotHandle) == SQLITE_OK else { return nil }
        snapshot = nil
        return try? Data(contentsOf: snapshotURL, options: .mappedIfSafe)
    }

    func restoreDatabase(from data: Data) -> Bool {
        guard data.count <= 128 * 1024 * 1024, let database, let databaseURL else { return false }
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory.appendingPathComponent("ielts-restore-\(UUID().uuidString).sqlite")
        let recoveryDirectory = databaseURL.deletingLastPathComponent().appendingPathComponent("App Backups", isDirectory: true)
        let recovery = recoveryDirectory.appendingPathComponent("before-restore-\(Int(Date.now.timeIntervalSince1970)).sqlite")
        var source: OpaquePointer?
        do {
            try data.write(to: temporary, options: .atomic)
            guard sqlite3_open_v2(temporary.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw currentError() }
            let hasWords = Self.hasTable(source, name: "words")
            let hasProgress = Self.hasTable(source, name: "word_progress")
            let isHealthy = Self.quickCheck(source)
            guard hasWords && hasProgress && isHealthy else {
                throw NSError(domain: "NativeLearningStore", code: 4, userInfo: [NSLocalizedDescriptionKey: "备份校验失败 (words=\(hasWords), progress=\(hasProgress), quick_check=\(isHealthy), bytes=\(data.count))"])
            }

            _ = flush()
            try manager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            if manager.fileExists(atPath: recovery.path) { try manager.removeItem(at: recovery) }
            try manager.copyItem(at: databaseURL, to: recovery)
            let backup = sqlite3_backup_init(database, "main", source, "main")
            guard let backup else { throw currentError() }
            let step = sqlite3_backup_step(backup, -1)
            let finish = sqlite3_backup_finish(backup)
            guard step == SQLITE_DONE && finish == SQLITE_OK else { throw currentError() }
            try execute("""
                CREATE TABLE IF NOT EXISTS expression_records (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, prompt TEXT NOT NULL,
                    response TEXT NOT NULL, rating INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0,
                    notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS writing_drafts (
                    id TEXT PRIMARY KEY, week INTEGER NOT NULL, task TEXT NOT NULL, prompt TEXT NOT NULL,
                    response TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL
                );
                """)
            try ensureStudyTables()
            try loadProgress()
            try loadStudyMarks()
            try loadExpressionRecords()
            try loadWritingDrafts()
            sqlite3_close(source)
            source = nil
            try? manager.removeItem(at: temporary)
            return true
        } catch {
            if let source { sqlite3_close(source) }
            try? manager.removeItem(at: temporary)
            storageError = "备份恢复失败：\(error.localizedDescription)"
            return false
        }
    }

    func dailyStats(days: Int) -> [(date: Date, attempts: Int, correct: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var buckets: [Date: (Int, Int)] = [:]
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, "SELECT rating, created_at FROM practice_records WHERE created_at >= ?", -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, start.ISO8601Format(), -1, sqliteTransient)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let timestamp = parseDate(text(statement, 1)) else { continue }
                let day = calendar.startOfDay(for: timestamp)
                let current = buckets[day] ?? (0, 0)
                buckets[day] = (current.0 + 1, current.1 + (sqlite3_column_int(statement, 0) > 0 ? 1 : 0))
            }
        }
        sqlite3_finalize(statement)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let values = buckets[date] ?? (0, 0)
            return (date, values.0, values.1)
        }
    }

    private func openDatabase(urlOverride: URL?) throws {
        let url: URL
        if let urlOverride {
            try FileManager.default.createDirectory(at: urlOverride.deletingLastPathComponent(), withIntermediateDirectories: true)
            url = urlOverride
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("IELTS Vocabulary Lab", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            url = directory.appendingPathComponent("learning.sqlite")
        }
        databaseURL = url
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else { throw currentError() }
        sqlite3_busy_timeout(database, 5_000)
        try execute("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL")
        try execute("""
            CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS words (
                id TEXT PRIMARY KEY, week INTEGER NOT NULL, day INTEGER NOT NULL, day_title TEXT NOT NULL,
                term TEXT NOT NULL, ipa TEXT NOT NULL, part_of_speech TEXT NOT NULL, meaning_zh TEXT NOT NULL,
                collocations_json TEXT NOT NULL, example_en TEXT NOT NULL, example_zh TEXT NOT NULL,
                word_family TEXT NOT NULL, note TEXT NOT NULL, example_source TEXT NOT NULL DEFAULT '',
                example_source_url TEXT NOT NULL DEFAULT '', example_license_url TEXT NOT NULL DEFAULT '',
                exam_tags_json TEXT NOT NULL DEFAULT '[]'
            );
            CREATE TABLE IF NOT EXISTS word_progress (
                word_id TEXT PRIMARY KEY, attempts INTEGER NOT NULL DEFAULT 0, correct INTEGER NOT NULL DEFAULT 0,
                wrong INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, level INTEGER NOT NULL DEFAULT 0,
                last_reviewed_at TEXT, next_review_at TEXT, history_json TEXT NOT NULL DEFAULT '[]',
                FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS exams (
                id TEXT PRIMARY KEY, score INTEGER NOT NULL, total INTEGER NOT NULL, correct INTEGER NOT NULL,
                results_json TEXT NOT NULL, config_json TEXT NOT NULL, created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS practice_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT, mode TEXT NOT NULL, prompt TEXT NOT NULL,
                response TEXT NOT NULL, rating INTEGER NOT NULL, created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_word_progress_next_review ON word_progress(next_review_at);
            CREATE INDEX IF NOT EXISTS idx_exams_created_at ON exams(created_at);
            CREATE INDEX IF NOT EXISTS idx_practice_created_at ON practice_records(created_at);
            CREATE TABLE IF NOT EXISTS expression_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, prompt TEXT NOT NULL,
                response TEXT NOT NULL, rating INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0,
                notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_expression_records_created_at ON expression_records(created_at);
            CREATE TABLE IF NOT EXISTS writing_drafts (
                id TEXT PRIMARY KEY, week INTEGER NOT NULL, task TEXT NOT NULL, prompt TEXT NOT NULL,
                response TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_writing_drafts_updated_at ON writing_drafts(updated_at);
            """)
        try ensureStudyTables()
    }

    private func ensureStudyTables() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS study_marks (
                word_id TEXT PRIMARY KEY REFERENCES words(id) ON DELETE CASCADE,
                studied_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS study_sessions (
                week INTEGER NOT NULL, day INTEGER NOT NULL,
                word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
                updated_at TEXT NOT NULL, PRIMARY KEY (week, day)
            );
            """)
    }

    private func loadStudyMarks() throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT word_id FROM study_marks", -1, &statement, nil) == SQLITE_OK else { throw currentError() }
        defer { sqlite3_finalize(statement) }
        var loaded: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW { loaded.insert(text(statement, 0)) }
        studiedWordIDs = loaded
    }

    private func loadCatalog(urlOverride: URL?) throws {
        guard let url = urlOverride ?? Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw NSError(domain: "NativeLearningStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "App 中没有内置词库资源。"])
        }
        words = try JSONDecoder().decode([NativeWord].self, from: Data(contentsOf: url))
    }

    private func buildLearningPath() {
        recommendedWords = words.filter { $0.track != .otherExam }.sorted { $0.index < $1.index }
        learningLocations = Dictionary(uniqueKeysWithValues: recommendedWords.enumerated().map { offset, word in
            let week = offset / 120 + 1
            let day = offset % 120 / 20 + 1
            return (word.id, NativeLearningLocation(week: week, day: day))
        })
    }

    private func seedWords() throws {
        guard !words.isEmpty else { return }
        try execute("BEGIN IMMEDIATE")
        do {
            for word in words {
                try run("""
                    INSERT INTO words (id, week, day, day_title, term, ipa, part_of_speech, meaning_zh,
                        collocations_json, example_en, example_zh, word_family, note)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        week=excluded.week, day=excluded.day, day_title=excluded.day_title,
                        term=excluded.term, ipa=excluded.ipa, part_of_speech=excluded.part_of_speech,
                        meaning_zh=excluded.meaning_zh, collocations_json=excluded.collocations_json,
                        example_en=excluded.example_en, example_zh=excluded.example_zh,
                        word_family=excluded.word_family, note=excluded.note
                    """, bindings: [word.id, word.week, word.day, word.dayTitle, word.term, word.ipa,
                                  word.partOfSpeech, word.meaningZh, Self.json(word.collocations), word.exampleEn,
                                  word.exampleZh, word.wordFamily, word.note])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func loadProgress() throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT word_id, attempts, correct, wrong, streak, level, last_reviewed_at, next_review_at FROM word_progress", -1, &statement, nil) == SQLITE_OK else {
            throw currentError()
        }
        defer { sqlite3_finalize(statement) }
        var loaded: [String: NativeProgress] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = text(statement, 0)
            loaded[id] = NativeProgress(attempts: Int(sqlite3_column_int(statement, 1)),
                correct: Int(sqlite3_column_int(statement, 2)), wrong: Int(sqlite3_column_int(statement, 3)),
                streak: Int(sqlite3_column_int(statement, 4)), level: Int(sqlite3_column_int(statement, 5)),
                lastReviewedAt: parseDate(text(statement, 6)), nextReviewAt: parseDate(text(statement, 7)))
        }
        progress = loaded
    }

    private func loadExpressionRecords() throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT id, kind, prompt, response, rating, created_at FROM expression_records ORDER BY created_at DESC LIMIT 500", -1, &statement, nil) == SQLITE_OK else {
            throw currentError()
        }
        defer { sqlite3_finalize(statement) }
        var loaded: [NativeExpressionRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            loaded.append(NativeExpressionRecord(id: sqlite3_column_int64(statement, 0), kind: text(statement, 1),
                prompt: text(statement, 2), response: text(statement, 3), rating: Int(sqlite3_column_int(statement, 4)),
                createdAt: parseDate(text(statement, 5)) ?? .distantPast))
        }
        expressionRecords = loaded
    }

    private func loadWritingDrafts() throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT id, week, task, prompt, response, notes, updated_at FROM writing_drafts ORDER BY updated_at DESC", -1, &statement, nil) == SQLITE_OK else {
            throw currentError()
        }
        defer { sqlite3_finalize(statement) }
        var loaded: [NativeWritingDraft] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            loaded.append(NativeWritingDraft(id: text(statement, 0), week: Int(sqlite3_column_int(statement, 1)),
                task: text(statement, 2), prompt: text(statement, 3), response: text(statement, 4),
                notes: text(statement, 5), updatedAt: parseDate(text(statement, 6)) ?? .distantPast))
        }
        writingDrafts = loaded
    }

    private func loadTranslations(_ locale: String) {
        guard let url = Bundle.main.url(forResource: locale, withExtension: "json"),
              let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(NativeTranslationPack.self, from: data) else {
            translations = nil
            return
        }
        translations = pack
    }

    private func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &message) == SQLITE_OK else {
            let reason = message.map { String(cString: $0) } ?? currentError().localizedDescription
            sqlite3_free(message)
            throw NSError(domain: "NativeLearningStore.SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: reason])
        }
    }

    private func run(_ sql: String, bindings: [Any]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw currentError() }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case let text as String:
                result = sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
            case let number as Int:
                result = sqlite3_bind_int64(statement, index, sqlite3_int64(number))
            default:
                result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw currentError() }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw currentError() }
    }

    private func currentError() -> NSError {
        NSError(domain: "NativeLearningStore.SQLite", code: Int(sqlite3_errcode(database)),
                userInfo: [NSLocalizedDescriptionKey: database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite unavailable"])
    }

    private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    private static func hasTable(_ db: OpaquePointer?, name: String) -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", -1, &statement, nil) == SQLITE_OK else { return false }
        sqlite3_bind_text(statement, 1, name, -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func quickCheck(_ db: OpaquePointer?) -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else { return false }
        return String(cString: value) == "ok"
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
            ?? ISO8601DateFormatter.withFractionalSeconds.date(from: value)
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func bundledWords() -> [NativeWord] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([NativeWord].self, from: data)) ?? []
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
