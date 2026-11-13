import SwiftUI
import Combine

enum NativeSection: String, CaseIterable, Identifiable {
    case today, study, training, review, vocabulary, translation, speaking, writing, statistics, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "今天"
        case .study: "每日背词"
        case .training: "每日训练"
        case .review: "到期复习"
        case .vocabulary: "词库"
        case .translation: "翻译工具"
        case .speaking: "口语练习"
        case .writing: "写作练习"
        case .statistics: "学习统计"
        case .settings: "设置与数据"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .study: "book.pages"
        case .training: "rectangle.stack"
        case .review: "arrow.clockwise"
        case .vocabulary: "text.book.closed"
        case .translation: "character.bubble"
        case .speaking: "waveform"
        case .writing: "pencil.line"
        case .statistics: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
final class NativeAppModel: ObservableObject {
    @Published var section: NativeSection = .today
    @Published var appearance: String = UserDefaults.standard.string(forKey: "native.appearance") ?? "system" {
        didSet { UserDefaults.standard.set(appearance, forKey: "native.appearance") }
    }
    @Published var selectedWeek = min(max(UserDefaults.standard.integer(forKey: "native.learning.week"), 1), 50) {
        didSet { UserDefaults.standard.set(selectedWeek, forKey: "native.learning.week") }
    }
    @Published var selectedDay = min(max(UserDefaults.standard.integer(forKey: "native.learning.day"), 1), 6) {
        didSet { UserDefaults.standard.set(selectedDay, forKey: "native.learning.day") }
    }
    @Published var trainingMode: NativeStudyMode = .meaning
    /// A non-nil value makes the next training session a short, focused challenge.
    /// The answers still go through the normal SQLite progress pipeline.
    @Published var trainingLimit: Int?
    @Published var trainingWordIDs: [String]?
    @Published var pendingWordID: String?
    @Published var reviewStarted = false
    let trainingSession = NativeTrainingSession()
    let reviewSession = NativeTrainingSession()
    let store = NativeLearningStore()
    private var storeSubscription: AnyCancellable?

    init() {
        selectedWeek = min(selectedWeek, store.recommendedWeekCount)
        storeSubscription = store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func beginStudying(_ word: NativeWord? = nil) {
        if let word {
            guard let location = store.learningLocation(for: word) else {
                beginTraining(.meaning, wordIDs: [word.id])
                return
            }
            selectedWeek = location.week
            selectedDay = location.day
        }
        trainingLimit = nil
        trainingWordIDs = nil
        pendingWordID = word?.id
        section = .study
    }

    func beginTraining(_ mode: NativeStudyMode, limit: Int? = nil, wordIDs: [String]? = nil) {
        trainingMode = mode
        trainingLimit = limit
        trainingWordIDs = wordIDs
        pendingWordID = nil
        section = .training
        trainingSession.mode = mode
        trainingSession.requestVersion += 1
    }

    func showTraining() {
        if trainingSession.isInitialized {
            pendingWordID = nil
            section = .training
        } else {
            beginTraining(trainingMode)
        }
    }

    func beginReview() {
        trainingMode = .meaning
        reviewStarted = true
        reviewSession.mode = .meaning
        reviewSession.requestVersion += 1
    }

    func openRoute(week: Int, day: Int, word: String?) {
        if let word, let match = store.words.first(where: { $0.id == word }),
           let location = store.learningLocation(for: match) {
            selectedWeek = location.week
            selectedDay = location.day
        } else {
            selectedWeek = min(max(week, 1), store.recommendedWeekCount)
            selectedDay = min(max(day - (week - 1) * 7, 1), 6)
        }
        pendingWordID = word
        trainingMode = .meaning
        trainingLimit = nil
        trainingWordIDs = word.map { [$0] }
        section = .training
        trainingSession.mode = .meaning
        trainingSession.requestVersion += 1
    }
}

struct NativeLayoutMetrics {
    let width: CGFloat
    let height: CGFloat

    var isCompact: Bool { width < 760 }
    var isNarrow: Bool { width < 920 }
    var isShort: Bool { height < 560 }
    var horizontalPadding: CGFloat {
        if width < 700 { return 18 }
        if width < 920 { return 25 }
        return 34
    }
    var verticalPadding: CGFloat { height < 560 ? 20 : 30 }
    var metricColumns: Int { width < 920 ? 2 : 4 }
}

private struct NativeLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = NativeLayoutMetrics(width: 1024, height: 768)
}

extension EnvironmentValues {
    var nativeLayout: NativeLayoutMetrics {
        get { self[NativeLayoutMetricsKey.self] }
        set { self[NativeLayoutMetricsKey.self] = newValue }
    }
}

struct NativeResponsiveStack<Content: View>: View {
    @Environment(\.nativeLayout) private var layout
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if layout.isCompact {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

struct NativeMetricGrid<Content: View>: View {
    @Environment(\.nativeLayout) private var layout
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: layout.metricColumns),
                  alignment: .leading, spacing: 20) {
            content
        }
    }
}

