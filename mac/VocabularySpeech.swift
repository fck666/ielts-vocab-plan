import AVFoundation
import Foundation

enum VocabularySpeechError: LocalizedError {
    case emptyText
    case missingVoice(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "没有可朗读的单词。"
        case .missingVoice(let locale):
            let accent = locale == "en-GB" ? "英语（英国）" : "英语（美国）"
            return "未安装\(accent)声音，请在系统设置的朗读声音中下载。"
        }
    }
}

@MainActor
final class VocabularySpeech {
    static let shared = VocabularySpeech()
    private let synthesizer = AVSpeechSynthesizer()
    private var observer: SpeechObserver!
    private var pendingStart: ((Result<[String: Any], Error>) -> Void)?
    private var activeUtterance: AVSpeechUtterance?
    private var requestID: String?
    private var requestedAt = Date.now
    private var activeAccent = "uk"
    private var didWarmUp = false
    private static var cachedVoices: [String: AVSpeechSynthesisVoice] = [:]

    private init() {
        observer = SpeechObserver { [weak self] utterance, started in
            Task { @MainActor in self?.speechEvent(utterance: utterance, started: started) }
        }
        synthesizer.delegate = observer
    }

    static func utterance(text: String, locale: String) throws -> AVSpeechUtterance {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw VocabularySpeechError.emptyText }
        let voice = try voice(for: locale)
        let utterance = AVSpeechUtterance(string: term)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        return utterance
    }

    private static func voice(for locale: String) throws -> AVSpeechSynthesisVoice {
        if let cached = cachedVoices[locale] { return cached }
        let preferredNames = locale == "en-GB" ? ["Daniel", "Serena", "Oliver"] : ["Samantha", "Alex"]
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.replacingOccurrences(of: "_", with: "-").lowercased() == locale.lowercased()
        }
        let voice = voices.sorted { left, right in
            let leftPreferred = preferredNames.contains { left.name.localizedCaseInsensitiveContains($0) }
            let rightPreferred = preferredNames.contains { right.name.localizedCaseInsensitiveContains($0) }
            if leftPreferred != rightPreferred { return leftPreferred }
            if left.quality != right.quality { return left.quality.rawValue > right.quality.rawValue }
            return left.identifier < right.identifier
        }.first
        guard let voice else { throw VocabularySpeechError.missingVoice(locale) }
        cachedVoices[locale] = voice
        return voice
    }

    func warmUp() {
        guard !didWarmUp else { return }
        didWarmUp = true
        for locale in ["en-GB", "en-US"] {
            guard let utterance = try? Self.utterance(text: "ready", locale: locale) else { continue }
            utterance.volume = 0
            synthesizer.speak(utterance)
        }
    }

    func speak(text: String, locale: String, requestID: String = UUID().uuidString,
               onStart: ((Result<[String: Any], Error>) -> Void)? = nil) throws {
        let utterance = try Self.utterance(text: text, locale: locale)
        // Keep one synthesizer alive in the app; a new request replaces speech already playing.
        pendingStart?(.failure(CancellationError()))
        pendingStart = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activeUtterance = utterance
        self.requestID = requestID
        activeAccent = locale == "en-GB" ? "uk" : "us"
        requestedAt = .now
        pendingStart = onStart
        synthesizer.speak(utterance)
    }

    func stop() {
        pendingStart?(.failure(CancellationError()))
        pendingStart = nil
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
        requestID = nil
    }

    var status: [String: Any] {
        ["backend": "macos-native", "available": true,
         "speaking": activeUtterance != nil, "requestID": requestID ?? "",
         "voices": ["uk": (try? Self.utterance(text: "test", locale: "en-GB")) != nil,
                    "us": (try? Self.utterance(text: "test", locale: "en-US")) != nil]]
    }

    private func speechEvent(utterance: AVSpeechUtterance, started: Bool) {
        guard activeUtterance === utterance else { return }
        if started {
            let reply: [String: Any] = ["ok": true, "backend": "macos-native",
                "requestID": requestID ?? "", "accent": activeAccent,
                "voice": utterance.voice?.name ?? "",
                "startLatencyMs": Date.now.timeIntervalSince(requestedAt) * 1000]
            NSLog("Native pronunciation started (%@), engine latency %.1f ms", activeAccent,
                  Date.now.timeIntervalSince(requestedAt) * 1000)
            pendingStart?(.success(reply))
            pendingStart = nil
        } else {
            pendingStart?(.failure(CancellationError()))
            pendingStart = nil
            activeUtterance = nil
            requestID = nil
        }
    }
}

private final class SpeechObserver: NSObject, AVSpeechSynthesizerDelegate {
    let event: (AVSpeechUtterance, Bool) -> Void
    init(event: @escaping (AVSpeechUtterance, Bool) -> Void) { self.event = event }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { event(utterance, true) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { event(utterance, false) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { event(utterance, false) }
}
