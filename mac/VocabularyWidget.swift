import AppIntents
import Foundation
import SwiftUI
import WidgetKit

private let widgetKind = "IELTSVocabularyCard"

enum VocabularyWeek: String, AppEnum {
    case week1, week2, week3, week4, week5, week6, week7, week8, week9, week10
    case week11, week12, week13, week14, week15, week16, week17, week18, week19, week20
    case week21, week22, week23, week24, week25, week26, week27, week28, week29, week30
    case week31, week32, week33, week34, week35, week36, week37, week38, week39, week40
    case week41, week42, week43, week44, week45, week46, week47, week48, week49, week50

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "周次"
    static var caseDisplayRepresentations: [VocabularyWeek: DisplayRepresentation] = [
        .week1: "Week 1", .week2: "Week 2", .week3: "Week 3", .week4: "Week 4", .week5: "Week 5",
        .week6: "Week 6", .week7: "Week 7", .week8: "Week 8", .week9: "Week 9", .week10: "Week 10",
        .week11: "Week 11", .week12: "Week 12", .week13: "Week 13", .week14: "Week 14", .week15: "Week 15",
        .week16: "Week 16", .week17: "Week 17", .week18: "Week 18", .week19: "Week 19", .week20: "Week 20",
        .week21: "Week 21", .week22: "Week 22", .week23: "Week 23", .week24: "Week 24", .week25: "Week 25",
        .week26: "Week 26", .week27: "Week 27", .week28: "Week 28", .week29: "Week 29", .week30: "Week 30",
        .week31: "Week 31", .week32: "Week 32", .week33: "Week 33", .week34: "Week 34", .week35: "Week 35",
        .week36: "Week 36", .week37: "Week 37", .week38: "Week 38", .week39: "Week 39", .week40: "Week 40",
        .week41: "Week 41", .week42: "Week 42", .week43: "Week 43", .week44: "Week 44", .week45: "Week 45",
        .week46: "Week 46", .week47: "Week 47", .week48: "Week 48", .week49: "Week 49", .week50: "Week 50",
    ]

    var number: Int { Int(rawValue.dropFirst(4)) ?? 1 }
}

enum VocabularyStudyDay: String, AppEnum {
    case day1, day2, day3, day4, day5, day6

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "学习日"
    static var caseDisplayRepresentations: [VocabularyStudyDay: DisplayRepresentation] = [
        .day1: "本周第 1 天", .day2: "本周第 2 天", .day3: "本周第 3 天",
        .day4: "本周第 4 天", .day5: "本周第 5 天", .day6: "本周第 6 天",
    ]

    var number: Int { Int(rawValue.dropFirst(3)) ?? 1 }
}

struct VocabularyWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "IELTS 每日词卡"
    static var description = IntentDescription("选择词库周次和首批学习日；之后从本周词库随机抽取，并在整周学完前避免重复。")

    @Parameter(title: "周次", default: .week1)
    var week: VocabularyWeek

    @Parameter(title: "本周学习日", default: .day1)
    var studyDay: VocabularyStudyDay

    @Parameter(title: "自动轮换（由系统调度）", default: true)
    var automaticRotation: Bool
}

private struct VocabularyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetVocabularySnapshot
    let automaticRotation: Bool

    var studyURL: URL {
        var components = URLComponents()
        components.scheme = "ieltsvocab"
        components.host = "study"
        components.queryItems = [
            URLQueryItem(name: "week", value: String(snapshot.week)),
            URLQueryItem(name: "day", value: String(snapshot.actualDay)),
            URLQueryItem(name: "word", value: snapshot.word?.id),
        ]
        return components.url!
    }
}

private struct VocabularyProvider: AppIntentTimelineProvider {
    func entry(for configuration: VocabularyWidgetConfiguration, date: Date = .now) -> VocabularyEntry {
        VocabularyEntry(date: date, snapshot: WidgetVocabularyStore().snapshot(
            week: configuration.week.number, learningDay: configuration.studyDay.number,
            automaticRotation: configuration.automaticRotation, date: date
        ), automaticRotation: configuration.automaticRotation)
    }

    func placeholder(in context: Context) -> VocabularyEntry { entry(for: VocabularyWidgetConfiguration()) }
    func snapshot(for configuration: VocabularyWidgetConfiguration, in context: Context) async -> VocabularyEntry { entry(for: configuration) }

