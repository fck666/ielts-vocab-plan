import AppKit
import CoreGraphics
import Foundation
import SwiftUI

private struct DesktopCardWord: Decodable, Identifiable {
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

@MainActor
private final class DesktopVocabularyCardModel: ObservableObject {
    @Published private(set) var selectedWeek: Int
    @Published private(set) var selectedDay: Int
    @Published private(set) var batchIndex = 0
    @Published private(set) var wordIndex = 0
    @Published private(set) var isRevealed = false
    @Published var isAutoAdvancePaused = true
    var onWordChange: (() -> Void)?

    let weeks: [Int]
    private let words: [DesktopCardWord]
    private let defaults = UserDefaults.standard

    var availableDays: [Int] {
        Array(Set(words.filter { $0.week == selectedWeek }.map(\.day))).sorted()
    }

    var dayWords: [DesktopCardWord] {
        words.filter { $0.week == selectedWeek && $0.day == selectedDay }.sorted { $0.index < $1.index }
    }

    var batchCount: Int {
        max(1, (dayWords.count + 9) / 10)
    }

    var batchWords: [DesktopCardWord] {
        let start = batchIndex * 10
        guard start < dayWords.count else { return [] }
        return Array(dayWords[start..<min(start + 10, dayWords.count)])
    }

    var currentWord: DesktopCardWord? {
        let items = batchWords
        return items.indices.contains(wordIndex) ? items[wordIndex] : items.first
    }

    func title(for day: Int) -> String {
        words.first(where: { $0.week == selectedWeek && $0.day == day })?.dayTitle ?? ""
    }

    init() {
        let root = Bundle.main.resourceURL?.appendingPathComponent("site/data/words.json")
        let data = root.flatMap { try? Data(contentsOf: $0) }
        let decoded = data.flatMap { try? JSONDecoder().decode([DesktopCardWord].self, from: $0) } ?? []
        words = decoded
        weeks = Array(Set(decoded.map(\.week))).sorted()

        let savedWeek = defaults.integer(forKey: "desktopCard.week")
        let initialWeek = weeks.contains(savedWeek) ? savedWeek : (weeks.first ?? 1)
        selectedWeek = initialWeek

        let days = Array(Set(decoded.filter { $0.week == initialWeek }.map(\.day))).sorted()
        let savedDay = defaults.integer(forKey: "desktopCard.day")
        selectedDay = days.contains(savedDay) ? savedDay : (days.first ?? 1)
        let savedWordIndex = max(0, defaults.integer(forKey: indexKey))
        if defaults.object(forKey: batchKey) == nil {
            // Migrate the pre-batch card index, which represented a position in the whole day.
            batchIndex = min(savedWordIndex / 10, batchCount - 1)
            wordIndex = savedWordIndex % 10
        } else {
            batchIndex = max(0, defaults.integer(forKey: batchKey))
            wordIndex = savedWordIndex
        }
        isRevealed = defaults.bool(forKey: revealKey)
        normalizeIndex()
    }

    func selectWeek(_ week: Int) {
        guard weeks.contains(week) else { return }
        selectedWeek = week
        let days = availableDays
        if !days.contains(selectedDay) { selectedDay = days.first ?? 1 }
        batchIndex = 0
        wordIndex = 0
        isRevealed = false
        persistSelection()
        onWordChange?()
    }

    func selectDay(_ day: Int) {
        guard availableDays.contains(day) else { return }
        selectedDay = day
        batchIndex = 0
        wordIndex = 0
        isRevealed = false
        persistSelection()
        onWordChange?()
    }

    func toggleMeaning() {
        isRevealed.toggle()
        defaults.set(isRevealed, forKey: revealKey)
    }

    func nextWord() {
        let count = batchWords.count
        guard count > 0 else { return }
        wordIndex = (wordIndex + 1) % count
        isRevealed = false
        defaults.set(wordIndex, forKey: indexKey)
        defaults.set(false, forKey: revealKey)
        onWordChange?()
    }

    func previousWord() {
        let count = batchWords.count
        guard count > 0 else { return }
        wordIndex = (wordIndex + count - 1) % count
        isRevealed = false
        defaults.set(wordIndex, forKey: indexKey)
        defaults.set(false, forKey: revealKey)
        onWordChange?()
    }

    func changeBatch() {
        guard batchCount > 1 else { return }
        batchIndex = (batchIndex + 1) % batchCount
        wordIndex = 0
        isRevealed = false
        defaults.set(batchIndex, forKey: batchKey)
        defaults.set(wordIndex, forKey: indexKey)
        defaults.set(false, forKey: revealKey)
        onWordChange?()
    }