struct NativeRootView: View {
    @ObservedObject var model: NativeAppModel
    var onSidebarVisibilityChanged: () -> Void = {}
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hoverRevealedSidebar = false
    @AppStorage("native.sidebar.pinned") private var sidebarPinned = false
    @State private var sidebarPointerInside = false
    @State private var sidebarAutoHideGeneration = 0

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    Text("IELTS 词汇")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Button(action: toggleSidebarPin) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(sidebarPinned ? Color.accentColor : Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(sidebarPinned ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(sidebarPinned ? "取消固定侧边栏" : "固定侧边栏")
                    .accessibilityLabel(sidebarPinned ? "取消固定侧边栏" : "固定侧边栏")
                }
                .padding(.horizontal, 12).padding(.top, 22).padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(NativeSection.allCases) { section in
                        Button {
                            if section == .training {
                                model.showTraining()
                            } else {
                                model.section = section
                            }
                            model.pendingWordID = nil
                            if hoverRevealedSidebar { hideSidebar() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: section.symbol).frame(width: 17)
                                Text(section.title)
                                Spacer(minLength: 0)
                                if section == .review && !model.store.dueWords.isEmpty {
                                    Text(model.store.dueWords.count.formatted())
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.system(size: 13, weight: model.section == section ? .medium : .regular))
                            .foregroundStyle(model.section == section ? Color.primary : Color.secondary)
                            .padding(.horizontal, 10).frame(height: 31)
                            .background(model.section == section ? Color.accentColor.opacity(0.11) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                Spacer()
            }
            .frame(minWidth: 176)
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationSplitViewColumnWidth(min: 176, ideal: 196, max: 230)
            .onHover(perform: sidebarHoverChanged)
        } detail: {
            Group {
                switch model.section {
                case .today: NativeTodayView()
                case .study: NativeDailyStudyView(store: model.store)
                case .training: NativeTrainingView(session: model.trainingSession)
                case .review: NativeReviewView()
                case .vocabulary: NativeVocabularyView()
                case .translation: NativeTranslationView()
                case .speaking: NativeSpeakingView()
                case .writing: NativeWritingView()
                case .statistics: NativeStatisticsView()
                case .settings: NativeSettingsView()
                }
            }
            .environmentObject(model)
            .frame(minWidth: 500, minHeight: 380)
            .overlay(alignment: .topLeading) {
                if columnVisibility == .detailOnly {
                    GeometryReader { geometry in
                        SidebarRevealRegion(height: geometry.size.height * 0.25) { hovering in
                            if hovering { revealSidebar() }
                        }
                    }
                    .frame(width: 14)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columnVisibility) { _, _ in
            DispatchQueue.main.async { onSidebarVisibilityChanged() }
        }
        .alert("数据库状态", isPresented: Binding(get: { model.store.storageError != nil }, set: { if !$0 { model.store.clearStorageError() } })) {
            Button("好", role: .cancel) { model.store.clearStorageError() }
        } message: {
            Text(model.store.storageError ?? "")
        }
    }

    private func hideSidebar() {
        sidebarAutoHideGeneration += 1
        hoverRevealedSidebar = false
        sidebarPointerInside = false
        withAnimation(.easeOut(duration: 0.1)) {
            columnVisibility = .detailOnly
        }
    }

    private func revealSidebar() {
        guard !sidebarPinned, columnVisibility == .detailOnly else { return }
        hoverRevealedSidebar = true
        withAnimation(.easeInOut(duration: 0.18)) {
            columnVisibility = .all
        }
        scheduleSidebarAutoHide(after: 1.2)
    }

    private func toggleSidebarPin() {
        if sidebarPinned {
            sidebarPinned = false
            hideSidebar()
        } else {
            sidebarAutoHideGeneration += 1
            sidebarPinned = true
            hoverRevealedSidebar = false
            columnVisibility = .all
        }
    }

    private func sidebarHoverChanged(_ hovering: Bool) {
        sidebarPointerInside = hovering
        if hovering {
            sidebarAutoHideGeneration += 1
        } else if hoverRevealedSidebar && !sidebarPinned {
            scheduleSidebarAutoHide(after: 0.45)
        }
    }

    private func scheduleSidebarAutoHide(after delay: TimeInterval) {
        sidebarAutoHideGeneration += 1
        let generation = sidebarAutoHideGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == sidebarAutoHideGeneration,
                  hoverRevealedSidebar,
                  !sidebarPinned,
                  !sidebarPointerInside else { return }
            hideSidebar()
        }
    }
}

private struct SidebarRevealRegion: View {
    let height: CGFloat
    let onHover: (Bool) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: 14, height: height, alignment: .topLeading)
            .onHover(perform: onHover)
            .accessibilityHidden(true)
    }
}

