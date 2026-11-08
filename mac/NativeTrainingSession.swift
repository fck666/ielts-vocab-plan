import Foundation
import Combine

enum NativeStudyMode: String, CaseIterable, Identifiable {
    case meaning, spelling, context
    var id: String { rawValue }
    var title: String {
        switch self {
        case .meaning: "认词义"
        case .spelling: "默写拼写"
        case .context: "语境应用"
        }
    }
    var symbol: String {
        switch self {
        case .meaning: "character.book.closed"
        case .spelling: "keyboard"
        case .context: "text.quote"
        }
    }
}

private struct NativeTrainingResponse {
    var selectedOption: String?
    var answer = ""
    var answered = false
    var correct = false
    var feedback = ""
}

@MainActor
final class NativeTrainingSession: ObservableObject {
    private struct QuestionKey: Hashable {
        let wordID: String
        let mode: NativeStudyMode
        let retryRound: Bool
    }

    @Published var queue: [NativeWord] = []
    @Published var retryQueue: [NativeWord] = []
    @Published var index = 0
    @Published var mode: NativeStudyMode = .meaning
    @Published var completed = false
    @Published var retryRound = false
    @Published var showHint = false
    @Published var meaningVisible = true
    @Published var hoveredOptionID: String?
    @Published var feedbackVersion = 0
    @Published var requestVersion = 0
    @Published var startedVersion = -1
    // Keep drafts and submitted feedback for each mode without re-recording answers on a tab switch.
    @Published private var responses: [QuestionKey: NativeTrainingResponse] = [:]

    var isInitialized: Bool { startedVersion >= 0 }
    private var currentKey: QuestionKey? {
        guard queue.indices.contains(index) else { return nil }
        return QuestionKey(wordID: queue[index].id, mode: mode, retryRound: retryRound)
    }
    private var currentResponse: NativeTrainingResponse {
        currentKey.flatMap { responses[$0] } ?? NativeTrainingResponse()
    }

    var selectedOption: String? {
        get { currentResponse.selectedOption }
        set { updateResponse { $0.selectedOption = newValue } }
    }
    var answer: String {
        get { currentResponse.answer }
        set { updateResponse { $0.answer = newValue } }
    }
    var answered: Bool {
        get { currentResponse.answered }
        set { updateResponse { $0.answered = newValue } }
    }
    var correct: Bool {
        get { currentResponse.correct }
        set { updateResponse { $0.correct = newValue } }
    }
    var feedback: String {
        get { currentResponse.feedback }
        set { updateResponse { $0.feedback = newValue } }
    }

    func clearCurrentResponse() {
        guard let currentKey else { return }
        responses.removeValue(forKey: currentKey)
    }

    func resetResponses() {
        responses.removeAll()
        hoveredOptionID = nil
    }

    private func updateResponse(_ update: (inout NativeTrainingResponse) -> Void) {
        guard let currentKey else { return }
        var response = currentResponse
        update(&response)
        responses[currentKey] = response
    }
}
