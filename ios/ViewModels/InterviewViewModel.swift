import Combine
import Foundation
import SwiftUI

public enum InterviewState: Equatable {
    case setup
    case inProgress
    case evaluatingAnswer
    case completed
    case error(String)
}

@MainActor
public final class InterviewViewModel: ObservableObject {
    @Published public var state: InterviewState = .setup

    @Published public var selectedRole: String = "iOS Developer (Swift)"
    @Published public var selectedSeniority: String = "Senior"
    @Published public var selectedTopics: Set<String> = [
        "Memory Management (ARC)",
        "Swift Concurrency & Actors",
        "LLVM & Architecture"
    ]
    @Published public var maxTurns: Int = 4

    @Published public var serverURLString: String = Config.apiBaseURL

    @Published public private(set) var sessionId: String?
    @Published public private(set) var currentQuestion: String = ""
    @Published public private(set) var currentTurn: Int = 1
    @Published public private(set) var lastFeedback: String?
    @Published public private(set) var lastTranscribedText: String?
    @Published public private(set) var turnsHistory: [InterviewTurn] = []

    @Published public private(set) var finalReport: InterviewReport?

    @Published public var errorMessage: String?

    private let apiService: APIService
    public let audioManager: AudioRecorderManager

    public init(
        apiService: APIService = .shared,
        audioManager: AudioRecorderManager? = nil
    ) {
        self.apiService = apiService
        self.audioManager = audioManager ?? AudioRecorderManager.shared
    }

    public func updateServerURL(_ newURL: String) {
        let trimmed = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.serverURLString = trimmed
        Task {
            _ = await apiService.setBaseURL(string: trimmed)
        }
    }

    public func startInterview() async {
        state = .evaluatingAnswer
        errorMessage = nil

        _ = await apiService.setBaseURL(string: serverURLString)

        let request = StartSessionRequest(
            role: selectedRole,
            seniorityLevel: selectedSeniority,
            focusTopics: Array(selectedTopics),
            maxTurns: maxTurns
        )

        do {
            let response = try await apiService.startSession(request: request)
            self.sessionId = response.sessionId
            self.currentQuestion = response.firstQuestion
            self.currentTurn = response.turnNumber
            self.maxTurns = response.maxTurns
            self.state = .inProgress
        } catch {
            self.errorMessage = error.localizedDescription
            self.state = .error(error.localizedDescription)
        }
    }

    public func startAudioRecording() async {
        errorMessage = nil
        do {
            try await audioManager.startRecording()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleRecording() async {
        if audioManager.isRecording {
            await submitRecordedAudio()
        } else {
            await startAudioRecording()
        }
    }

    public func submitRecordedAudio() async {
        guard let sessionId = sessionId else { return }
        guard let audioData = audioManager.stopRecording() else {
            return
        }

        state = .evaluatingAnswer
        errorMessage = nil

        do {
            let response = try await apiService.submitAudioAnswer(
                sessionId: sessionId,
                audioData: audioData,
                filename: "answer_\(currentTurn).m4a"
            )

            self.lastTranscribedText = response.transcribedText
            self.lastFeedback = response.feedback
            self.currentTurn = response.currentTurn

            let turnRecord = InterviewTurn(
                turnNumber: response.turnNumber,
                question: currentQuestion,
                candidateAnswer: response.transcribedText,
                feedback: response.feedback,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            self.turnsHistory.append(turnRecord)

            if response.isFinished || response.nextQuestion == nil {
                await finishInterview()
            } else {
                self.currentQuestion = response.nextQuestion ?? ""
                self.state = .inProgress
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.state = .inProgress // Kullanıcı tekrar deneyebilsin
        }
    }

    public func submitTextAnswer(_ text: String) async {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sessionId = sessionId, !cleanText.isEmpty else { return }

        state = .evaluatingAnswer
        errorMessage = nil

        do {
            let response = try await apiService.submitTextAnswer(
                sessionId: sessionId,
                candidateAnswer: cleanText
            )

            self.lastTranscribedText = cleanText
            self.lastFeedback = response.feedback
            self.currentTurn = response.currentTurn

            let turnRecord = InterviewTurn(
                turnNumber: response.turnNumber,
                question: currentQuestion,
                candidateAnswer: cleanText,
                feedback: response.feedback,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            self.turnsHistory.append(turnRecord)

            if response.isFinished || response.nextQuestion == nil {
                await finishInterview()
            } else {
                self.currentQuestion = response.nextQuestion ?? ""
                self.state = .inProgress
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.state = .inProgress
        }
    }

    public func finishInterview() async {
        guard let sessionId = sessionId else { return }
        state = .evaluatingAnswer

        do {
            let response = try await apiService.finishSession(sessionId: sessionId)
            self.finalReport = response.report
            self.turnsHistory = response.turns.isEmpty ? self.turnsHistory : response.turns
            self.state = .completed
        } catch {
            self.errorMessage = error.localizedDescription
            self.state = .completed
        }
    }

    public func reset() {
        self.sessionId = nil
        self.currentQuestion = ""
        self.currentTurn = 1
        self.lastFeedback = nil
        self.lastTranscribedText = nil
        self.turnsHistory.removeAll()
        self.finalReport = nil
        self.errorMessage = nil
        self.state = .setup
    }
}
