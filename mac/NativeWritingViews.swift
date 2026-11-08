import Charts
import SwiftUI

struct NativeWritingView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var task = "t1"
    @State private var draftID = UUID().uuidString
    @State private var response = ""
    @State private var notes = ""
    @State private var showTranslation = false
    @State private var startedAt: Date?
    @State private var timerElapsed = 0
    @State private var savedMessage = ""
    private var plan: NativeWritingWeek? { NativePracticeCatalog.writing.indices.contains(model.selectedWeek - 1) ? NativePracticeCatalog.writing[model.selectedWeek - 1] : nil }
    private var prompt: String { task == "t1" ? plan?.t1.title ?? "" : plan?.t2.title ?? "" }
    private var wordCount: Int { response.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "-" }.count }

    var body: some View {
        NativePage(eyebrow: "WRITING", title: "写作练习", subtitle: "十周主题与 Task 1 / Task 2 计划；草稿自动保存在本机。", accent: .orange) { layout in
            VStack(alignment: .leading, spacing: 17) {
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 9) {
                        weekPicker.frame(maxWidth: .infinity)
                        taskPicker(compact: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        weekPicker.frame(maxWidth: 290)
                        taskPicker(compact: false)
                    }
                }
                if let plan {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task == "t1" ? "TASK 1 · 至少 150 词" : "TASK 2 · 至少 250 词")
                                .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).tracking(0.7)
                            Text(prompt).font(.system(size: 16, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
                            if task == "t1" { writingVisual(plan.t1, compact: layout.isCompact) }
                            if showTranslation {
                                Text(task == "t1" ? plan.t1.zh : plan.t2.zh)
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            Button(showTranslation ? "隐藏中文题意" : "显示中文题意") {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { showTranslation.toggle() }
                            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    if layout.isCompact {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 10) {
                                wordCountLabel
                                Text(task == "t1" ? "建议约 20 分钟" : "建议约 40 分钟").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 10) {
                                timerControls
                                Spacer(minLength: 4)
                                saveButton
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            wordCountLabel
                            Text(task == "t1" ? "建议约 20 分钟" : "建议约 40 分钟").font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer(minLength: 5)
                            timerControls
                            saveButton
                        }
                    }
                    TextEditor(text: $response)
                        .font(.system(size: 14, design: .serif))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(nsColor: .separatorColor).opacity(0.55)))
                        .frame(minHeight: 270)
                        .onChange(of: response) { _, _ in autosave() }
                    if !savedMessage.isEmpty {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: savedMessage)
                    }
                    TextField("写完后记录一个待修改点", text: $notes).textFieldStyle(.roundedBorder)
                        .onChange(of: notes) { _, _ in autosave() }
                    if !plan.t1.hints.isEmpty {
                        DisclosureGroup("本题检查要点") {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(task == "t1" ? plan.t1.hints : plan.t2.hints, id: \.self) { Text("• \($0)").font(.system(size: 11)).foregroundStyle(.secondary) }
                            }.padding(.top, 6)
                        }.font(.system(size: 12))
                    }
                    Divider()
                    NativeSectionHeading(title: "已保存草稿", trailing: "\(model.store.writingDrafts.count) 篇")
                    ForEach(model.store.writingDrafts.prefix(8)) { draft in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第 \(draft.week) 周 · \(draft.task.uppercased())").font(.system(size: 11, weight: .medium))
                                Text(draft.prompt).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text("\(draft.response.split { $0.isWhitespace }.count) 词").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            Button("打开") { openDraft(draft) }.buttonStyle(.plain)
                        }.padding(.vertical, 3)
                    }
                } else { ContentUnavailableView("写作题目暂不可用", systemImage: "pencil.line") }
            }
        }
        .onChange(of: model.selectedWeek) { _, _ in resetDraft() }
        .onChange(of: task) { _, _ in resetDraft() }
        .onAppear { resetDraft() }
    }

    private var weekPicker: some View {
        NativeSelectControl(
            title: "周次",
            selection: $model.selectedWeek,
            options: Array(NativePracticeCatalog.writing.enumerated()).map { index, item in
                NativeSelectionOption(value: index + 1, title: "第 \(index + 1) 周 · \(item.theme)")
            },
            minWidth: 220
        )
    }

    @ViewBuilder private func taskPicker(compact: Bool) -> some View {
        if compact {
            Picker("任务", selection: $task) {
                Text("Task 1 · Academic").tag("t1"); Text("Task 2 · Essay").tag("t2")
            }.pickerStyle(.segmented).frame(maxWidth: 330)
        } else {
            Picker("任务", selection: $task) {
                Text("Task 1 · Academic").tag("t1"); Text("Task 2 · Essay").tag("t2")
            }.pickerStyle(.segmented).frame(width: 290)
        }
    }

    private var wordCountLabel: some View {
        Text("\(wordCount) 词").font(.system(size: 12, weight: .medium, design: .monospaced))
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: wordCount)
    }

    @ViewBuilder private var timerControls: some View {
        if let startedAt {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(elapsed(start: startedAt, at: timeline.date)).font(.system(size: 12, design: .monospaced)).monospacedDigit()
                    .contentTransition(.numericText())
            }
            Button("暂停计时") { timerElapsed += Int(Date.now.timeIntervalSince(startedAt)); self.startedAt = nil }.buttonStyle(.bordered)
        } else {
            if timerElapsed > 0 { Text(timeLabel(timerElapsed)).font(.system(size: 12, design: .monospaced)).monospacedDigit() }
            Button(timerElapsed > 0 ? "继续计时" : "开始计时") { startedAt = .now }.buttonStyle(.bordered)
        }
    }

    private var saveButton: some View {
        Button("保存草稿") { saveDraft() }.buttonStyle(.borderedProminent)
    }

    @ViewBuilder private func writingVisual(_ item: NativeWritingWeek.TaskOne, compact: Bool) -> some View {
        if let categories = item.categories, let series = item.series, !categories.isEmpty {
            Chart {
                ForEach(series, id: \.name) { row in
                    ForEach(Array(row.values.enumerated()), id: \.offset) { index, value in
                        BarMark(x: .value("类别", categories[index]), y: .value(row.name, value))
                            .position(by: .value("年份", row.name))
                            .foregroundStyle(by: .value("年份", row.name))
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .chartForegroundStyleScale(
                domain: series.map(\.name),
                range: Array([Color.indigo.opacity(0.76), .teal.opacity(0.76), .orange.opacity(0.70)].prefix(series.count))
            )
            .frame(height: 180)
            .padding(.vertical, 6)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: model.selectedWeek)
        } else if let headers = item.headers, let rows = item.rows {
            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 7) {
                GridRow { ForEach(headers, id: \.self) { Text($0).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary) } }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in Text(cell.value).font(.system(size: 11, design: .monospaced)) } }
                }
            }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        } else if let steps = item.steps, compact {
            VStack(spacing: 7) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    Text(step).font(.system(size: 11)).frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .padding(.horizontal, 9)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        } else if let steps = item.steps {
            HStack(spacing: 7) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 7) {
                        Text(step).font(.system(size: 10)).frame(maxWidth: .infinity, minHeight: 42)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                        if index < steps.count - 1 { Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary) }
                    }
                }
            }
        } else {
            Text(item.type.uppercased() + " · 示意题图将在后续原生模块补全")
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func resetDraft() {
        guard let draft = model.store.writingDrafts.first(where: { $0.week == model.selectedWeek && $0.task == task }) else {
            draftID = UUID().uuidString; response = ""; notes = ""; timerElapsed = 0; startedAt = nil; return
        }
        openDraft(draft)
    }

    private func openDraft(_ draft: NativeWritingDraft) {
        model.selectedWeek = draft.week
        task = draft.task
        draftID = draft.id
        response = draft.response
        notes = draft.notes
        timerElapsed = 0
        startedAt = nil
        savedMessage = "已打开本机草稿"
    }

    private func autosave() {
        guard !response.isEmpty else { return }
        let draft = NativeWritingDraft(id: draftID, week: model.selectedWeek, task: task, prompt: prompt,
                                       response: response, notes: notes, updatedAt: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard self.draftID == draft.id else { return }
            self.model.store.saveWritingDraft(draft)
            self.savedMessage = "已自动保存 · \(Date.now.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func saveDraft() {
        guard let plan else { return }
        model.store.saveWritingDraft(NativeWritingDraft(id: draftID, week: model.selectedWeek, task: task, prompt: prompt, response: response, notes: notes, updatedAt: .now))
        savedMessage = "草稿已保存 · \(Date.now.formatted(date: .omitted, time: .shortened))"
        if let startedAt { timerElapsed += Int(Date.now.timeIntervalSince(startedAt)); self.startedAt = nil }
        _ = plan
    }

    private func elapsed(start: Date, at date: Date) -> String { timeLabel(timerElapsed + Int(date.timeIntervalSince(start))) }
    private func timeLabel(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}