    func openDictation() {
        guard let word = currentWord else { return }
        var components = URLComponents()
        components.scheme = "ieltsvocab"
        components.host = "study"
        components.queryItems = [
            URLQueryItem(name: "week", value: String(selectedWeek)),
            URLQueryItem(name: "day", value: String(selectedDay)),
            URLQueryItem(name: "word", value: word.id),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    func pronounce(locale: String) {
        guard let word = currentWord else { return }
        do { try VocabularySpeech.shared.speak(text: word.term, locale: locale) }
        catch {
            let alert = NSAlert()
            alert.messageText = "无法朗读"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private var indexKey: String { "desktopCard.index.w\(selectedWeek).d\(selectedDay)" }
    private var batchKey: String { "desktopCard.batch.w\(selectedWeek).d\(selectedDay)" }
    private var revealKey: String { "desktopCard.revealed.w\(selectedWeek).d\(selectedDay)" }

    private func persistSelection() {
        defaults.set(selectedWeek, forKey: "desktopCard.week")
        defaults.set(selectedDay, forKey: "desktopCard.day")
        defaults.set(batchIndex, forKey: batchKey)
        defaults.set(wordIndex, forKey: indexKey)
        defaults.set(isRevealed, forKey: revealKey)
    }

    private func normalizeIndex() {
        batchIndex = min(batchIndex, batchCount - 1)
        defaults.set(batchIndex, forKey: batchKey)
        let count = batchWords.count
        wordIndex = count > 0 ? wordIndex % count : 0
        defaults.set(wordIndex, forKey: indexKey)
    }
}

@MainActor
private final class DesktopCardDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        window?.performDrag(with: event)
        NSCursor.openHand.set()
    }
}

private struct DesktopCardDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DesktopCardDragView {
        let view = DesktopCardDragView()
        view.toolTip = "按住这里拖动卡片，位置会自动保存"
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel("拖动卡片移动位置")
        return view
    }

    func updateNSView(_ nsView: DesktopCardDragView, context: Context) {}
}

@MainActor
private final class DesktopCardPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private struct DesktopVocabularyCardView: View {
    @ObservedObject var model: DesktopVocabularyCardModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("IELTS VOCABULARY LAB")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(model.currentWord?.dayTitle ?? "IELTS Vocabulary")
                        Text("· 拖动这里移动")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay { DesktopCardDragArea() }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(.plain)
                .help("关闭桌面词卡")
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(model.weeks, id: \.self) { week in
                        Button {
                            model.selectWeek(week)
                        } label: {
                            if week == model.selectedWeek { Label("Week \(week)", systemImage: "checkmark") }
                            else { Text("Week \(week)") }
                        }
                    }
                } label: {
                    Label("Week \(model.selectedWeek)", systemImage: "calendar")
                }

                Menu {
                    ForEach(model.availableDays, id: \.self) { day in
                        let title = model.title(for: day)
                        Button {
                            model.selectDay(day)
                        } label: {
                            if day == model.selectedDay { Label("Day \(day) · \(title)", systemImage: "checkmark") }
                            else { Text("Day \(day) · \(title)") }
                        }
                    }
                } label: {
                    Label("Day \(model.selectedDay)", systemImage: "sun.max")
                }

                Button {
                    model.changeBatch()
                } label: {
                    Label("换一批", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(model.batchCount <= 1)
                .help("当前第 \(model.batchIndex + 1) / \(model.batchCount) 批，每批最多 10 个单词")
            }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(.bordered)
            .padding(.top, 12)

            if let word = model.currentWord {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.term)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer(minLength: 4)
                    Text(word.ipa)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 15)

