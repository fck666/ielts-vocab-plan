import SwiftUI
import UniformTypeIdentifiers

private struct NativeSQLiteDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.database] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct NativeSettingsView: View {
    @EnvironmentObject private var model: NativeAppModel
    @State private var selectedLocale = "zh-CN"
    @State private var pendingLocale: String?
    @State private var exportDocument: NativeSQLiteDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showRestoreConfirmation = false
    @State private var restoreData: Data?
    @State private var status = ""
    private let languages: [(String, String, String, Bool)] = [
        ("zh-CN", "简体中文", "已校对", true), ("ja", "日本語", "词条译文初稿", false),
        ("ko", "한국어", "词条译文初稿", false), ("fr", "Français", "词条译文初稿", false),
        ("es", "Español", "词条译文初稿", false), ("ar", "العربية", "词条译文初稿", false)
    ]

    var body: some View {
        NativePage(eyebrow: "PREFERENCES", title: "设置与数据", subtitle: "学习数据仅保存在这台 Mac；导出备份后可恢复。") { layout in
            VStack(alignment: .leading, spacing: 20) {
                NativeSectionHeading(title: "学习偏好")
                NativeResponsiveStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每日目标").font(.system(size: 13, weight: .medium))
                        Text("新词完成后可继续到期复习").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Text("20 词").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                }
                Divider()
                NativeResponsiveStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发音口音").font(.system(size: 13, weight: .medium))
                        Text("使用 macOS 原生语音").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    NativeSelectControl(
                        title: "口音",
                        selection: Binding(get: { UserDefaults.standard.string(forKey: "native.speech.accent") ?? "en-GB" }, set: { UserDefaults.standard.set($0, forKey: "native.speech.accent") }),
                        options: [
                            NativeSelectionOption(value: "en-GB", title: "英式 English UK"),
                            NativeSelectionOption(value: "en-US", title: "美式 English US")
                        ],
                        minWidth: 185
                    )
                }
                Divider()
                NativeSectionHeading(title: "学习语言", trailing: "切换语言会清空当前学习进度")
                VStack(spacing: 0) {
                    ForEach(languages, id: \.0) { locale, name, state, ready in
                        let stateColor: Color = ready ? Color.secondary : Color.orange
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.system(size: 13, weight: .medium))
                                Text(state).font(.system(size: 10)).foregroundStyle(stateColor)
                            }
                            Spacer()
                            if model.store.locale == locale {
                                Label("使用中", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(.green)
                            } else {
                                Button("切换") { pendingLocale = locale }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                        }.padding(.vertical, 9)
                        if locale != languages.last?.0 { Divider() }
                    }
                }
                Divider()
                NativeSectionHeading(title: "本地数据", trailing: "SQLite · 无需数据库服务")
                NativeResponsiveStack(spacing: 10) {
                    Button { exportDatabase() } label: { Label("导出 SQLite 备份", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent).disabled(model.store.storageError != nil)
                    Button { showImporter = true } label: { Label("恢复备份…", systemImage: "arrow.down.doc") }
                        .buttonStyle(.bordered)
                }
                Text("备份包含词条进度、练习记录和写作草稿。口语录音文件位于 Application Support/IELTS Vocabulary Lab/Recordings。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !status.isEmpty { Text(status).font(.system(size: 11)).foregroundStyle(.secondary) }
                Divider()
                NativeSectionHeading(title: "桌面词卡")
                HStack {
                    Text("系统小组件由 macOS 管理刷新节奏；菜单栏仍可打开独立桌面词卡。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text("每周抽词 · 轮内去重").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear { selectedLocale = model.store.locale }
        .confirmationDialog("切换学习语言？", isPresented: Binding(get: { pendingLocale != nil }, set: { if !$0 { pendingLocale = nil } }), titleVisibility: .visible) {
            Button("先导出备份", role: .none) { exportDatabase() }
            Button("切换并重置学习数据", role: .destructive) {
                if let pendingLocale { model.store.changeLocaleAndResetProgress(pendingLocale); selectedLocale = pendingLocale }
                pendingLocale = nil
            }
            Button("取消", role: .cancel) { pendingLocale = nil }
        } message: {
            let name = languages.first(where: { $0.0 == pendingLocale })?.1 ?? "所选语言"
            Text("释义、例句译文和用法提示将改为\(name)。进度、错题、口语记录和写作草稿会清空；请先导出 SQLite 备份。")
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .database,
                      defaultFilename: "IELTS-learning-backup.sqlite") { result in
            switch result {
            case .success: status = "SQLite 备份已导出。"
            case .failure(let error): status = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.database], allowsMultipleSelection: false) { result in
            do {
                let url = try result.get().first
                guard let url else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                restoreData = try Data(contentsOf: url)
                showRestoreConfirmation = true
            } catch { status = "無法讀取备份：\(error.localizedDescription)" }
        }
        .confirmationDialog("恢复本机档案？", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button("恢复 SQLite 备份", role: .destructive) {
                if let restoreData { status = model.store.restoreDatabase(from: restoreData) ? "恢复完成，当前页面已载入备份数据。" : "恢复失败，当前学习记录保持不变。" }
                restoreData = nil
            }
            Button("取消", role: .cancel) { restoreData = nil }
        } message: {
            Text("恢复会替换当前词条进度、练习记录与写作草稿。开始前会在本机保留一份可手动恢复的数据库副本。")
        }
    }

    private func exportDatabase() {
        guard model.store.flush(), let data = model.store.exportDatabaseData() else {
            status = "导出失败：数据库尚未保存。"
            return
        }
        exportDocument = NativeSQLiteDocument(data: data)
        showExporter = true
    }
}