struct NativePage<Content: View>: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isVisible = false
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let content: (NativeLayoutMetrics) -> Content

    init(eyebrow: String, title: String, subtitle: String,
         accent: Color = .accentColor,
         @ViewBuilder content: @escaping (NativeLayoutMetrics) -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content
    }

    var body: some View {
		GeometryReader { geometry in
			let layout = NativeLayoutMetrics(width: geometry.size.width, height: geometry.size.height)
			ScrollView {
                VStack(alignment: .leading, spacing: layout.isShort ? 18 : 25) {
					VStack(alignment: .leading, spacing: 6) {
						HStack(spacing: 7) {
							Capsule().fill(accent.opacity(0.82)).frame(width: 3, height: 11)
							Text(eyebrow.uppercased()).font(.system(size: 10, weight: .semibold, design: .rounded))
								.foregroundStyle(accent)
						}
						Text(title).font(.system(size: 27, weight: .semibold, design: .rounded))
						Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
					}
					.opacity(isVisible ? 1 : 0)
					.offset(y: reduceMotion || isVisible ? 0 : 7)
					.animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: isVisible)
					content(layout).environment(\.nativeLayout, layout)
						.opacity(isVisible ? 1 : 0)
						.offset(y: reduceMotion || isVisible ? 0 : 10)
						.animation(reduceMotion ? nil : .easeOut(duration: 0.34).delay(0.04), value: isVisible)
				}
				.frame(maxWidth: 1040, alignment: .leading)
				.padding(.horizontal, layout.horizontalPadding)
				.padding(.top, layout.verticalPadding).padding(.bottom, 36)
				.frame(maxWidth: .infinity, alignment: .topLeading)
			}
			.background(Color(nsColor: .controlBackgroundColor).opacity(0.32))
		}
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                isVisible = false
                DispatchQueue.main.async { withAnimation { isVisible = true } }
            }
        }
        .onDisappear { isVisible = false }
    }
}

struct NativeSectionHeading: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }
}

struct NativeMetric: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let label: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: value)
            Text(detail).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NativeSelectionOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct NativeSelectControl<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [NativeSelectionOption<Value>]
    var minWidth: CGFloat = 160
    @State private var isHovered = false

    private var selectedTitle: String {
        options.first(where: { $0.value == selection })?.title ?? "选择"
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            let label = Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                + Text("   \(selectedTitle)  ")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                + Text(Image(systemName: "chevron.down"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)

            label
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .padding(.horizontal, 10)
        .frame(width: minWidth, height: 38, alignment: .leading)
        .background(
            isHovered ? Color.accentColor.opacity(0.07) : Color(nsColor: .controlBackgroundColor).opacity(0.62),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isHovered ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.08), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .help("选择\(title)")
        .accessibilityLabel(title)
        .accessibilityValue(selectedTitle)
        .accessibilityHint("打开\(title)选项")
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }
}