                HStack {
                    Text(word.partOfSpeech)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { model.pronounce(locale: "en-GB") } label: {
                        Label("英音 UK", systemImage: "speaker.wave.2")
                    }
                    Button { model.pronounce(locale: "en-US") } label: {
                        Label("美音 US", systemImage: "speaker.wave.2")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.bordered)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.isRevealed ? "释义与搭配" : "先回忆，再看答案")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(model.isRevealed ? word.meaningZh : "回忆这个词在“\(word.dayTitle)”话题中的意思")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                    if model.isRevealed, let collocation = word.collocations.first {
                        Text(collocation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
                .padding(.top, 11)

                Spacer(minLength: 10)

                HStack(spacing: 7) {
                    Button(model.isRevealed ? "收起释义" : "显示释义") {
                        model.toggleMeaning()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primary.opacity(0.12))

                    Button {
                        model.previousWord()
                    } label: {
                        Label("上一词", systemImage: "arrow.left")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        model.nextWord()
                    } label: {
                        Label("下一词", systemImage: "arrow.right")
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 0)

                    Button {
                        model.openDictation()
                    } label: {
                        Label("网页默写", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                }

                HStack {
                    Text("第 \(model.batchIndex + 1) / \(model.batchCount) 批 · \(model.wordIndex + 1) / \(model.batchWords.count) 词")
                    Spacer()
                    Text(model.isAutoAdvancePaused ? "自动切词已暂停" : "每分钟自动切词")
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.top, 7)
            } else {
                Spacer()
                Text("没有找到词库文件")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 390, height: 326)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
        .padding(8)
    }
}

@MainActor
final class DesktopVocabularyCardWindowController: NSWindowController, NSWindowDelegate {
    private static let positionAutosaveName = "IELTSDesktopVocabularyCard"
    var onClose: (() -> Void)?
    private let model: DesktopVocabularyCardModel
    private var autoAdvanceTimer: Timer?
    private var visibleSince: TimeInterval?
    private var lastCheckedAt: TimeInterval?
    private var isSystemAwake = true
    private var isDisplayAwake = true
    private var isSessionActive = true

    init() {
        let model = DesktopVocabularyCardModel()
        self.model = model
        let panel = DesktopCardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 406, height: 342),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        // Keep the card above desktop icons and below ordinary application windows.
        // Set this after isFloatingPanel, whose setter resets the window level.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: DesktopVocabularyCardView(model: model, onClose: { [weak panel] in panel?.close() }))

        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - panel.frame.width - 28, y: screen.maxY - panel.frame.height - 70))
        }
        super.init(window: panel)
        let cardSize = panel.frame.size
        panel.setFrameAutosaveName(Self.positionAutosaveName)
        panel.setFrameUsingName(Self.positionAutosaveName)
        panel.setContentSize(cardSize)
        panel.delegate = self
        keepCardOnScreen()
        model.onWordChange = { [weak self] in
            self?.visibleSince = nil
            self?.refreshAutoAdvance()
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(workspaceStateChanged(_:)), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func showCard() {
        keepCardOnScreen()
        showWindow(nil)
        window?.orderFront(nil)
        startAutoAdvanceTimer()
    }

    func windowDidMove(_ notification: Notification) {
        window?.saveFrame(usingName: Self.positionAutosaveName)
        visibleSince = nil
    }

    @objc private func screenConfigurationChanged() {
        keepCardOnScreen()
    }

    private func keepCardOnScreen() {
        guard let window else { return }
        let screens = NSScreen.screens.map(\.visibleFrame)
        let screen = screens.max { lhs, rhs in
            let left = window.frame.intersection(lhs)
            let right = window.frame.intersection(rhs)
            return (left.isNull ? 0 : left.width * left.height) < (right.isNull ? 0 : right.width * right.height)
        }
        let hasVisibleArea = screen.map { !window.frame.intersection($0).isNull } ?? false
        guard let visibleFrame = hasVisibleArea ? screen : NSScreen.main?.visibleFrame else { return }
        var origin = window.frame.origin
        origin.x = min(max(origin.x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - window.frame.width))
        origin.y = min(max(origin.y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - window.frame.height))
        if origin != window.frame.origin { window.setFrameOrigin(origin) }
        window.saveFrame(usingName: Self.positionAutosaveName)
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        refreshAutoAdvance()
    }

    @objc private func workspaceStateChanged(_ notification: Notification) {
        switch notification.name {
        case NSWorkspace.willSleepNotification: isSystemAwake = false
        case NSWorkspace.didWakeNotification: isSystemAwake = true
        case NSWorkspace.screensDidSleepNotification: isDisplayAwake = false
        case NSWorkspace.screensDidWakeNotification: isDisplayAwake = true
        case NSWorkspace.sessionDidResignActiveNotification: isSessionActive = false
        case NSWorkspace.sessionDidBecomeActiveNotification: isSessionActive = true
        default: return
        }
        visibleSince = nil
        lastCheckedAt = nil
        refreshAutoAdvance()
    }

    private func startAutoAdvanceTimer() {
        guard autoAdvanceTimer == nil else { return }
        refreshAutoAdvance()
        autoAdvanceTimer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, self.autoAdvanceTimer === timer else { return }
                self.refreshAutoAdvance()
            }
        }
        if let autoAdvanceTimer {
            RunLoop.main.add(autoAdvanceTimer, forMode: .common)
        }
    }

    private func refreshAutoAdvance() {
        let now = ProcessInfo.processInfo.systemUptime
        // Resume with a full minute after sleep, suspension or a delayed run loop.
        if let lastCheckedAt, now - lastCheckedAt > 3 { visibleSince = nil }
        lastCheckedAt = now
        guard isCardUncovered else {
            visibleSince = nil
            model.isAutoAdvancePaused = true
            return
        }
        model.isAutoAdvancePaused = false
        guard let visibleSince else {
            self.visibleSince = now
            return
        }
        if now - visibleSince >= 60 {
            self.visibleSince = now
            model.nextWord()
        }
    }

    private var isCardUncovered: Bool {
        guard isSystemAwake, isDisplayAwake, isSessionActive,
              let window, window.isVisible, window.occlusionState.contains(.visible) else { return false }
        let number = CGWindowID(window.windowNumber)
        // Window metadata is sufficient; no screen capture or recording permission is needed.
        guard let ownWindows = CGWindowListCopyWindowInfo(.optionIncludingWindow, number) as? [[String: Any]],
              let ownBounds = ownWindows.first?[kCGWindowBounds as String] as? NSDictionary,
              let ownRect = CGRect(dictionaryRepresentation: ownBounds),
              let aboveWindows = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow, .excludeDesktopElements], number) as? [[String: Any]] else {
            return false
        }
        let cardRect = ownRect.insetBy(dx: 8, dy: 8)
        return !aboveWindows.contains { info in
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
            return !rect.isEmpty && cardRect.intersects(rect)
        }
    }

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: Self.positionAutosaveName)
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        visibleSince = nil
        lastCheckedAt = nil
        model.isAutoAdvancePaused = true
        onClose?()
    }
}
