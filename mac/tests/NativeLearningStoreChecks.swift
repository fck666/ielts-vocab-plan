import Foundation

@main
struct NativeLearningStoreChecks {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NativeLearningStoreChecks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = NativeLearningStore(
            databaseURLOverride: root.appendingPathComponent("learning.sqlite"),
            wordsURLOverride: URL(fileURLWithPath: CommandLine.arguments[1])
        )
        try require(store.storageError == nil, store.storageError ?? "Database initialization failed")
        try require(store.words.count == 6_000, "Expected all 6,000 words to load")

        guard let word = store.words.first else { throw CheckError.failed("The word catalog is empty") }
        store.recordAnswer(word: word, mode: "meaning", response: word.meaningZh, correct: true)
        try require(store.progress[word.id]?.attempts == 1, "The first answer was not stored")
        try require(store.progress[word.id]?.level == 1, "A correct answer should raise mastery to level 1")

        let dailyWords = store.words(week: 1, day: 1)
        try require(dailyWords.count == 20, "A daily study deck should contain 20 words")
        try require(store.words(week: 2, day: 1).count == 20, "Week 2 day 1 should resolve its globally numbered source day")
        try require(store.words(week: 11, day: 1).count == 20, "Week 11 day 1 should resolve its globally numbered source day")
        try require(store.learningDays(forWeek: 33) == [1], "The final partial IELTS week should expose only its populated day")
        try require(store.words(week: 33, day: 1).count == 4, "The default IELTS path should retain its final four IELTS-tagged words")
        try require(store.words(week: 34, day: 1).isEmpty, "Cross-exam expansion words should stay outside the default learning path")
        try require(store.recommendedWeekCount == 33, "The recommended path should contain 1,200 topic words and 2,644 IELTS-tagged words")
        try require(store.words.filter { $0.track == .topicCore }.count == 1_200, "Topic-core classification changed unexpectedly")
        try require(store.words.filter { $0.track == .ieltsTagged }.count == 2_644, "IELTS-tag classification changed unexpectedly")
        try require(store.words.filter { $0.track == .otherExam }.count == 2_156, "Cross-exam classification changed unexpectedly")
        let weekElevenWord = store.words.first { $0.week == 11 }
        try require(weekElevenWord.map { store.learningLocation(for: $0) == NativeLearningLocation(week: 11, day: 1) } == true,
                    "A source-global day should be translated to a week-local learning location")
        let studied = dailyWords[1]
        try require(store.markWordStudied(studied), "Marking a word as studied failed")
        try require(store.markWordStudied(studied), "Study marks should be idempotent")
        store.saveStudyPosition(studied)
        try require(store.isWordStudied(studied), "The studied word was not marked")
        try require(store.studyPosition(week: 1, day: 1) == studied.id, "Week-local resume lookup did not preserve the stored source day")
        try require(store.studiedWordCount == 2, "Study and practice counts should be combined without duplicates")
        try require(store.totalAttempts == 1, "Reading a word must not count as an answered question")
        try require(store.progress[studied.id]?.level == 0, "Reading a word must not raise its mastery")
        try require((store.progress[studied.id]?.nextReviewAt ?? .distantPast) > .now, "A studied word needs a future review date")
        try require(store.studyPosition(week: 1, day: 1) == studied.id, "The daily study position was not saved")

        guard let backup = store.exportDatabaseData() else { throw CheckError.failed("Database export failed") }
        try require(backup.prefix(16) == Data("SQLite format 3\0".utf8), "Export did not produce a standalone SQLite database")
        store.recordAnswer(word: word, mode: "spelling", response: "incorrect", correct: false)
        try require(store.markWordStudied(dailyWords[2]), "The additional study mark was not saved")
        store.saveStudyPosition(dailyWords[2])
        try require(store.progress[word.id]?.attempts == 2, "The second answer was not stored")
        let restored = store.restoreDatabase(from: backup)
        try require(restored, store.storageError ?? "Database restore failed")
        try require(store.progress[word.id]?.attempts == 1, "Restore did not recover the exported progress")
        try require(store.totalCorrect == 1, "Restore did not recover the correct-answer count")
        try require(store.studiedWordIDs == Set([studied.id]), "Restore did not recover the study marks")
        try require(store.studyPosition(week: 1, day: 1) == studied.id, "Restore did not recover the study position")
        try require(store.dailyStats(days: 1).first?.attempts == 1, "Daily practice statistics did not survive restore")
        try require(store.flush(), "The restored database could not be checkpointed")

        let reopened = NativeLearningStore(databaseURLOverride: root.appendingPathComponent("learning.sqlite"),
                                          wordsURLOverride: URL(fileURLWithPath: CommandLine.arguments[1]))
        try require(reopened.storageError == nil, "Reopening the learning database failed")
        try require(reopened.studiedWordIDs == Set([studied.id]), "Study marks did not survive reopening")
        try require(reopened.studyPosition(week: 1, day: 1) == studied.id, "The saved position did not survive reopening")

        print("Native SQLite checks passed: 6,000 words, daily study marks and resume, separate practice counts, export, restore, reopen and statistics.")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckError.failed(message) }
    }
}

private enum CheckError: Error {
    case failed(String)
}
