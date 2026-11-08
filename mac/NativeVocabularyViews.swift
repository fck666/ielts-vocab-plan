import SwiftUI

private struct NativeDailyWordState {
    var isWriting: Bool
    var meaningVisible: Bool
    var expanded = false
    var answer = ""
    var revealed = false
    var submitted = false
    var spellingCorrect = false
    var feedback = ""

    mutating func resetWriting() {
        answer = ""; revealed = false; submitted = false
        spellingCorrect = false; feedback = ""
    }
}

private enum NativeDailyStudyFocus: Hashable {
    case card(String)
    case input(String)
}

struct NativeDailyStudyView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: NativeLearningStore
    @AppStorage("native.study.cardMode") private var cardMode = "read"
    @AppStorage("native.study.showMeaning") private var showMeaning = true
    @State private var rowStates: [String: NativeDailyWordState] = [:]
    @State private var speechError: String?
    @FocusState private var focusedTarget: NativeDailyStudyFocus?

    private var dailyWords: [NativeWord] { store.words(week: model.selectedWeek, day: model.selectedDay) }
    private var studiedCount: Int { dailyWords.filter { store.isWordStudied($0) }.count }
    private var dayKey: String { "\(model.selectedWeek)-\(model.selectedDay)" }
    private var stateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    var body: some View {
        ScrollViewReader { proxy in
            NativePage(eyebrow: "DAILY VOCABULARY", title: "每日背词", subtitle: "当天词单集中展示，上下滚动学习，也可以逐词打字默写。大多数学习日为 20 词。", accent: .teal) { layout in
                VStack(alignment: .leading, spacing: 18) {
                    dateControls(layout: layout).id("daily-study-top")
                    if !dailyWords.isEmpty {
                        if layout.isCompact {
                            VStack(alignment: .leading, spacing: 10) {
                                wordListHeading
                                HStack(spacing: 12) {
                                    dailyModePicker
                                    meaningToggle
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                wordListHeading
                                Spacer(minLength: 8)
                                dailyModePicker
                                meaningToggle
                            }
                        }
                        Text("每个词都能单独听音、查看详细用法、切换默写和标记已学。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        VStack(spacing: 8) {
                            ForEach(Array(dailyWords.enumerated()), id: \.element.id) { offset, word in
                                NativeDailyStudyRow(word: word, number: offset + 1, store: store,
                                                    state: stateBinding(for: word),
                                                    focusTarget: $focusedTarget,
                                                    onInteract: { store.saveStudyPosition(word) }, onSpeak: speak,
                                                    onNavigate: { direction in
                                                        navigateWord(direction, from: word, proxy: proxy)
                                                    })
                                    .id(word.id)
                            }
                        }
                        .padding(9)
                        .background(Color(nsColor: .separatorColor).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.20), lineWidth: 1))
                        footer
                    } else {
                        ContentUnavailableView("这个学习日没有词条", systemImage: "book.pages", description: Text("请选择其他周次和学习日。"))
                    }
                }
            }
            .onAppear { restorePosition(proxy) }
            .onChange(of: dayKey) { _, _ in
                VocabularySpeech.shared.stop()
                restorePosition(proxy)
            }
            .onChange(of: cardMode) { _, mode in
                withAnimation(stateAnimation) {
                    for word in dailyWords {
                        var next = state(for: word)
                        next.isWriting = mode == "write"
                        rowStates[word.id] = next
                    }
                }
            }
        }
        .navigationTitle("每日背词 · \(dailyWords.count) 词")
        .onDisappear { VocabularySpeech.shared.stop() }
        .alert("发音暂不可用", isPresented: Binding(get: { speechError != nil }, set: { if !$0 { speechError = nil } })) {
            Button("好", role: .cancel) { speechError = nil }
        } message: { Text(speechError ?? "") }
    }

    private func dateControls(layout: NativeLayoutMetrics) -> some View {
        Group {
            if layout.isCompact {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 12) { weekPicker; dayPicker }
                    Text("本日已学 \(studiedCount) / \(dailyWords.count)")
                        .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
            } else {
                HStack(spacing: 12) {
                    weekPicker
                    dayPicker
                    Spacer(minLength: 8)
                    Text("本日已学 \(studiedCount) / \(dailyWords.count)")
                        .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private var weekPicker: some View {
        NativeSelectControl(
            title: "周次",
            selection: $model.selectedWeek,
            options: (1...model.store.recommendedWeekCount).map {
                NativeSelectionOption(value: $0, title: "第 \($0) 周")
            },
            minWidth: 170
        )
    }

    private var dayPicker: some View {
        NativeSelectControl(
            title: "学习日",
            selection: $model.selectedDay,
            options: (1...6).map { NativeSelectionOption(value: $0, title: "第 \($0) 天") },
            minWidth: 170
        )
    }

    private var wordListHeading: some View {
        HStack(spacing: 9) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.teal)
                .frame(width: 29, height: 29)
                .background(Color.teal.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(dailyWords.first?.dayTitle ?? "本日词单")
                    .font(.system(size: 13, weight: .medium))
                Text("本页共 \(dailyWords.count) 词")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var dailyModePicker: some View {
        Picker("全页模式", selection: $cardMode) {
            Text("阅读背词").tag("read")
            Text("全部默写").tag("write")
        }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 195)
    }

    private var meaningToggle: some View {
        Button {
            withAnimation(stateAnimation) {
                showMeaning.toggle()
                for word in dailyWords {
                    var next = state(for: word)
                    next.meaningVisible = showMeaning
                    rowStates[word.id] = next
                }
            }
        } label: {
            Label(showMeaning ? "隐藏全部释义" : "显示全部释义", systemImage: showMeaning ? "eye.slash" : "eye")
        }.buttonStyle(.borderless).font(.system(size: 11))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(studiedCount == dailyWords.count ? "本日词单已学完" : "本日已学 \(studiedCount) / \(dailyWords.count) 词",
                      systemImage: studiedCount == dailyWords.count ? "checkmark.circle" : "book.pages")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("去每日训练") { model.beginTraining(.meaning) }.buttonStyle(.borderedProminent)
            }
            Text("进度自动保存；标记已学后安排次日复习，不增加答题次数。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }

    private func state(for word: NativeWord) -> NativeDailyWordState {
        rowStates[word.id] ?? NativeDailyWordState(isWriting: cardMode == "write", meaningVisible: showMeaning)
    }

    private func stateBinding(for word: NativeWord) -> Binding<NativeDailyWordState> {
        Binding(get: { state(for: word) }, set: { rowStates[word.id] = $0 })
    }

    private func restorePosition(_ proxy: ScrollViewProxy) {
        let target = model.pendingWordID ?? store.studyPosition(week: model.selectedWeek, day: model.selectedDay)
        model.pendingWordID = nil
        let targetID = dailyWords.contains { $0.id == target } ? target : nil
        // Restore only after this day's rows enter the view hierarchy.
        DispatchQueue.main.async { proxy.scrollTo(targetID ?? "daily-study-top", anchor: .top) }
    }

    private func navigateWord(_ offset: Int, from word: NativeWord, proxy: ScrollViewProxy) {
        guard let currentIndex = dailyWords.firstIndex(where: { $0.id == word.id }) else { return }
        let nextIndex = currentIndex + offset
        guard dailyWords.indices.contains(nextIndex) else { return }
        let nextWord = dailyWords[nextIndex]
        store.saveStudyPosition(nextWord)
        withAnimation(stateAnimation) { proxy.scrollTo(nextWord.id, anchor: .center) }
        DispatchQueue.main.async {
            focusedTarget = state(for: nextWord).isWriting ? .input(nextWord.id) : .card(nextWord.id)
        }
    }

    private func speak(_ text: String, locale: String) {
        do { try VocabularySpeech.shared.speak(text: text, locale: locale) }
        catch { speechError = error.localizedDescription }
    }
}

private struct NativeDailyStudyRow: View {
    let word: NativeWord
    let number: Int
    @ObservedObject var store: NativeLearningStore
    @Binding var state: NativeDailyWordState
    @FocusState.Binding var focusTarget: NativeDailyStudyFocus?
    let onInteract: () -> Void
    let onSpeak: (String, String) -> Void
    let onNavigate: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var answerVisible: Bool { !state.isWriting || state.revealed || state.submitted }
    private var isStudied: Bool { store.isWordStudied(word) }
    private var isCardFocused: Bool { focusTarget == .card(word.id) }
    private var indexColor: Color { isStudied ? .green : .teal }
    private var cardFill: Color {
        if isHovered || isCardFocused { return Color.teal.opacity(0.07) }
        if isStudied { return Color.green.opacity(0.045) }
        return Color(nsColor: .windowBackgroundColor)
    }
    private var cardStroke: Color {
        if isHovered || isCardFocused { return Color.teal.opacity(0.25) }
        if isStudied { return Color.green.opacity(0.17) }
        return Color(nsColor: .separatorColor).opacity(0.28)
    }
    private var stateAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(indexColor)
                    .frame(width: 28, height: 28)
                    .background(indexColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    if answerVisible {
                        Text(word.term).font(.system(size: 21, weight: .medium, design: .rounded)).textSelection(.enabled)
                            .transition(.opacity)
                        HStack(spacing: 8) {
                            Text(word.ipa)
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            partOfSpeechBadge
                        }.transition(.opacity)
                    } else {
                        Text("第 \(number) 词 · 根据释义默写").font(.system(size: 15, weight: .medium))
                            .transition(.opacity)
                        partOfSpeechBadge.transition(.opacity)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    speechButton("英音", locale: "en-GB")
                    speechButton("美音", locale: "en-US")
                }
            }
            if state.isWriting || state.meaningVisible {
                Text(store.meaning(for: word)).font(.system(size: 14, weight: .medium))
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else {
                Text("释义已隐藏，先回忆一下。")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
            if state.isWriting {
                writingArea.transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack(spacing: 14) {
                Button {
                    withAnimation(stateAnimation) {
                        state.isWriting.toggle()
                        if state.isWriting { focusTarget = .input(word.id) }
                        onInteract()
                    }
                } label: {
                    Label(state.isWriting ? "阅读" : "默写", systemImage: state.isWriting ? "book" : "keyboard")
                }.accessibilityLabel("第 \(number) 词：\(state.isWriting ? "切换阅读" : "切换默写")")
                if !state.isWriting {
                    Button {
                        withAnimation(stateAnimation) {
                            state.meaningVisible.toggle()
                            onInteract()
                        }
                    } label: {
                        Label(state.meaningVisible ? "隐藏释义" : "显示释义", systemImage: state.meaningVisible ? "eye.slash" : "eye")
                    }.accessibilityLabel("第 \(number) 词：\(state.meaningVisible ? "隐藏释义" : "显示释义")")
                }
                if answerVisible {
                    Button {
                        withAnimation(stateAnimation) {
                            state.expanded.toggle()
                            onInteract()
                        }
                    } label: {
                        Label(state.expanded ? "收起详情" : "详细用法", systemImage: state.expanded ? "chevron.up" : "chevron.down")
                    }.accessibilityLabel("第 \(number) 词：\(state.expanded ? "收起详情" : "详细用法")")
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(stateAnimation) {
                        if store.markWordStudied(word) { onInteract() }
                    }
                } label: {
                    Label(store.isWordStudied(word) ? "已学" : "标记已学", systemImage: store.isWordStudied(word) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(store.isWordStudied(word) ? Color.green : Color.teal)
                }
                .disabled(store.isWordStudied(word))
                .accessibilityLabel("第 \(number) 词：\(store.isWordStudied(word) ? "已学" : "标记已学")")
            }
            .buttonStyle(.borderless).font(.system(size: 11))
            if state.expanded && answerVisible {
                details.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusable()
        .focused($focusTarget, equals: .card(word.id))
        .onKeyPress(.leftArrow) { handleArrow(-1) }
        .onKeyPress(.rightArrow) { handleArrow(1) }
        .background(RoundedRectangle(cornerRadius: 9).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(cardStroke, lineWidth: isHovered || isCardFocused ? 1.2 : 0.8))
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
        .animation(stateAnimation, value: isCardFocused)
        .animation(stateAnimation, value: isStudied)
        .animation(stateAnimation, value: state.isWriting)
        .animation(stateAnimation, value: state.meaningVisible)
        .animation(stateAnimation, value: state.expanded)
        .animation(stateAnimation, value: state.revealed)
        .animation(stateAnimation, value: state.submitted)
        .animation(stateAnimation, value: store.isWordStudied(word))
    }

    private var writingArea: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                TextField("输入英文单词", text: $state.answer)
                    .font(.system(size: 16, design: .monospaced)).textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true).focused($focusTarget, equals: .input(word.id)).disabled(state.submitted)
                    .accessibilityLabel("第 \(number) 词默写输入")
                    .onSubmit { checkSpelling() }
                Button("检查") { checkSpelling() }
                    .buttonStyle(.bordered)
                    .disabled(state.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.submitted)
                    .accessibilityLabel("检查第 \(number) 词拼写")
                if !answerVisible {
                    Button("看答案") {
                        withAnimation(stateAnimation) {
                            state.revealed = true
                            state.feedback = "已查看答案，这次不计成绩。"
                            onInteract()
                        }
                    }.buttonStyle(.borderless).font(.system(size: 11))
                        .accessibilityLabel("查看第 \(number) 词答案")
                }
                if state.submitted || state.revealed {
                    Button("再写") {
                        withAnimation(stateAnimation) {
                            state.resetWriting()
                            focusTarget = .input(word.id)
                            onInteract()
                        }
                    }.buttonStyle(.borderless).font(.system(size: 11))
                        .accessibilityLabel("第 \(number) 词再写一次")
                }
            }
            if !state.feedback.isEmpty {
                Label(state.feedback, systemImage: state.spellingCorrect ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: 11)).foregroundStyle(state.spellingCorrect ? Color.green : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var partOfSpeechBadge: some View {
        Text(word.partOfSpeech)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.teal)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.teal.opacity(0.09), in: Capsule())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 13) {
            Divider()
            if !word.collocations.isEmpty { detail("常见搭配", text: word.collocations.joined(separator: "   ·   ")) }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("例句").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Button { onSpeak(word.exampleEn, "en-GB"); onInteract() } label: {
                        Label("朗读例句", systemImage: "speaker.wave.2")
                    }.buttonStyle(.borderless).font(.system(size: 11))
                }
                Text(word.exampleEn).font(.system(size: 14, design: .serif))
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if state.meaningVisible {
                    Text(store.exampleTranslation(for: word)).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !store.family(for: word).isEmpty { detail("词族", text: store.family(for: word)) }
            if state.meaningVisible && !store.note(for: word).isEmpty { detail("用法提示", text: store.note(for: word)) }
        }.padding(.top, 1)
    }

    private func detail(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func speechButton(_ title: String, locale: String) -> some View {
        Button { onSpeak(word.term, locale); onInteract() } label: { Label(title, systemImage: "speaker.wave.2") }
            .buttonStyle(.bordered).controlSize(.small)
            .accessibilityLabel("第 \(number) 词\(title)")
    }

    private func checkSpelling() {
        guard !state.submitted else { return }
        let typed = state.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        withAnimation(stateAnimation) {
            state.spellingCorrect = typed.caseInsensitiveCompare(word.term) == .orderedSame
            state.submitted = true
            state.feedback = state.spellingCorrect ? "拼写正确" : "正确拼写是 \(word.term)，可以再写一次。"
            if !state.revealed {
                store.recordAnswer(word: word, mode: "study_spelling", response: typed, correct: state.spellingCorrect)
            } else {
                state.feedback += "（已查看答案，本次不计成绩）"
            }
            onInteract()
        }
    }

    private func handleArrow(_ direction: Int) -> KeyPress.Result {
        guard focusTarget != .input(word.id) else { return .ignored }
        onNavigate(direction)
        return .handled
    }
}


struct NativeVocabularyView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var week = 0
    @State private var day = 0
    @State private var wordID: String?
    @State private var compactWordID: String?
    @State private var showAllWords = false
    @State private var compactShowingDetail = false

    private var weekOptions: [Int] {
        Array(1...(showAllWords ? 50 : model.store.recommendedWeekCount))
    }

    private var filtered: [NativeWord] {
        model.store.words.filter { word in
            (showAllWords || word.track != .otherExam) &&
            (week == 0 || word.week == week) && (day == 0 || model.store.learningDay(for: word) == day) &&
            (search.isEmpty || word.term.localizedCaseInsensitiveContains(search) || model.store.meaning(for: word).localizedCaseInsensitiveContains(search))
        }
    }
    private var selectedWord: NativeWord? {
        if let wordID, let word = filtered.first(where: { $0.id == wordID }) { return word }
        return filtered.first
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < 780 {
                NavigationStack {
                    Group {
                        if compactShowingDetail, let word = selectedWord {
                            NativeWordDetail(word: word)
                                .environmentObject(model)
                                .toolbar {
                                    ToolbarItem(placement: .automatic) {
                                        Button {
                                            compactShowingDetail = false
                                        } label: {
                                            Label("词库", systemImage: "chevron.left")
                                        }
                                    }
                                }
                        } else {
                            wordBrowser(compact: true)
                        }
                    }
                    .navigationTitle(compactShowingDetail ? selectedWord?.term ?? "词库" : "词库 · \(filtered.count.formatted()) 词")
                }
            } else {
                HSplitView {
                    wordBrowser(compact: false)
                        .frame(minWidth: 250, idealWidth: 315, maxWidth: 420)
                    if let word = selectedWord {
                        NativeWordDetail(word: word)
                            .environmentObject(model)
                            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                            .id(word.id)
                            .transition(.opacity)
                    } else {
                        ContentUnavailableView(search.isEmpty ? "词库为空" : "没有匹配的词条", systemImage: "text.book.closed")
                            .frame(minWidth: 300, maxWidth: .infinity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedWord?.id)
                .navigationTitle("词库 · \(filtered.count.formatted()) 词")
            }
        }
        .onChange(of: showAllWords) { _, isShowingAll in
            if !isShowingAll && week > model.store.recommendedWeekCount { week = 0 }
        }
        .onChange(of: filtered.first?.id) { _, value in
            if let value, !filtered.contains(where: { $0.id == wordID }) { wordID = value }
        }
    }

    private func wordBrowser(compact: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("词库范围", selection: $showAllWords) {
                    Text("雅思学习路径").tag(false)
                    Text("全部 6000 词").tag(true)
                }.pickerStyle(.segmented).labelsHidden()
                if compact {
                    VStack(spacing: 6) {
                        weekFilter(menu: true)
                        dayFilter(menu: true)
                    }
                } else {
                    HStack(spacing: 6) {
                        weekFilter(menu: false)
                        dayFilter(menu: false)
                    }
                }
            }.padding(compact ? 12 : 10)
            Divider()
            List(selection: compact ? $compactWordID : $wordID) {
                ForEach(filtered) { word in
                    Button {
                        wordID = word.id
                        if compact { compactShowingDetail = true }
                    } label: {
                        wordListRow(word)
                    }
                    .buttonStyle(.plain)
                    .tag(word.id)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, placement: .toolbar, prompt: "搜索英文或释义")
            .onChange(of: compactWordID) { _, value in
                guard compact, let value else { return }
                wordID = value
                compactShowingDetail = true
            }
        }
    }

    @ViewBuilder private func weekFilter(menu: Bool) -> some View {
        let options = [NativeSelectionOption(value: 0, title: "全部周次")] + weekOptions.map {
            NativeSelectionOption(value: $0, title: "第 \($0) 周")
        }
        if menu {
            NativeSelectControl(title: "周次", selection: $week, options: options, minWidth: 145)
                .frame(maxWidth: .infinity)
        } else {
            NativeSelectControl(title: "周次", selection: $week, options: options, minWidth: 145)
        }
    }

    @ViewBuilder private func dayFilter(menu: Bool) -> some View {
        let options = [NativeSelectionOption(value: 0, title: "全部学习日")] + (1...6).map {
            NativeSelectionOption(value: $0, title: "第 \($0) 天")
        }
        if menu {
            NativeSelectControl(title: "学习日", selection: $day, options: options, minWidth: 145)
                .frame(maxWidth: .infinity)
        } else {
            NativeSelectControl(title: "学习日", selection: $day, options: options, minWidth: 145)
        }
    }

    private func wordListRow(_ word: NativeWord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(word.term).font(.system(size: 14, weight: .medium))
                Spacer(minLength: 4)
                if let level = model.store.progress[word.id]?.level, level > 0 {
                    Text("\(level)/5").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(model.store.meaning(for: word)).lineLimit(1)
                Spacer(minLength: 4)
                Text("W\(word.week) · D\(model.store.learningDay(for: word))")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Text(word.track.title).font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct NativeWordDetail: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let word: NativeWord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.term).font(.system(size: 34, weight: .medium, design: .rounded)).textSelection(.enabled)
                        Text("\(word.ipa)   ·   \(word.partOfSpeech)").font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                        Text(word.track.title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.teal)
                        Text(word.track.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        speechButton("GB", locale: "en-GB")
                        speechButton("US", locale: "en-US")
                    }
                }
                .padding(15)
                .background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.teal.opacity(0.16), lineWidth: 1))
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("释义").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(model.store.meaning(for: word)).font(.system(size: 17))
                }
                if !word.collocations.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("常见搭配").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        ForEach(word.collocations, id: \.self) { Text($0).font(.system(size: 13, design: .serif)) }
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("例句").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(word.exampleEn).font(.system(size: 15, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    Text(model.store.exampleTranslation(for: word)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if !model.store.family(for: word).isEmpty { detailLine("词族", text: model.store.family(for: word)) }
                if !model.store.note(for: word).isEmpty { detailLine("用法提示", text: model.store.note(for: word)) }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("熟练度").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text("\(model.store.progress[word.id]?.level ?? 0) / 5").font(.system(size: 15, design: .monospaced))
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.store.progress[word.id]?.level ?? 0)
                    }
                    Spacer()
                    Button(model.store.learningLocation(for: word) == nil ? "进入单词练习" : "背这个词") {
                        model.beginStudying(word)
                    }.buttonStyle(.bordered)
                    Button("练习这个词") { model.openRoute(week: word.week, day: word.day, word: word.id) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(25).frame(maxWidth: 650, alignment: .leading)
        }
    }

    private func speechButton(_ title: String, locale: String) -> some View {
        Button(title) { Task { @MainActor in try? VocabularySpeech.shared.speak(text: word.term, locale: locale) } }
            .buttonStyle(.bordered).controlSize(.small).help(locale == "en-GB" ? "英式发音" : "美式发音")
    }

    private func detailLine(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
