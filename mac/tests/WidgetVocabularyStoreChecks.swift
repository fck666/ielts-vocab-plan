import Foundation

@main
struct WidgetVocabularyStoreChecks {
    static func main() throws {
        let path = CommandLine.arguments[1]
        let words = try JSONDecoder().decode([WidgetVocabularyWord].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let weeks = Array(Set(words.map(\.week))).sorted()
        var dayCount = 0

        for week in weeks {
            let weekWords = words.filter { $0.week == week }.sorted { $0.index < $1.index }
            let days = Array(Set(weekWords.map(\.day))).sorted()
            let batchCount = (weekWords.count + 9) / 10
            for (offset, day) in days.enumerated() {
                dayCount += 1
                let suite = "ielts-widget-checks-" + UUID().uuidString
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                let store = WidgetVocabularyStore(words: words, defaults: defaults)
                let ordinal = offset + 1
                let dailyWords = weekWords.filter { $0.day == day }
                let first = store.snapshot(week: week, learningDay: ordinal, automaticRotation: false, date: date)
                precondition(first.actualDay == day && first.batchCount == batchCount && first.wordCount == 10)
                precondition(first.word?.id == dailyWords[0].id)

                var visited: [String] = []
                var batches: [[String]] = []
                for batch in 0..<batchCount {
                    var currentBatch: [String] = []
                    for _ in 0..<min(10, weekWords.count - visited.count) {
                        let value = store.snapshot(week: week, learningDay: ordinal, automaticRotation: false, date: date)
                        precondition(value.batchIndex == batch && value.wordCount > 0)
                        visited.append(value.word!.id)
                        currentBatch.append(value.word!.id)
                        store.moveWord(week: week, learningDay: ordinal, automaticRotation: false, step: 1, date: date)
                    }
                    precondition(store.snapshot(week: week, learningDay: ordinal, automaticRotation: false, date: date).wordIndex == 0)
                    batches.append(currentBatch)
                    if batch < batchCount - 1 {
                        store.changeBatch(week: week, learningDay: ordinal, automaticRotation: false, date: date)
                    }
                }
                precondition(Set(visited) == Set(weekWords.map(\.id)) && visited.count == weekWords.count)
                precondition(Set(visited).count == visited.count)

                let lastBatch = Set(batches.last!)
                store.changeBatch(week: week, learningDay: ordinal, automaticRotation: false, date: date)
                let nextCycle = (0..<10).map { index -> String in
                    let value = store.snapshot(week: week, learningDay: ordinal, automaticRotation: false, date: date)
                    precondition(value.batchIndex == 0 && value.wordIndex == index,
                                 "Expected first batch of new cycle at word \(index), got batch \(value.batchIndex), word \(value.wordIndex), week \(week), day \(day)")
                    store.moveWord(week: week, learningDay: ordinal, automaticRotation: false, step: 1, date: date)
                    return value.word!.id
                }
                precondition(Set(nextCycle).count == 10 && Set(nextCycle).isDisjoint(with: lastBatch))
                let sharedState = WidgetVocabularyStore(words: words, defaults: defaults)
                precondition(sharedState.snapshot(week: week, learningDay: days.count, automaticRotation: false, date: date).word?.id == nextCycle[0])
            }
        }
        precondition(weeks.count == 50 && dayCount == 300)

        let suite = "ielts-widget-state-checks-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WidgetVocabularyStore(words: words, defaults: defaults)
        let first = store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date)
        precondition(first.word?.id == "w1-d1-01")
        store.moveWord(week: 1, learningDay: 1, automaticRotation: false, step: -1, date: date)
        precondition(store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date).word?.id == "w1-d1-10")
        store.moveWord(week: 1, learningDay: 1, automaticRotation: false, step: 1, date: date)
        store.toggleMeaning(week: 1, learningDay: 1, automaticRotation: false, date: date)
        store.moveWord(week: 1, learningDay: 1, automaticRotation: false, step: 1, date: date)
        precondition(store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date).isRevealed)
        store.changeBatch(week: 1, learningDay: 1, automaticRotation: false, date: date)
        let secondBatch = store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date)
        precondition(secondBatch.batchIndex == 1 && secondBatch.wordIndex == 0 && secondBatch.isRevealed)
        precondition(secondBatch.word?.week == 1 && secondBatch.actualDay >= 1)
        store.toggleMeaning(week: 1, learningDay: 1, automaticRotation: false, date: date)
        store.moveWord(week: 1, learningDay: 1, automaticRotation: false, step: 1, date: date)
        precondition(!store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date).isRevealed)

        store.toggleMeaning(week: 1, learningDay: 1, automaticRotation: true, date: date)
        let interval = WidgetVocabularyStore.rotationInterval
        let rotated = store.snapshot(week: 1, learningDay: 1, automaticRotation: true, date: date.addingTimeInterval(interval))
        precondition(rotated.wordIndex == 2 && rotated.isRevealed)
        precondition(store.nextRotation(week: 1, learningDay: 1, date: date.addingTimeInterval(interval + 5)) == date.addingTimeInterval(interval * 2))

        defaults.removePersistentDomain(forName: suite)
        let fresh = WidgetVocabularyStore(words: words, defaults: defaults)
        let initial = fresh.snapshot(week: 1, learningDay: 1, automaticRotation: true, date: date)
        let future = fresh.snapshot(week: 1, learningDay: 1, automaticRotation: true, date: date.addingTimeInterval(interval * 3))
        precondition(initial.wordIndex == 0 && future.wordIndex == 3)
        fresh.toggleMeaning(week: 1, learningDay: 1, automaticRotation: true, date: date.addingTimeInterval(interval * 3))
        let reloaded = WidgetVocabularyStore(words: words, defaults: defaults)
        precondition(reloaded.snapshot(week: 1, learningDay: 2, automaticRotation: false, date: date).isRevealed)

        // Keep the old daily card's current word, meaning toggle and rotation anchor on upgrade.
        let legacy = try JSONSerialization.data(withJSONObject: [
            "batchIndex": 1, "wordIndex": 3, "isRevealed": true,
            "changedAt": date.timeIntervalSinceReferenceDate,
        ])
        defaults.set(legacy, forKey: "widget.presentation.v2.w4.d22")
        let migrated = store.snapshot(week: 4, learningDay: 1, automaticRotation: false, date: date)
        precondition(migrated.word?.id == "w4-d22-14" && migrated.isRevealed)
        precondition(store.nextRotation(week: 4, learningDay: 1, date: date) == date.addingTimeInterval(interval))

        let corruptKey = "widget.presentation.v3.w1"
        defaults.set(try JSONEncoder().encode(WidgetVocabularyState(
            batchIndex: Int.max, wordIDs: ["w1-d1-01"], seenWordIDs: ["w1-d1-01"], remainingWordIDs: [],
            wordIndex: Int.max, isRevealed: true, changedAt: date
        )), forKey: corruptKey)
        let normalized = store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date)
        precondition(normalized.batchIndex == 11 && normalized.wordCount == 10 && normalized.wordIndex == 9 && normalized.isRevealed)
        defaults.set(Data("invalid".utf8), forKey: corruptKey)
        precondition(store.snapshot(week: 1, learningDay: 1, automaticRotation: false, date: date).wordIndex == 0)
        let empty = WidgetVocabularyStore(words: [], defaults: defaults)
        precondition(empty.snapshot(week: 1, learningDay: 1, automaticRotation: true, date: date).word == nil)
        empty.changeBatch(week: 1, learningDay: 1, automaticRotation: true, date: date)
        print("PASS: 300 days / 6000 words; weekly no-repeat deck, batch rollover, navigation, persistent meaning state, timeline rotation and corrupt/empty data")
    }
}
