import Foundation

struct WidgetVocabularyWord: Decodable, Identifiable {
    let id: String
    let index: Int
    let week: Int
    let day: Int
    let dayTitle: String
    let term: String
    let ipa: String
    let partOfSpeech: String
    let meaningZh: String
    let collocations: [String]
}

struct WidgetVocabularyState: Codable {
    var batchIndex: Int
    var wordIDs: [String]
    var seenWordIDs: [String]
    var remainingWordIDs: [String]
    var wordIndex: Int
    var isRevealed: Bool
    var changedAt: Date
}

struct WidgetVocabularySnapshot {
    let week: Int
    let learningDay: Int
    let actualDay: Int
    let word: WidgetVocabularyWord?
    let batchIndex: Int
    let batchCount: Int
    let wordIndex: Int
    let wordCount: Int
    let isRevealed: Bool
}

private struct WidgetVocabularyCatalog {
    let wordsByWeek: [Int: [WidgetVocabularyWord]]
    let daysByWeek: [Int: [Int]]
    let wordsByID: [String: WidgetVocabularyWord]

    init(words: [WidgetVocabularyWord]) {
        var weeks: [Int: [WidgetVocabularyWord]] = [:]
        var ids: [String: WidgetVocabularyWord] = [:]
        for word in words {
            weeks[word.week, default: []].append(word)
            ids[word.id] = word
        }
        for week in weeks.keys {
            weeks[week]?.sort { $0.index < $1.index }
        }
        self.wordsByWeek = weeks
        self.daysByWeek = weeks.mapValues { Array(Set($0.map(\.day))).sorted() }
        self.wordsByID = ids
    }

    init(bundle: Bundle) {
        let url = bundle.url(forResource: "words", withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) }
        let words = data.flatMap { try? JSONDecoder().decode([WidgetVocabularyWord].self, from: $0) } ?? []
        self.init(words: words)
    }
}

private struct LegacyWidgetVocabularyState: Decodable {
    let batchIndex: Int
    let wordIndex: Int
    let isRevealed: Bool
    let changedAt: Date
}

// This extension has its own local presentation state. It never edits webpage progress.
struct WidgetVocabularyStore {
    static let rotationInterval: TimeInterval = 15 * 60
    private static let bundledCatalog = WidgetVocabularyCatalog(bundle: .main)

