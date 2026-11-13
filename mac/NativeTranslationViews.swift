import AppKit
import SwiftUI
import Translation

struct NativeTranslationView: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            NativeOfflineTranslationView()
        } else {
            NativePage(eyebrow: "TRANSLATE", title: "翻译工具",
                       subtitle: "英语与简体中文互译；翻译内容不会写入学习记录。", accent: .blue) { _ in
                Label("离线翻译需要 macOS 15 或更新版本。", systemImage: "macos")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}

@available(macOS 15.0, *)
private struct NativeOfflineTranslationView: View {
    @EnvironmentObject private var model: NativeAppModel
    private enum TranslationMode: String, Identifiable {
        case onDevice
        case deepL

        var id: String { rawValue }
    }

    private enum Direction: String, Identifiable {
        case englishToChinese
        case chineseToEnglish

        var id: String { rawValue }
        var sourceTitle: String { self == .englishToChinese ? "英语" : "简体中文" }
        var targetTitle: String { self == .englishToChinese ? "简体中文" : "英语" }
        var sourceLanguage: Locale.Language {
            Locale.Language(identifier: self == .englishToChinese ? "en" : "zh-Hans")
        }
        var targetLanguage: Locale.Language {
            Locale.Language(identifier: self == .englishToChinese ? "zh-Hans" : "en")
        }
        var reversed: Direction { self == .englishToChinese ? .chineseToEnglish : .englishToChinese }
    }

    private struct Request: Sendable {
        let id: UUID
        let text: String
    }

    @State private var direction: Direction = .englishToChinese
    @AppStorage("translation.mode") private var modeRaw = "onDevice"
    private var mode: TranslationMode { TranslationMode(rawValue: modeRaw) ?? .onDevice }
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var availability: LanguageAvailability.Status?
    @State private var configuration: TranslationSession.Configuration?
    @State private var nativeSession: TranslationSession?
    @State private var hasAPIKey = false
    @State private var pendingRequest: Request?
    @State private var onlineRequestTask: Task<Void, Never>?
    @State private var autoTranslationTask: Task<Void, Never>?
    @State private var isSessionReady = false
    @State private var isPreparingSession = true
    @State private var isTranslating = false
    @State private var message = ""

    private var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (mode == .deepL ? hasAPIKey : availability != .unsupported && isSessionReady)
            && !isTranslating
    }

    private var availabilityMessage: String {
        switch availability {
        case .installed:
            "离线语言资源已安装。输入内容由 macOS 在本机处理。"
        case .supported:
            "此语言组合可用；首次翻译时 macOS 可能需要下载离线语言资源。"
        case .unsupported:
            "此 Mac 当前不支持英语与简体中文互译。"
        case nil:
            "正在检查 macOS 的语言资源…"
        @unknown default:
            "正在检查 macOS 的语言资源…"
        }
    }

    private var statusMessage: String {
        if isTranslating { return "正在翻译…" }
        if mode == .deepL { return message.isEmpty ? (hasAPIKey ? "DeepL 在线翻译已就绪。" : "请在设置与数据中添加 DeepL API Key。") : message }
        if isPreparingSession { return "正在准备离线翻译…" }
        return message.isEmpty ? availabilityMessage : message
    }

    var body: some View {
        NativePage(eyebrow: "TRANSLATE", title: "翻译工具",
                   subtitle: "英语与简体中文互译；翻译内容不会写入学习记录。", accent: .blue) { pageLayout in
            VStack(alignment: .leading, spacing: pageLayout.isShort ? 14 : 18) {
                directionPicker

                NativeResponsiveStack(spacing: 14) {
                    sourcePanel(compact: pageLayout.isCompact)
                    resultPanel(compact: pageLayout.isCompact)
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusMessage)
                            .font(.system(size: 11)).foregroundStyle(message.contains("失败") ? Color.red : Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if mode == .deepL && !hasAPIKey {
                            Button("前往设置") { model.section = .settings }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                        }
                    }
                    Spacer(minLength: 4)
                    Button(action: translate) {
                        Label("翻译", systemImage: "translate")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canTranslate)
                    .keyboardShortcut(.return, modifiers: .command)
                }

                if mode == .onDevice {
                    Label("本机翻译不发送原文。首次使用可能需要联网下载系统语言资源。",
                          systemImage: "lock.shield")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Label("在线翻译会将原文发送给 DeepL。", systemImage: "network")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear(perform: refreshAPIKeyStatus)
        .onDisappear {
            autoTranslationTask?.cancel()
            autoTranslationTask = nil
            cancelPendingTranslation()
        }
        .onChange(of: modeRaw) { _, _ in
            autoTranslationTask?.cancel()
            cancelPendingTranslation()
            message = ""
        }
        .task(id: "\(direction.id)-\(mode.id)") {
            isSessionReady = false
            nativeSession = nil
            configuration = nil
            isPreparingSession = mode == .onDevice
            guard mode == .onDevice else { return }
            availability = await LanguageAvailability().status(
                from: direction.sourceLanguage,
                to: direction.targetLanguage
            )
            guard !Task.isCancelled else { return }
            guard availability != .unsupported else {
                isPreparingSession = false
                return
            }
            if #available(macOS 26.0, *) {
                let session: TranslationSession
                if #available(macOS 26.4, *) {
                    session = TranslationSession(
                        installedSource: direction.sourceLanguage,
                        target: direction.targetLanguage,
                        preferredStrategy: .lowLatency
                    )
                } else {
                    session = TranslationSession(
                        installedSource: direction.sourceLanguage,
                        target: direction.targetLanguage
                    )
                }
                nativeSession = session
                do {
                    try await session.prepareTranslation()
                    guard !Task.isCancelled else { return }
                    isSessionReady = true
                    isPreparingSession = false
                } catch {
                    guard !Task.isCancelled else { return }
                    isSessionReady = false
                    isPreparingSession = false
                    message = "翻译准备失败：\(error.localizedDescription)"
                }
                return
            }
            var nextConfiguration = TranslationSession.Configuration(
                source: direction.sourceLanguage,
                target: direction.targetLanguage
            )
            if #available(macOS 26.4, *) {
                nextConfiguration.preferredStrategy = .lowLatency
            }
            nextConfiguration.invalidate()
            configuration = nextConfiguration
        }
        .translationTask(configuration) { session in
            if #available(macOS 26.0, *) { return }
            let sessionDirection = direction
            guard let request = pendingRequest else {
                do {
                    try await session.prepareTranslation()
                    guard mode == .onDevice, direction == sessionDirection else { return }
                    isSessionReady = true
                    isPreparingSession = false
                } catch {
                    guard mode == .onDevice, direction == sessionDirection else { return }
                    isSessionReady = false
                    isPreparingSession = false
                    message = "翻译准备失败：\(error.localizedDescription)"
                }
                return
            }
            isPreparingSession = false
            do {
                let response = try await session.translate(request.text)
                guard pendingRequest?.id == request.id else { return }
                translatedText = response.targetText
                availability = .installed
                message = "翻译完成"
            } catch {
                guard pendingRequest?.id == request.id else { return }
                message = "翻译失败：\(error.localizedDescription)"
            }
            pendingRequest = nil
            isTranslating = false
        }
    }

    private var directionPicker: some View {
        HStack(spacing: 10) {
            languageLabel(direction.sourceTitle, symbol: "text.alignleft")
            Spacer(minLength: 0)
            Button(action: swapDirection) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 30)
            }
            .buttonStyle(.bordered)
            .help("交换翻译方向")
            .accessibilityLabel("交换翻译方向")
            Spacer(minLength: 0)
            languageLabel(direction.targetTitle, symbol: "text.alignright")
        }
    }

    private func languageLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func sourcePanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(direction.sourceTitle)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(sourceText.count)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                if !sourceText.isEmpty {
                    Button(action: clear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13)).foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("清空原文")
                    .accessibilityLabel("清空原文")
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: sourceBinding)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: compact ? 140 : 230)
                if sourceText.isEmpty {
                    Text("输入要翻译的内容…")
                        .font(.system(size: 14, weight: .regular, design: .default)).foregroundStyle(.tertiary)
                        .padding(.leading, 5).padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor).opacity(0.45)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(direction.targetTitle)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if !translatedText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translatedText, forType: .string)
                        message = "已复制翻译结果"
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("复制翻译结果")
                }
            }
            Group {
                if translatedText.isEmpty {
                    Text("翻译结果会显示在这里")
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        Text(translatedText)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .font(.system(size: 14, weight: .regular, design: .default))
            .frame(maxWidth: .infinity, minHeight: compact ? 140 : 230, alignment: .topLeading)
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor).opacity(0.45)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceBinding: Binding<String> {
        Binding(get: { sourceText }, set: updateSource)
    }

    private func updateSource(_ text: String) {
        sourceText = text
        translatedText = ""
        message = ""
        autoTranslationTask?.cancel()
        autoTranslationTask = nil
        cancelPendingTranslation()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Wait until the user pauses typing so each keystroke does not start a request.
        autoTranslationTask = Task {
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedText else { return }
            translate()
        }
    }

    private func translate() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        translatedText = ""
        message = ""
        isTranslating = true
        let request = Request(id: UUID(), text: text)
        pendingRequest = request
        if mode == .deepL {
            do {
                guard let apiKey = try DeepLKeychain.read(), !apiKey.isEmpty else {
                    isTranslating = false
                    pendingRequest = nil
                    hasAPIKey = false
                    message = "请在设置与数据中保存 DeepL API Key。"
                    return
                }
                let source = direction == .englishToChinese ? "EN" : "ZH"
                let target = direction == .englishToChinese ? "ZH" : "EN"
                onlineRequestTask = Task {
                    await performDeepLTranslation(request, apiKey: apiKey, source: source, target: target)
                }
            } catch {
                isTranslating = false
                pendingRequest = nil
                message = error.localizedDescription
            }
            return
        }
        guard availability != .unsupported, isSessionReady else {
            isTranslating = false
            pendingRequest = nil
            return
        }
        if #available(macOS 26.0, *) {
            guard let nativeSession, isSessionReady else {
                isTranslating = false
                pendingRequest = nil
                message = "翻译会话尚未准备好，请稍后重试。"
                return
            }
            Task {
                await performTranslation(request, with: nativeSession)
            }
        } else {
            var nextConfiguration = configuration ?? TranslationSession.Configuration(
                source: direction.sourceLanguage,
                target: direction.targetLanguage
            )
            nextConfiguration.invalidate()
            configuration = nextConfiguration
        }
    }

    private func swapDirection() {
        cancelPendingTranslation()
        let previousInput = sourceText
        sourceText = translatedText
        translatedText = previousInput
        message = ""
        direction = direction.reversed
    }

    private func clear() {
        sourceText = ""
        translatedText = ""
        message = ""
        cancelPendingTranslation()
    }

    private func cancelPendingTranslation() {
        let wasTranslating = isTranslating
        onlineRequestTask?.cancel()
        onlineRequestTask = nil
        pendingRequest = nil
        isTranslating = false
        guard wasTranslating else { return }
        if #available(macOS 26.0, *), let nativeSession {
            nativeSession.cancel()
            isSessionReady = false
            isPreparingSession = true
            let sessionDirection = direction
            Task {
                do {
                    try await nativeSession.prepareTranslation()
                    guard mode == .onDevice, direction == sessionDirection else { return }
                    isSessionReady = true
                    isPreparingSession = false
                } catch {
                    guard mode == .onDevice, direction == sessionDirection else { return }
                    isSessionReady = false
                    isPreparingSession = false
                    message = "翻译准备失败：\(error.localizedDescription)"
                }
            }
            return
        }
        isSessionReady = false
        isPreparingSession = true
        guard var configuration else { return }
        configuration.invalidate()
        self.configuration = configuration
    }

    private func performTranslation(_ request: Request, with session: TranslationSession) async {
        do {
            let response = try await session.translate(request.text)
            guard pendingRequest?.id == request.id else { return }
            translatedText = response.targetText
            availability = .installed
            message = "翻译完成"
        } catch {
            guard pendingRequest?.id == request.id else { return }
            message = "翻译失败：\(error.localizedDescription)"
        }
        pendingRequest = nil
        isTranslating = false
    }

    private func performDeepLTranslation(_ request: Request, apiKey: String, source: String, target: String) async {
        do {
            let result = try await DeepLTranslationService().translate(
                request.text,
                from: source,
                to: target,
                apiKey: apiKey
            )
            guard pendingRequest?.id == request.id else { return }
            translatedText = result
            message = "DeepL 翻译完成"
        } catch {
            guard pendingRequest?.id == request.id else { return }
            message = error.localizedDescription
        }
        pendingRequest = nil
        isTranslating = false
        onlineRequestTask = nil
    }

    private func refreshAPIKeyStatus() {
        do {
            hasAPIKey = try DeepLKeychain.read()?.isEmpty == false
        } catch {
            hasAPIKey = false
            message = error.localizedDescription
        }
    }

}