private struct NativeTodayView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var challengeHovered = false
    @State private var hoveredDay: Int?
    private var days: [Int] { model.store.learningDays(forWeek: model.selectedWeek) }

    private var stateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.22)
    }

    private var dailyWords: [NativeWord] {
        model.store.words(week: model.selectedWeek, day: model.selectedDay)
    }

    private var studiedCount: Int {
        dailyWords.filter { model.store.isWordStudied($0) }.count
    }

    private var savedWord: NativeWord? {
        guard let id = model.store.studyPosition(week: model.selectedWeek, day: model.selectedDay) else { return nil }
        return dailyWords.first { $0.id == id }
    }

    private var challengeCount: Int {
        min(5, dailyWords.count)
    }

    var body: some View {
        NativePage(eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()), title: "今天", subtitle: "默认学习路径优先主题核心词与带 IELTS 标签的扩展词；完整词库仍可在词库页查阅。", accent: .teal) { layout in
            VStack(alignment: .leading, spacing: 21) {
                todayProgress(layout: layout)
                quickChallenge(layout: layout)
                weeklyFootprint
                reviewQueue
            }
        }
        .onAppear { normalizeSelection() }
        .onChange(of: model.selectedWeek) { _, _ in normalizeSelection() }
    }

    private func todayProgress(layout: NativeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if layout.isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("今日学习").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Text("\(studiedCount) / \(dailyWords.count)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText())
                        Text(savedWord.map { "上次停在 \($0.term)" } ?? "还没有开始今天的词单")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("第 \(model.selectedWeek) 周 · 学习日 \(model.selectedDay)")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        Text("每日目标 \(dailyWords.count) 词")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.teal)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("今日学习").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Text("\(studiedCount) / \(dailyWords.count)")
                            .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText())
                        Text(savedWord.map { "上次停在 \($0.term)" } ?? "还没有开始今天的词单")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("第 \(model.selectedWeek) 周 · 学习日 \(model.selectedDay)")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        Text("每日目标 \(dailyWords.count) 词")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.teal)
                    }
                }
            }
            ProgressView(value: Double(studiedCount), total: Double(max(dailyWords.count, 1)))
                .tint(studiedCount == dailyWords.count && !dailyWords.isEmpty ? .green : .teal)
                .animation(stateAnimation, value: studiedCount)
            learningActions
        }
        .padding(20)
        .background(Color.teal.opacity(0.075), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.teal.opacity(0.16), lineWidth: 1))
        .animation(stateAnimation, value: studiedCount)
    }

    private var learningActions: some View {
        HStack(spacing: 10) {
            Button(savedWord == nil ? "开始背词" : "继续背词") {
                model.beginStudying(savedWord)
            }.buttonStyle(.borderedProminent).controlSize(.large)
            if !dailyWords.isEmpty {
                Button("打开整页词单") { model.section = .study }
                    .buttonStyle(.bordered).controlSize(.large)
            }
        }
    }

    private func normalizeSelection() {
        if model.selectedWeek > model.store.recommendedWeekCount {
            model.selectedWeek = model.store.recommendedWeekCount
        }
        let availableDays = model.store.learningDays(forWeek: model.selectedWeek)
        if !availableDays.contains(model.selectedDay) {
            model.selectedDay = availableDays.first ?? 1
        }
    }

    private func quickChallenge(layout: NativeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                NativeSectionHeading(title: "一分钟挑战", trailing: challengeCount > 0 ? "\(challengeCount) 题 · 约 1 分钟" : "今天暂无词条")
            }
            if layout.isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        challengeIcon
                        challengeDescription
                    }
                    Button("开始挑战") { model.beginTraining(.spelling, limit: challengeCount) }
                        .buttonStyle(.borderedProminent).disabled(challengeCount == 0)
                }
            } else {
                HStack(spacing: 16) {
                    challengeIcon
                    challengeDescription
                    Spacer(minLength: 10)
                    Button("开始挑战") { model.beginTraining(.spelling, limit: challengeCount) }
                        .buttonStyle(.borderedProminent).disabled(challengeCount == 0)
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(challengeHovered ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.accentColor.opacity(challengeHovered ? 0.08 : 0), radius: 9, y: 3)
        .onHover { hovering in challengeHovered = hovering }
        .animation(stateAnimation, value: challengeHovered)
    }

    private var challengeIcon: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.orange)
            .frame(width: 35, height: 35)
            .background(Color.orange.opacity(0.12), in: Circle())
    }

    private var challengeDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("用默写快速确认今天的记忆")
                .font(.system(size: 14, weight: .medium))
            Text("从今天的词单中抽取少量题目；错题会进入正常的复习安排。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weeklyFootprint: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本周足迹").font(.system(size: 16, weight: .semibold))
                    Text("点击某天切换词单").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                NativeSelectControl(
                    title: "周次",
                    selection: $model.selectedWeek,
                    options: (1...model.store.recommendedWeekCount).map {
                        NativeSelectionOption(value: $0, title: "第 \($0) 周")
                    },
                    minWidth: 166
                )
            }
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let words = model.store.words(week: model.selectedWeek, day: day)
                    let learned = words.filter { model.store.isWordStudied($0) }.count
                    Button {
                        withAnimation(stateAnimation) { model.selectedDay = day }
                    } label: {
                        VStack(spacing: 8) {
                            Text("D\(day)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(model.selectedDay == day ? Color.accentColor : .secondary)
                            ZStack {
                                Circle().stroke(Color.primary.opacity(0.10), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: words.isEmpty ? 0 : CGFloat(learned) / CGFloat(words.count))
                                    .stroke(learned == words.count && !words.isEmpty ? Color.green : Color.accentColor,
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .animation(stateAnimation, value: learned)
                                Text("\(learned)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                            }.frame(width: 42, height: 42)
                            Text(words.isEmpty ? "—" : "\(learned)/\(words.count)")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(model.selectedDay == day ? Color.accentColor.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help("切换到第 \(day) 天")
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(model.selectedDay == day ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07),
                                    lineWidth: model.selectedDay == day || hoveredDay == day ? 1 : 0)
                    }
                    .scaleEffect(!reduceMotion && (model.selectedDay == day || hoveredDay == day) ? 1.025 : 1)
                    .onHover { hovering in
                        hoveredDay = hovering ? day : (hoveredDay == day ? nil : hoveredDay)
                    }
                    .animation(stateAnimation, value: model.selectedDay == day)
                    .animation(stateAnimation, value: hoveredDay == day)
                }
            }
        }
    }

    private var reviewQueue: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: model.store.dueWords.isEmpty ? "checkmark.circle" : "arrow.clockwise")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(model.store.dueWords.isEmpty ? .green : Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.store.dueWords.isEmpty ? "今天没有到期复习" : "有 \(model.store.dueWords.count) 个词等你回忆")
                    .font(.system(size: 14, weight: .medium))
                Text(model.store.dueWords.isEmpty ? "完成今天的词单后，明天会自动安排下一轮。" : "错题会在本轮末尾再出现一次。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("进入复习") { model.section = .review }
                .buttonStyle(.bordered).disabled(model.store.dueWords.isEmpty)
        }
        .padding(.top, 2)
    }

}

