import AVFoundation
import AVKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

import AVFoundation
import AVKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct NativeSpeakingWeek: Decodable {
    struct LongTurn: Decodable { let title: String; let zh: String; let cues: [String]; let explain: String }
    let theme: String
    let focus: String
    let hints: [String]
    let p1: [[String]]
    let p2: LongTurn
    let p3: [[String]]
}

struct NativeWritingWeek: Decodable {
    struct Series: Decodable { let name: String; let values: [Double] }
    struct Cell: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) { value = text }
            else if let number = try? container.decode(Double.self) {
                value = number.rounded() == number ? String(Int(number)) : String(number)
            } else { value = "" }
        }
    }
    struct TaskOne: Decodable {
        let type: String; let title: String; let zh: String; let unit: String?
        let categories: [String]?; let series: [Series]?; let headers: [String]?; let rows: [[Cell]]?; let steps: [String]?; let hints: [String]
    }
    struct TaskTwo: Decodable { let title: String; let zh: String; let hints: [String] }
    let theme: String
    let t1: TaskOne
    let t2: TaskTwo
}

enum NativePracticeCatalog {
    static let speaking: [NativeSpeakingWeek] = load("native-speaking-plan")
    static let writing: [NativeWritingWeek] = load("native-writing-plan")

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
}