    private let catalog: WidgetVocabularyCatalog
    private let defaults: UserDefaults

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.catalog = bundle.bundleURL == Bundle.main.bundleURL
            ? Self.bundledCatalog
            : WidgetVocabularyCatalog(bundle: bundle)
        self.defaults = defaults
    }

    init(words: [WidgetVocabularyWord], defaults: UserDefaults) {
        self.catalog = WidgetVocabularyCatalog(words: words)
        self.defaults = defaults
    }

    func snapshot(week: Int, learningDay: Int, automaticRotation: Bool, date: Date = .now) -> WidgetVocabularySnapshot {
        let selection = selection(week: week, learningDay: learningDay)
        let state = normalizedState(week: week, initialDayWords: selection.dayWords, weekWords: selection.weekWords, date: date)
        let steps = rotationSteps(state: state, automaticRotation: automaticRotation, date: date)
        let index = state.wordIDs.isEmpty ? 0 : (state.wordIndex + steps % state.wordIDs.count) % state.wordIDs.count
        let word = state.wordIDs.indices.contains(index) ? catalog.wordsByID[state.wordIDs[index]] : nil
        let activeDay = word?.day ?? selection.day
        let activeOrdinal = (catalog.daysByWeek[week] ?? []).firstIndex(of: activeDay).map { $0 + 1 } ?? selection.ordinal

        return WidgetVocabularySnapshot(
            week: week, learningDay: activeOrdinal, actualDay: activeDay,
            word: word, batchIndex: state.batchIndex,
            batchCount: max(1, (selection.weekWords.count + 9) / 10),
            wordIndex: index, wordCount: state.wordIDs.count,
            isRevealed: state.isRevealed
        )
    }

    func moveWord(week: Int, learningDay: Int, automaticRotation: Bool, step: Int, date: Date = .now) {
        update(week: week, learningDay: learningDay, automaticRotation: automaticRotation, date: date) { state, snapshot, _ in
            guard snapshot.wordCount > 0 else { return }
            let offset = step % snapshot.wordCount
            state.wordIndex = (snapshot.wordIndex + offset + snapshot.wordCount) % snapshot.wordCount
        }
    }

    func changeBatch(week: Int, learningDay: Int, automaticRotation: Bool, date: Date = .now) {
        update(week: week, learningDay: learningDay, automaticRotation: automaticRotation, date: date) { state, _, weekWords in
            let remaining = state.remainingWordIDs
            if !remaining.isEmpty {
                state.wordIDs = Array(remaining.prefix(10))
                state.seenWordIDs.append(contentsOf: state.wordIDs)
                state.remainingWordIDs = Array(remaining.dropFirst(10))
                state.batchIndex += 1
            } else if !weekWords.isEmpty {
                let previous = Set(state.wordIDs)
                let shuffled = weekWords.map(\.id).shuffled()
                let cycle = shuffled.filter { !previous.contains($0) } + shuffled.filter { previous.contains($0) }
                state.wordIDs = Array(cycle.prefix(10))
                state.seenWordIDs = state.wordIDs
                state.remainingWordIDs = Array(cycle.dropFirst(10))
                state.batchIndex = 0
            }
            state.wordIndex = 0
        }
    }

    func toggleMeaning(week: Int, learningDay: Int, automaticRotation: Bool, date: Date = .now) {
        update(week: week, learningDay: learningDay, automaticRotation: automaticRotation, date: date) { state, _, _ in
            state.isRevealed.toggle()
        }
    }

    func nextRotation(week: Int, learningDay: Int, date: Date) -> Date {
        let selection = selection(week: week, learningDay: learningDay)
        let state = normalizedState(week: week, initialDayWords: selection.dayWords, weekWords: selection.weekWords, date: date)
        let steps = floor(max(0, date.timeIntervalSince(state.changedAt)) / Self.rotationInterval)
        return state.changedAt.addingTimeInterval((steps + 1) * Self.rotationInterval)
    }

    private func selection(week: Int, learningDay: Int) -> (day: Int, ordinal: Int, dayWords: [WidgetVocabularyWord], weekWords: [WidgetVocabularyWord]) {
        let weekWords = catalog.wordsByWeek[week] ?? []
        let days = catalog.daysByWeek[week] ?? []
        guard !days.isEmpty else { return (0, 1, [], weekWords) }
        let ordinal = min(max(1, learningDay), days.count)
        let day = days[ordinal - 1]
        return (day, ordinal, weekWords.filter { $0.day == day }, weekWords)
    }

    private func key(week: Int) -> String { "widget.presentation.v3.w\(week)" }

    private func normalizedState(week: Int, initialDayWords: [WidgetVocabularyWord], weekWords: [WidgetVocabularyWord], date: Date) -> WidgetVocabularyState {
        let stateKey = key(week: week)
        let data = defaults.data(forKey: stateKey)
        if let decoded = data.flatMap({ try? JSONDecoder().decode(WidgetVocabularyState.self, from: $0) }) {
            return normalized(decoded, weekWords: weekWords)
        }

        let legacy = initialDayWords.first.flatMap { word -> LegacyWidgetVocabularyState? in
            let legacyKey = "widget.presentation.v2.w\(week).d\(word.day)"
            return defaults.data(forKey: legacyKey).flatMap { try? JSONDecoder().decode(LegacyWidgetVocabularyState.self, from: $0) }
        }
        let initialBatch = min(max(0, legacy?.batchIndex ?? 0), max(0, (initialDayWords.count + 9) / 10 - 1))
        let currentIDs = Array(initialDayWords.dropFirst(initialBatch * 10).prefix(10).map(\.id))
        let currentSet = Set(currentIDs)
        let remainingIDs = weekWords.map(\.id).filter { !currentSet.contains($0) }.shuffled()
        let state = WidgetVocabularyState(
            batchIndex: 0,
            wordIDs: currentIDs,
            seenWordIDs: currentIDs,
            remainingWordIDs: remainingIDs,
            wordIndex: legacy?.wordIndex ?? 0,
            isRevealed: legacy?.isRevealed ?? false,
            changedAt: legacy?.changedAt ?? date
        )
        let normalizedState = normalized(state, weekWords: weekWords)
        if let encoded = try? JSONEncoder().encode(normalizedState) {
            defaults.set(encoded, forKey: stateKey)
        }
        return normalizedState
    }

    private func normalized(_ value: WidgetVocabularyState, weekWords: [WidgetVocabularyWord]) -> WidgetVocabularyState {
        let validIDs = Set(weekWords.map(\.id))
        var current: [String] = []
        var currentSet = Set<String>()
        for id in value.wordIDs where validIDs.contains(id) && currentSet.insert(id).inserted {
            current.append(id)
        }
        var seenWordIDs: [String] = []
        var seen = Set<String>()
        for id in value.seenWordIDs + current where validIDs.contains(id) && seen.insert(id).inserted {
            seenWordIDs.append(id)
        }
        var remaining: [String] = []
        var remainingSet = Set<String>()
        for id in value.remainingWordIDs where validIDs.contains(id) && !seen.contains(id) && remainingSet.insert(id).inserted {
            remaining.append(id)
        }
        let covered = seen.union(remainingSet)
        remaining.append(contentsOf: weekWords.map(\.id).filter { !covered.contains($0) })
        let batchCount = max(1, (weekWords.count + 9) / 10)
        let batch = min(max(0, value.batchIndex), batchCount - 1)
        let batchSize = min(10, weekWords.count)
        var wordIDs = Array(current.prefix(batchSize))
        if wordIDs.count < batchSize {
            let fillCount = batchSize - wordIDs.count
            let fill = Array(remaining.prefix(fillCount))
            wordIDs.append(contentsOf: fill)
            seenWordIDs.append(contentsOf: fill)
            seen.formUnion(fill)
            remaining = Array(remaining.dropFirst(fillCount))
        }
        let wordIndex = wordIDs.isEmpty ? 0 : min(max(0, value.wordIndex), wordIDs.count - 1)
        return WidgetVocabularyState(
            batchIndex: batch, wordIDs: wordIDs, seenWordIDs: seenWordIDs, remainingWordIDs: remaining,
            wordIndex: wordIndex, isRevealed: value.isRevealed, changedAt: value.changedAt
        )
    }

    private func rotationSteps(state: WidgetVocabularyState, automaticRotation: Bool, date: Date) -> Int {
        guard automaticRotation else { return 0 }
        return Int(min(1_000_000, floor(max(0, date.timeIntervalSince(state.changedAt)) / Self.rotationInterval)))
    }

    private func update(week: Int, learningDay: Int, automaticRotation: Bool, date: Date,
                        mutation: (inout WidgetVocabularyState, WidgetVocabularySnapshot, [WidgetVocabularyWord]) -> Void) {
        let selection = selection(week: week, learningDay: learningDay)
        let snapshot = snapshot(week: week, learningDay: learningDay, automaticRotation: automaticRotation, date: date)
        guard snapshot.word != nil else { return }
        var state = normalizedState(week: week, initialDayWords: selection.dayWords, weekWords: selection.weekWords, date: date)
        state.wordIndex = snapshot.wordIndex
        mutation(&state, snapshot, selection.weekWords)
        state.changedAt = date
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key(week: week))
        }
    }
}