private struct NativeTrainingView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var answerInputFocused: Bool
    @FocusState private var trainingNavigationFocused: Bool
    @ObservedObject private var session: NativeTrainingSession
    private let isReview: Bool

    private var queue: [NativeWord] { get { session.queue } nonmutating set { session.queue = newValue } }
    private var retryQueue: [NativeWord] { get { session.retryQueue } nonmutating set { session.retryQueue = newValue } }
    private var index: Int { get { session.index } nonmutating set { session.index = newValue } }
    private var mode: NativeStudyMode { get { session.mode } nonmutating set { session.mode = newValue } }
    private var selectedOption: String? { get { session.selectedOption } nonmutating set { session.selectedOption = newValue } }
    private var answer: String { get { session.answer } nonmutating set { session.answer = newValue } }
    private var answered: Bool { get { session.answered } nonmutating set { session.answered = newValue } }
    private var correct: Bool { get { session.correct } nonmutating set { session.correct = newValue } }
    private var feedback: String { get { session.feedback } nonmutating set { session.feedback = newValue } }
    private var completed: Bool { get { session.completed } nonmutating set { session.completed = newValue } }
    private var retryRound: Bool { get { session.retryRound } nonmutating set { session.retryRound = newValue } }
    private var showHint: Bool { get { session.showHint } nonmutating set { session.showHint = newValue } }
    private var meaningVisible: Bool { get { session.meaningVisible } nonmutating set { session.meaningVisible = newValue } }
    private var hoveredOptionID: String? { get { session.hoveredOptionID } nonmutating set { session.hoveredOptionID = newValue } }
    private var feedbackVersion: Int { get { session.feedbackVersion } nonmutating set { session.feedbackVersion = newValue } }

    init(session: NativeTrainingSession, isReview: Bool = false) {
        _session = ObservedObject(wrappedValue: session)
        self.isReview = isReview
    }
    private var word: NativeWord? { queue.indices.contains(index) ? queue[index] : nil }
    private var isChallenge: Bool { !isReview && model.trainingLimit != nil }
    private var stateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
    private var questionIdentity: String {
        word?.id ?? (completed ? "completed" : "empty")
    }

    var body: some View {
        ZStack {
            if completed || queue.isEmpty {
                emptyOrComplete
                    .transition(.opacity)
            } else if let word {
                trainingContent(word)
                    .id(word.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($trainingNavigationFocused)
        .animation(stateAnimation, value: questionIdentity)
        .onKeyPress(.leftArrow) {
            guard !answerInputFocused else { return .ignored }
            guard index > 0 else { return .ignored }
            move(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !answerInputFocused else { return .ignored }
            guard let word else { return .ignored }
            if answered {
                advance()
                return .handled
            }
            if mode == .spelling {
                submitSpelling(word)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            startSessionIfNeeded()
            trainingNavigationFocused = true
        }
        .onChange(of: session.requestVersion) { _, _ in startSessionIfNeeded() }
        .onChange(of: mode) { _, _ in
            model.trainingMode = mode
            answerInputFocused = false
            trainingNavigationFocused = true
            hoveredOptionID = nil
        }
        .onChange(of: answerInputFocused) { _, focused in
            if !focused { trainingNavigationFocused = true }
        }
    }

    @ViewBuilder private func trainingContent(_ word: NativeWord) -> some View {
        NativePage(eyebrow: isReview ? "SPACED REVIEW" : isChallenge ? "QUICK CHALLENGE" : "DAILY PRACTICE",
                   title: isReview ? "到期复习" : isChallenge ? "一分钟挑战" : mode.title,
                   subtitle: isChallenge ? "从今天的词单中抽取少量题目，错题仍会进入复习。" : "第 \(model.store.learningLocation(for: word)?.week ?? word.week) 周 · 第 \(model.store.learningDay(for: word)) 天 · \(word.dayTitle) · \(word.track.title)",
                   accent: isReview || isChallenge ? .orange : .indigo) { layout in
            VStack(alignment: .leading, spacing: 22) {
                NativeResponsiveStack(spacing: 12) {
                    NativeSegmentedControl(
                        title: "训练方式", selection: $session.mode,
                        options: NativeStudyMode.allCases.map {
                            NativeSegmentOption(value: $0, title: $0.title, symbol: $0.symbol)
                        },
                        accent: isReview || isChallenge ? .orange : .indigo
                    )
                    .frame(maxWidth: 420)
                    HStack(spacing: 10) {
                        Text("\(min(index + 1, queue.count)) / \(queue.count)")
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        if !isChallenge {
                            Button { withAnimation(stateAnimation) { showHint.toggle() } } label: {
                                Image(systemName: showHint ? "lightbulb.fill" : "lightbulb")
                            }
                            .buttonStyle(.bordered).help("显示提示")
                        }
                    }
                }
                ProgressView(value: Double(index + 1), total: Double(max(queue.count, 1)))
                    .tint(isReview || isChallenge ? .orange : .indigo)
                    .animation(stateAnimation, value: index)
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(mode == .meaning ? "选择对应的释义" : mode == .spelling ? "根据释义写出单词" : "填入句中最合适的词")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        if mode != .meaning {
                            Button { withAnimation(stateAnimation) { meaningVisible.toggle() } } label: {
                                Label(meaningVisible ? "隐藏释义" : "显示释义", systemImage: meaningVisible ? "eye.slash" : "eye")
                            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    prompt(word)
                    if showHint {
                        Text("\(word.ipa)  ·  \(word.partOfSpeech)")
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    if answered {
                        answerFeedback(word)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        answerInput(word)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
                Divider()
                NativeResponsiveStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button { move(-1) } label: { Label("上一题", systemImage: "chevron.left") }
                            .buttonStyle(.bordered).disabled(index == 0)
                        Button { skipCurrent() } label: { Label("跳过", systemImage: "chevron.right") }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Spacer(minLength: 4)
                        trainingAdvanceButton(word)
                    }
                }
            }
        }
    }

    @ViewBuilder private func trainingAdvanceButton(_ word: NativeWord) -> some View {
        if answered {
            Button(retryRound && index == queue.count - 1 ? "完成复练" : "下一题") { advance() }
                .buttonStyle(.borderedProminent).keyboardShortcut(.return)
        } else if mode != .meaning && mode != .context {
            Button("检查答案") { submitSpelling(word) }
                .buttonStyle(.borderedProminent).keyboardShortcut(.return)
        }
    }

    @ViewBuilder private var emptyOrComplete: some View {
        NativePage(eyebrow: "LEARNING", title: completed ? "这一轮完成" : isReview ? "复习队列为空" : "今天没有词条", subtitle: completed ? "回忆过的词已写入本机学习记录。" : "你可以调整周次和学习日后开始新的练习。", accent: completed ? .green : .teal) { _ in
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: completed ? "checkmark.circle" : "tray")
                    .font(.system(size: 30, weight: .light)).foregroundStyle(completed ? .green : .secondary)
                Text(completed ? "答题和错词回练已经写入本机学习记录。" : isReview ? "已学词目前都在下次复习日期之后。" : "这个学习日没有匹配到词条。")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                HStack {
                    Button("回到今天") { model.section = .today }.buttonStyle(.borderedProminent)
                    Button("查看词库") { model.section = .vocabulary }.buttonStyle(.bordered)
                }
            }.padding(.top, 10)
        }
    }

    @ViewBuilder private func prompt(_ word: NativeWord) -> some View {
        switch mode {
        case .meaning:
            VStack(alignment: .leading, spacing: 8) {
                Text(word.term).font(.system(size: 35, weight: .medium, design: .rounded)).textSelection(.enabled)
                HStack(spacing: 10) {
                    Text(word.ipa).font(.system(size: 13, design: .monospaced))
                    Text(word.partOfSpeech)
                }.font(.system(size: 12)).foregroundStyle(.secondary)
            }
        case .spelling:
            VStack(alignment: .leading, spacing: 10) {
                Text(meaningVisible ? model.store.meaning(for: word) : "先回忆词义").font(.system(size: 26, weight: .medium))
                if isChallenge {
                    Text(word.partOfSpeech).font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    Text("\(word.dayTitle)  ·  \(word.partOfSpeech)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if !isChallenge && meaningVisible && !word.collocations.isEmpty {
                    Text("搭配线索：\(word.collocations.first ?? "")").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        case .context:
            VStack(alignment: .leading, spacing: 11) {
                Text(maskedExample(word)).font(.system(size: 21, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true)
                if meaningVisible { Text(model.store.meaning(for: word)).font(.system(size: 12)).foregroundStyle(.secondary) }
            }
        }
    }

    @ViewBuilder private func answerInput(_ word: NativeWord) -> some View {
        switch mode {
        case .spelling:
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    TextField("输入英文单词", text: $session.answer)
                        .textFieldStyle(.roundedBorder).font(.system(size: 16, design: .monospaced))
                        .disableAutocorrection(true)
                        .focused($answerInputFocused)
                        .onSubmit { submitSpelling(word) }
                        .accessibilityLabel("单词拼写答案")
                    Button {
                        session.clearCurrentResponse()
                        answerInputFocused = true
                    } label: {
                        Label("清空", systemImage: "delete.left")
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .fixedSize()
                    .disabled(answer.isEmpty)
                    .help("只清空当前单词的拼写输入")
                    .accessibilityLabel("清空当前拼写答案")
                }
                if !feedback.isEmpty && !answered {
                    Text(feedback).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
        case .meaning, .context:
            VStack(spacing: 4) {
                ForEach(options(for: word), id: \.id) { option in
                    Button {
                        guard !answered else { return }
                        let answerText = option.value
                        withAnimation(stateAnimation) {
                            correct = option.id == word.id
                            feedback = correct ? "答对了" : "再记一下这个词"
                            selectedOption = option.id
                            finishAnswer(word, response: answerText, isCorrect: correct)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(option.label).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 18)
                            Text(option.value).font(.system(size: 14)).foregroundStyle(.primary)
                            Spacer()
                            if selectedOption == option.id {
                                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(correct ? .green : .red)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 13).frame(minHeight: 47)
                        .background(optionFill(for: option.id), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(optionBorder(for: option.id), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                        .scaleEffect(!reduceMotion && hoveredOptionID == option.id && !answered ? 1.008 : 1)
                    }
                    .buttonStyle(.plain).disabled(answered)
                    .onHover { hovering in
                        hoveredOptionID = hovering ? option.id : (hoveredOptionID == option.id ? nil : hoveredOptionID)
                    }
                    .animation(stateAnimation, value: hoveredOptionID == option.id)
                    .animation(stateAnimation, value: selectedOption == option.id)
                }
            }.frame(maxWidth: 520)
        }
    }

    @ViewBuilder private func answerFeedback(_ word: NativeWord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            feedbackSymbol(correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .foregroundStyle(correct ? .green : .orange).font(.system(size: 19))
            VStack(alignment: .leading, spacing: 4) {
                Text(feedback).font(.system(size: 13, weight: .medium))
                Text("\(word.term)  ·  \(model.store.meaning(for: word))").font(.system(size: 12)).foregroundStyle(.secondary)
                if !word.collocations.isEmpty { Text(word.collocations.prefix(2).joined(separator: "   ·   ")).font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            Spacer()
            pronunciation(word)
        }
        .padding(14).frame(maxWidth: 570, alignment: .leading)
        .background(correct ? Color.green.opacity(0.075) : Color.orange.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(correct ? Color.green.opacity(0.18) : Color.orange.opacity(0.18), lineWidth: 1))
    }

    @ViewBuilder private func feedbackSymbol(_ name: String) -> some View {
        if reduceMotion {
            Image(systemName: name)
        } else {
            Image(systemName: name).symbolEffect(.bounce, value: feedbackVersion)
        }
    }

    private func pronunciation(_ word: NativeWord) -> some View {
        HStack(spacing: 5) {
            ForEach([("GB", "en-GB"), ("US", "en-US")], id: \.0) { label, locale in
                Button(label) { Task { @MainActor in try? VocabularySpeech.shared.speak(text: word.term, locale: locale) } }
                    .buttonStyle(.bordered).controlSize(.small).help("播放\(label == "GB" ? "英式" : "美式")发音")
            }
        }
    }

    private func options(for word: NativeWord) -> [(id: String, value: String, label: String)] {
        let pool = model.store.words.filter { $0.id != word.id }
        guard !pool.isEmpty else { return [(word.id, model.store.meaning(for: word), "A")] }
        let seed = stableHash(word.id)
        let distractors = (0..<min(3, pool.count)).map { offset in pool[(seed + offset * 733) % pool.count] }
        let choices = ([word] + distractors).sorted {
            let left = stableHash(word.id + $0.id)
            let right = stableHash(word.id + $1.id)
            return left == right ? $0.id < $1.id : left < right
        }
        return choices.enumerated().map { index, choice in
            (choice.id, mode == .meaning ? model.store.meaning(for: choice) : choice.term, String(UnicodeScalar(65 + index)!))
        }
    }

    private func optionFill(for id: String) -> Color {
        if selectedOption == id { return correct ? Color.green.opacity(0.09) : Color.red.opacity(0.08) }
        return hoveredOptionID == id ? Color.accentColor.opacity(0.045) : Color(nsColor: .controlBackgroundColor)
    }

    private func optionBorder(for id: String) -> Color {
        if selectedOption == id { return correct ? Color.green.opacity(0.32) : Color.red.opacity(0.28) }
        return hoveredOptionID == id ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07)
    }

    private func stableHash(_ value: String) -> Int {
        value.utf8.reduce(5_381) { (($0 << 5) &+ $0) ^ Int($1) } & 0x7fff_ffff
    }

    private func maskedExample(_ word: NativeWord) -> String {
        if let masked = word.maskedExample, !masked.isEmpty { return masked }
        let replaced = word.exampleEn.replacingOccurrences(of: word.term, with: "_____", options: .caseInsensitive)
        return replaced == word.exampleEn ? word.exampleEn : replaced
    }

    private func startSession(mode nextMode: NativeStudyMode) {
        mode = nextMode
        let candidates: [NativeWord]
        if isReview {
            candidates = model.store.dueWords
        } else if let ids = model.trainingWordIDs {
            let wanted = Set(ids)
            candidates = model.store.words.filter { wanted.contains($0.id) }
        } else {
            candidates = model.store.words(week: model.selectedWeek, day: model.selectedDay)
        }
        if let pending = model.pendingWordID, let matching = candidates.first(where: { $0.id == pending }) {
            queue = [matching] + candidates.filter { $0.id != pending }.shuffled()
            model.pendingWordID = nil
        } else {
            queue = candidates.shuffled()
        }
        if !isReview, let limit = model.trainingLimit {
            queue = Array(queue.prefix(max(1, limit)))
        }
        retryQueue = []; index = 0; completed = false; retryRound = false
        session.resetResponses()
        showHint = false; meaningVisible = true
        session.startedVersion = session.requestVersion
    }

    private func startSessionIfNeeded() {
        guard session.startedVersion != session.requestVersion else { return }
        startSession(mode: session.mode)
    }

    private func resetQuestion() {
        hoveredOptionID = nil
        answerInputFocused = false
    }

    private func submitSpelling(_ word: NativeWord) {
        guard !answered else { return }
        let typed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { feedback = "先输入一个答案"; return }
        answerInputFocused = false
        trainingNavigationFocused = true
        let normalized = typed.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let target = word.term.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let distance = spellingDistance(normalized, target)
        correct = distance <= 1
        feedback = distance == 0 ? "拼写正确" : distance == 1 ? "差一个字母，已识别" : "再写一次会更牢"
        finishAnswer(word, response: typed, isCorrect: correct)
    }

    private func finishAnswer(_ word: NativeWord, response: String, isCorrect: Bool) {
        withAnimation(stateAnimation) { answered = true; feedbackVersion += 1 }
        if !isCorrect && !retryRound && !retryQueue.contains(where: { $0.id == word.id }) {
            retryQueue.append(word)
        }
        model.store.recordAnswer(word: word, mode: mode.rawValue, response: response, correct: isCorrect)
    }

    private func move(_ offset: Int) {
        guard !queue.isEmpty else { return }
        if offset < 0 {
            withAnimation(stateAnimation) { index = max(0, index - 1); resetQuestion() }
            return
        }
        advance()
    }

    private func skipCurrent() {
        guard let word else { return }
        if !answered {
            correct = false
            feedback = "已跳过"
            finishAnswer(word, response: "", isCorrect: false)
        }
        advance()
    }

    private func advance() {
        if index + 1 < queue.count {
            withAnimation(stateAnimation) { index += 1; resetQuestion() }
            return
        }
        if !retryRound && !retryQueue.isEmpty {
            withAnimation(stateAnimation) {
                queue = retryQueue.shuffled(); retryQueue = []; index = 0; retryRound = true; resetQuestion()
            }
            return
        }
        withAnimation(stateAnimation) { completed = true }
    }

    private func spellingDistance(_ left: String, _ right: String) -> Int {
        let a = Array(left), b = Array(right)
        if abs(a.count - b.count) > 1 { return 2 }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + (ca == cb ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}

private struct NativeReviewView: View {
    @EnvironmentObject private var model: NativeAppModel
    var body: some View {
        if model.reviewStarted {
            NativeTrainingView(session: model.reviewSession, isReview: true)
        } else {
            NativePage(eyebrow: "SPACED REVIEW", title: "到期复习", subtitle: "先复习已学词；错题会在本轮末尾再出现一次。", accent: .orange) { _ in
                HStack(spacing: 22) {
                    NativeMetric(label: "待复习", value: model.store.dueWords.count.formatted(), detail: "仅统计已学且已到期词条")
                    NativeMetric(label: "稳定掌握", value: model.store.masteredWordCount.formatted(), detail: "熟练度达到 4 / 5")
                }
                Divider()
                if model.store.dueWords.isEmpty {
                    Label("复习队列已清空", systemImage: "checkmark.circle").font(.system(size: 15)).foregroundStyle(.secondary)
                } else {
                    Button("开始复习") { model.beginReview() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