struct NativeSpeakingView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var part = 1
    @State private var activePrompt: String?
    @State private var recording: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var recordingURL: URL?
    @State private var recordingStart: Date?
    @State private var recordingFinished = false
    @State private var hoveredPromptID: String?
    @State private var rating = 3
    @State private var notes = ""
    @State private var errorMessage: String?
    private var week: NativeSpeakingWeek? { NativePracticeCatalog.speaking.first { $0.theme == themeForSelectedWeek } }
    private var themeForSelectedWeek: String { NativePracticeCatalog.speaking.indices.contains(model.selectedWeek - 1) ? NativePracticeCatalog.speaking[model.selectedWeek - 1].theme : "" }

    var body: some View {
        NativePage(eyebrow: "SPEAKING", title: "口语练习", subtitle: "用一个真实细节展开回答；录音保存在本机。", accent: .indigo) { layout in
            VStack(alignment: .leading, spacing: 20) {
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 9) {
                        weekPicker.frame(maxWidth: .infinity)
                        partPicker(compact: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        weekPicker.frame(maxWidth: 280)
                        partPicker(compact: false)
                    }
                }
                if let week {
                    if layout.isCompact {
                        VStack(alignment: .leading, spacing: 7) {
                            focusDescription(week)
                            practiceTiming
                        }
                    } else {
                        HStack(alignment: .top, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("本周表达重点").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Text(week.focus).font(.system(size: 15, weight: .medium))
                        }
                        Spacer()
                            practiceTiming
                        }
                    }
                    Divider()
                    if part == 2 {
                            speakingQuestion(week.p2.title, translation: week.p2.zh, id: week.p2.title, cueText: week.p2.cues + [week.p2.explain], compact: layout.isCompact)
                    } else {
                        let questions = part == 1 ? week.p1 : week.p3
                        ForEach(Array(questions.enumerated()), id: \.offset) { _, item in
                            speakingQuestion(item[0], translation: item.count > 1 ? item[1] : "", id: item[0], cueText: [], compact: layout.isCompact)
                            Divider()
                        }
                    }
                    if let activePrompt {
                        recordingPanel(prompt: activePrompt, compact: layout.isCompact)
                    }
                    if !model.store.expressionRecords.filter({ $0.kind == "speaking" }).isEmpty {
                        Divider()
                        NativeSectionHeading(title: "最近练习", trailing: "\(model.store.expressionRecords.filter { $0.kind == "speaking" }.count) 条本地记录")
                        ForEach(model.store.expressionRecords.filter { $0.kind == "speaking" }.prefix(4)) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.prompt).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if FileManager.default.fileExists(atPath: item.response) {
                                    Button { play(item.response) } label: { Image(systemName: "play.fill") }.buttonStyle(.bordered).controlSize(.small).help("播放本机录音")
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                } else {
                    ContentUnavailableView("口语题目暂不可用", systemImage: "waveform")
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: part)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.selectedWeek)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activePrompt)
        .alert("录音无法启动", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var weekPicker: some View {
        NativeSelectControl(
            title: "周次",
            selection: $model.selectedWeek,
            options: Array(NativePracticeCatalog.speaking.enumerated()).map { index, item in
                NativeSelectionOption(value: index + 1, title: "第 \(index + 1) 周 · \(item.theme)")
            },
            minWidth: 220
        )
    }

    @ViewBuilder private func partPicker(compact: Bool) -> some View {
        if compact {
            NativeSelectControl(
                title: "Part",
                selection: $part,
                options: (1...3).map { NativeSelectionOption(value: $0, title: "Part \($0)") },
                minWidth: 150
            )
        } else {
            Picker("Part", selection: $part) {
                Text("Part 1").tag(1); Text("Part 2").tag(2); Text("Part 3").tag(3)
            }.pickerStyle(.segmented).frame(width: 245)
        }
    }

    private func focusDescription(_ week: NativeSpeakingWeek) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("本周表达重点").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(week.focus).font(.system(size: 15, weight: .medium))
        }
    }

    private var practiceTiming: some View {
        Text("Part \(part == 2 ? "2 · 准备 1 分钟，陈述 1–2 分钟" : "\(part) · 练习建议 \(part == 1 ? 45 : 90) 秒")")
            .font(.system(size: 11)).foregroundStyle(.secondary)
    }

    @ViewBuilder private func speakingQuestion(_ title: String, translation: String, id: String, cueText: [String], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if compact {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 12) {
                        promptNumber(for: title)
                        promptText(title, translation: translation, cueText: cueText)
                    }
                    Button { begin(prompt: title) } label: { Label("练习", systemImage: "mic") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    promptNumber(for: title)
                    promptText(title, translation: translation, cueText: cueText)
                    Spacer(minLength: 5)
                    Button { begin(prompt: title) } label: { Label("练习", systemImage: "mic") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(hoveredPromptID == id ? Color.accentColor.opacity(0.035) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hoveredPromptID == id ? Color.accentColor.opacity(0.12) : .clear, lineWidth: 1))
        .onHover { hoveredPromptID = $0 ? id : (hoveredPromptID == id ? nil : hoveredPromptID) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hoveredPromptID == id)
    }

    private func promptNumber(for title: String) -> some View {
        Text(String(format: "%02d", (NativePracticeCatalog.speaking[model.selectedWeek - 1].p1.firstIndex { $0.first == title } ?? 0) + 1))
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).padding(.top, 3)
    }

    private func promptText(_ title: String, translation: String, cueText: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
            if !translation.isEmpty { Text(translation).font(.system(size: 11)).foregroundStyle(.secondary) }
            if !cueText.isEmpty {
                Text(cueText.map { "• \($0)" }.joined(separator: "    "))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func recordingPanel(prompt: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Divider()
            Text(prompt).font(.system(size: 15, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    recordingControls
                    recordingSettings
                }
            } else {
                HStack(spacing: 11) {
                    recordingControls
                    Spacer(minLength: 6)
                    recordingSettings
                }
            }
            TextField("这次最想改进的一点", text: $notes)
                .textFieldStyle(.roundedBorder).frame(maxWidth: 470)
            if recordingStart == nil {
                Text("录音文件与自评只保存在这台 Mac。离开页面前请停止录音。")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(15)
        .background(recordingStart != nil ? Color.red.opacity(0.045) : Color.accentColor.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .stroke(recordingStart != nil ? Color.red.opacity(0.17) : Color.primary.opacity(0.08), lineWidth: 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: recordingStart != nil)
        .padding(.top, 6)
    }

    @ViewBuilder private var recordingControls: some View {
        if recordingStart != nil {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let time = elapsed(at: timeline.date)
                Text(time).font(.system(size: 14, design: .monospaced)).monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: time)
            }
            Circle().fill(.red).frame(width: 7, height: 7)
            Text("正在录音").font(.system(size: 11)).foregroundStyle(.secondary)
            Button("停止并保存") { stopRecording() }.buttonStyle(.borderedProminent)
        } else {
            if recordingFinished, let url = recordingURL {
                Button { play(url.path) } label: { Label("回听", systemImage: "play.fill") }.buttonStyle(.bordered)
                Text("录音已保存到本机").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Button(recordingFinished ? "重新录音" : "开始录音") { startRecording() }
                .buttonStyle(.borderedProminent)
            Button("关闭") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    activePrompt = nil
                    notes = ""
                }
            }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }

    private var recordingSettings: some View {
        HStack(spacing: 10) {
            NativeSelectControl(
                title: "自评",
                selection: $rating,
                options: (1...5).map { NativeSelectionOption(value: $0, title: "\($0) / 5") },
                minWidth: 126
            )
        }
    }

    private func begin(prompt: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            activePrompt = prompt
            recordingFinished = false
            recordingURL = nil
            rating = 3
            notes = ""
        }
    }

    private func startRecording() {
        let authorization = AVCaptureDevice.authorizationStatus(for: .audio)
        if authorization == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { granted ? self.configureRecorder() : (self.errorMessage = "請在系統提示中允許麥克風存取。") }
            }
        } else if authorization == .authorized {
            configureRecorder()
        } else {
            errorMessage = "請在「系統設定 > 隱私權與安全性 > 麥克風」允許 IELTS Vocabulary Lab。"
        }
    }

    private func configureRecorder() {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let folder = support.appendingPathComponent("IELTS Vocabulary Lab/Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("speaking-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
            let next = try AVAudioRecorder(url: url, settings: settings)
            next.prepareToRecord()
            guard next.record() else { throw NSError(domain: "NativeSpeaking", code: 1, userInfo: [NSLocalizedDescriptionKey: "系統沒有開始錄音。"]) }
            recording = next
            recordingURL = url
            recordingStart = .now
        } catch { errorMessage = error.localizedDescription }
    }

    private func stopRecording() {
        guard let start = recordingStart else { return }
        recording?.stop()
        let duration = Int(Date.now.timeIntervalSince(start))
        recordingStart = nil
        recordingFinished = true
        if let recordingURL {
            model.store.recordExpression(kind: "speaking", prompt: activePrompt ?? "口语练习",
                response: recordingURL.path, rating: rating, duration: duration, notes: notes)
        }
    }

    private func play(_ path: String) {
        do { player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)); player?.prepareToPlay(); player?.play() }
        catch { errorMessage = error.localizedDescription }
    }

    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(recordingStart ?? date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