    func timeline(for configuration: VocabularyWidgetConfiguration, in context: Context) async -> Timeline<VocabularyEntry> {
        let now = Date.now
        var entries = [entry(for: configuration, date: now)]
        guard configuration.automaticRotation else { return Timeline(entries: entries, policy: .never) }
        let next = WidgetVocabularyStore().nextRotation(week: configuration.week.number, learningDay: configuration.studyDay.number, date: now)
        for offset in 0..<24 {
            entries.append(entry(for: configuration, date: next.addingTimeInterval(Double(offset) * WidgetVocabularyStore.rotationInterval)))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

enum VocabularyWidgetAction: String, AppEnum {
    case previous, next, batch, meaning
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "词卡操作"
    static var caseDisplayRepresentations: [VocabularyWidgetAction: DisplayRepresentation] = [
        .previous: "上一词", .next: "下一词", .batch: "换一批", .meaning: "显示或收起释义",
    ]
}

struct VocabularyCardActionIntent: AppIntent {
    static var title: LocalizedStringResource = "操作 IELTS 词卡"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "周次") var week: Int
    @Parameter(title: "本周学习日") var learningDay: Int
    @Parameter(title: "自动轮换") var automaticRotation: Bool
    @Parameter(title: "操作") var action: VocabularyWidgetAction

    init() {}
    fileprivate init(entry: VocabularyEntry, action: VocabularyWidgetAction) {
        self.week = entry.snapshot.week
        self.learningDay = entry.snapshot.learningDay
        self.automaticRotation = entry.automaticRotation
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        let store = WidgetVocabularyStore()
        switch action {
        case .previous: store.moveWord(week: week, learningDay: learningDay, automaticRotation: automaticRotation, step: -1)
        case .next: store.moveWord(week: week, learningDay: learningDay, automaticRotation: automaticRotation, step: 1)
        case .batch: store.changeBatch(week: week, learningDay: learningDay, automaticRotation: automaticRotation)
        case .meaning: store.toggleMeaning(week: week, learningDay: learningDay, automaticRotation: automaticRotation)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

private struct VocabularyWidgetView: View {
    let entry: VocabularyEntry
    @Environment(\.widgetFamily) private var family
    private var compact: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : (large ? 10 : 5)) {
            if let word = entry.snapshot.word {
                HStack {
                    Text("IELTS 词卡").fontWeight(.semibold)
                    Spacer(minLength: 2)
                    Text("W\(entry.snapshot.week) · 第\(entry.snapshot.learningDay)天")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.term)
                        .font(.system(size: large ? 30 : (compact ? 20 : 22), weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if !compact {
                        Spacer(minLength: 0)
                        pronunciationButtons(for: word.term)
                    }
                }

                if !compact {
                    Text("\(word.ipa) · \(word.partOfSpeech)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if compact {
                    pronunciationButtons(for: word.term)
                }

                Text(entry.snapshot.isRevealed ? word.meaningZh : "先回忆它的中文意思")
                    .font(.system(size: large ? 15 : 11, weight: .medium))
                    .lineLimit(large ? 3 : (compact ? 1 : 2))
                if large, entry.snapshot.isRevealed, let collocation = word.collocations.first {
                    Text(collocation).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                HStack(spacing: compact ? 4 : 6) {
                    Button(intent: VocabularyCardActionIntent(entry: entry, action: .meaning)) {
                        Image(systemName: entry.snapshot.isRevealed ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(entry.snapshot.isRevealed ? "收起释义" : "显示释义")
                    if !compact {
                        Button(intent: VocabularyCardActionIntent(entry: entry, action: .previous)) {
                            Image(systemName: "arrow.left")
                        }
                        .accessibilityLabel("上一词")
                    }
                    Button(intent: VocabularyCardActionIntent(entry: entry, action: .next)) {
                        Image(systemName: "arrow.right")
                    }
                    .accessibilityLabel("下一词")
                    Button(intent: VocabularyCardActionIntent(entry: entry, action: .batch)) {
                        if compact { Image(systemName: "arrow.triangle.2.circlepath") }
                        else { Text("换一批") }
                    }
                    .accessibilityLabel("换一批")
                    .disabled(entry.snapshot.batchCount < 2)
                    if !compact {
                        Spacer(minLength: 0)
                        Link(destination: entry.studyURL) { Text("默写 ↗") }.buttonStyle(.plain)
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10))
                .controlSize(.mini)

                HStack {
                    Text("第\(entry.snapshot.batchIndex + 1)/\(entry.snapshot.batchCount)批 · \(entry.snapshot.wordIndex + 1)/\(entry.snapshot.wordCount)词")
                    if !compact {
                        Spacer(minLength: 0)
                        Text(entry.automaticRotation ? "系统自动轮换" : "手动切词")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            } else {
                Text("暂无可用词汇，请重新构建词库资源").font(.caption)
            }
        }
        .padding(large ? 16 : (compact ? 10 : 12))
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.studyURL)
    }

    private func pronunciationButtons(for term: String) -> some View {
        HStack(spacing: 5) {
            Button(intent: VocabularyPronounceIntent(term: term, accent: .uk)) {
                Label(compact ? "UK" : "英音 UK", systemImage: "speaker.wave.2")
            }
            .accessibilityLabel("朗读 \(term) 的英音")
            Button(intent: VocabularyPronounceIntent(term: term, accent: .us)) {
                Label(compact ? "US" : "美音 US", systemImage: "speaker.wave.2")
            }
            .accessibilityLabel("朗读 \(term) 的美音")
        }
        .font(.system(size: 10))
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .fixedSize()
    }
}

struct IELTSVocabularyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: widgetKind,
            intent: VocabularyWidgetConfiguration.self,
            provider: VocabularyProvider()
        ) { entry in
            VocabularyWidgetView(entry: entry)
        }
        .configurationDisplayName("IELTS 每日词卡")
        .description("以所选学习日为起点，从整周词库每批抽取10词，一轮内不重复；释义状态会随切词保留。自动轮换时间由系统安排。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct IELTSVocabularyWidgetBundle: WidgetBundle {
    var body: some Widget {
        IELTSVocabularyWidget()
    }
}
