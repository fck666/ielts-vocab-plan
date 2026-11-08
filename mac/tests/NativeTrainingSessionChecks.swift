import Foundation
import Combine

@main
struct NativeTrainingSessionChecks {
    @MainActor
    static func main() throws {
        let words = try JSONDecoder().decode([NativeWord].self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let session = NativeTrainingSession()
        session.queue = Array(words.prefix(2))
        session.mode = .spelling
        var changes = 0
        let subscription = session.objectWillChange.sink { changes += 1 }
        session.answer = "unfinished spelling"
        try require(changes > 0, "Typing must notify SwiftUI bindings")
        session.mode = .meaning
        try require(session.answer.isEmpty, "Spelling drafts must not leak into another mode")
        session.selectedOption = words[1].id
        session.correct = false
        session.feedback = "再记一下这个词"
        session.answered = true
        session.mode = .context
        try require(!session.answered && session.selectedOption == nil, "Context needs independent answer state")
        session.mode = .spelling
        try require(session.answer == "unfinished spelling", "A mode round-trip must preserve unfinished typing")
        session.mode = .meaning
        try require(session.answered && session.selectedOption == words[1].id && session.feedback == "再记一下这个词",
                    "Returning to an answered mode must preserve its selection and feedback")
        session.mode = .spelling
        session.index = 1
        try require(session.answer.isEmpty, "A new word needs its own draft")
        session.answer = "second word draft"
        session.index = 0
        try require(session.answer == "unfinished spelling", "Previous-word navigation must restore that word's draft")
        session.clearCurrentResponse()
        try require(session.answer.isEmpty && session.feedback.isEmpty, "Explicit clear must empty the active draft")
        session.mode = .meaning
        try require(session.answered, "Clearing spelling must leave the meaning answer intact")
        session.mode = .spelling
        session.index = 1
        try require(session.answer == "second word draft", "Clearing must leave other words intact")
        session.retryRound = true
        try require(session.answer.isEmpty, "Retry rounds must start blank rather than reveal the previous answer")
        session.answer = "retry draft"
        session.mode = .context
        session.mode = .spelling
        try require(session.answer == "retry draft", "Retry drafts must also survive tab switches")
        session.retryRound = false
        try require(session.answer == "second word draft", "Retry input must not overwrite the first round")
        session.resetResponses()
        try require(session.answer.isEmpty, "A fresh session must clear drafts")
        session.mode = .meaning
        session.index = 0
        try require(!session.answered && session.selectedOption == nil, "A fresh session must clear old submitted state too")
        withExtendedLifetime(subscription) {}
        print("Training session checks passed: mode and word drafts, submitted feedback, explicit clear, independent retry rounds and fresh sessions.")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckError.failed(message) }
    }
}

private enum CheckError: Error { case failed(String) }
