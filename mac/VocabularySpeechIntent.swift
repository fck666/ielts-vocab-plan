import AppIntents

enum VocabularySpeechAccent: String, AppEnum {
    case uk, us

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "发音口音"
    static var caseDisplayRepresentations: [VocabularySpeechAccent: DisplayRepresentation] = [
        .uk: "英音 UK", .us: "美音 US",
    ]

    var locale: String { self == .uk ? "en-GB" : "en-US" }
}

// AudioPlaybackIntent executes in the containing app, keeping speech alive without opening a page.
struct VocabularyPronounceIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "朗读 IELTS 单词"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "单词") var term: String
    @Parameter(title: "口音") var accent: VocabularySpeechAccent

    init() {}

    init(term: String, accent: VocabularySpeechAccent) {
        self.term = term
        self.accent = accent
    }

    func perform() async throws -> some IntentResult {
        try await VocabularySpeech.shared.speak(text: term, locale: accent.locale)
        return .result()
    }
}
