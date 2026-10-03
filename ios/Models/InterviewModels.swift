import Foundation

public nonisolated struct StartSessionRequest: Codable, Sendable {
    public let role: String
    public let seniorityLevel: String
    public let focusTopics: [String]?
    public let maxTurns: Int

    public init(
        role: String,
        seniorityLevel: String = "Senior",
        focusTopics: [String]? = nil,
        maxTurns: Int = 4
    ) {
        self.role = role
        self.seniorityLevel = seniorityLevel
        self.focusTopics = focusTopics
        self.maxTurns = maxTurns
    }

    enum CodingKeys: String, CodingKey {
        case role
        case seniorityLevel = "seniority_level"
        case focusTopics = "focus_topics"
        case maxTurns = "max_turns"
    }
}

public nonisolated struct StartSessionResponse: Codable, Sendable {
    public let sessionId: String
    public let role: String
    public let seniorityLevel: String
    public let firstQuestion: String
    public let turnNumber: Int
    public let maxTurns: Int
    public let createdAt: String

    public init(
        sessionId: String,
        role: String,
        seniorityLevel: String,
        firstQuestion: String,
        turnNumber: Int,
        maxTurns: Int,
        createdAt: String
    ) {
        self.sessionId = sessionId
        self.role = role
        self.seniorityLevel = seniorityLevel
        self.firstQuestion = firstQuestion
        self.turnNumber = turnNumber
        self.maxTurns = maxTurns
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case role
        case seniorityLevel = "seniority_level"
        case firstQuestion = "first_question"
        case turnNumber = "turn_number"
        case maxTurns = "max_turns"
        case createdAt = "created_at"
    }
}

public nonisolated struct SubmitAnswerRequest: Codable, Sendable {
    public let sessionId: String
    public let candidateAnswer: String

    public init(sessionId: String, candidateAnswer: String) {
        self.sessionId = sessionId
        self.candidateAnswer = candidateAnswer
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case candidateAnswer = "candidate_answer"
    }
}

public nonisolated struct SubmitAnswerResponse: Codable, Sendable {
    public let sessionId: String
    public let turnNumber: Int
    public let feedback: String
    public let nextQuestion: String?
    public let isFinished: Bool
    public let currentTurn: Int
    public let maxTurns: Int

    public init(
        sessionId: String,
        turnNumber: Int,
        feedback: String,
        nextQuestion: String?,
        isFinished: Bool,
        currentTurn: Int,
        maxTurns: Int
    ) {
        self.sessionId = sessionId
        self.turnNumber = turnNumber
        self.feedback = feedback
        self.nextQuestion = nextQuestion
        self.isFinished = isFinished
        self.currentTurn = currentTurn
        self.maxTurns = maxTurns
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case turnNumber = "turn_number"
        case feedback
        case nextQuestion = "next_question"
        case isFinished = "is_finished"
        case currentTurn = "current_turn"
        case maxTurns = "max_turns"
    }
}

public nonisolated struct SubmitAnswerAudioResponse: Codable, Sendable {
    public let sessionId: String
    public let turnNumber: Int
    public let transcribedText: String
    public let feedback: String
    public let nextQuestion: String?
    public let isFinished: Bool
    public let currentTurn: Int
    public let maxTurns: Int

    public init(
        sessionId: String,
        turnNumber: Int,
        transcribedText: String,
        feedback: String,
        nextQuestion: String?,
        isFinished: Bool,
        currentTurn: Int,
        maxTurns: Int
    ) {
        self.sessionId = sessionId
        self.turnNumber = turnNumber
        self.transcribedText = transcribedText
        self.feedback = feedback
        self.nextQuestion = nextQuestion
        self.isFinished = isFinished
        self.currentTurn = currentTurn
        self.maxTurns = maxTurns
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case turnNumber = "turn_number"
        case transcribedText = "transcribed_text"
        case feedback
        case nextQuestion = "next_question"
        case isFinished = "is_finished"
        case currentTurn = "current_turn"
        case maxTurns = "max_turns"
    }
}

public nonisolated struct TranscriptionResponse: Codable, Sendable {
    public let transcription: String
    public let detectedMimeType: String
    public let fileSizeBytes: Int

    public init(transcription: String, detectedMimeType: String, fileSizeBytes: Int) {
        self.transcription = transcription
        self.detectedMimeType = detectedMimeType
        self.fileSizeBytes = fileSizeBytes
    }

    enum CodingKeys: String, CodingKey {
        case transcription
        case detectedMimeType = "detected_mime_type"
        case fileSizeBytes = "file_size_bytes"
    }
}

public nonisolated struct InterviewReport: Codable, Sendable {
    public let overallScore: Int
    public let performanceLevel: String
    public let summary: String
    public let strengths: [String]
    public let criticalWeaknesses: [String]
    public let recommendedTopics: [String]

    public init(
        overallScore: Int,
        performanceLevel: String,
        summary: String,
        strengths: [String],
        criticalWeaknesses: [String],
        recommendedTopics: [String]
    ) {
        self.overallScore = overallScore
        self.performanceLevel = performanceLevel
        self.summary = summary
        self.strengths = strengths
        self.criticalWeaknesses = criticalWeaknesses
        self.recommendedTopics = recommendedTopics
    }

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case performanceLevel = "performance_level"
        case summary
        case strengths
        case criticalWeaknesses = "critical_weaknesses"
        case recommendedTopics = "recommended_topics"
    }
}

public nonisolated struct InterviewTurn: Codable, Sendable, Identifiable {
    public var id: Int { turnNumber }
    public let turnNumber: Int
    public let question: String
    public let candidateAnswer: String
    public let feedback: String
    public let timestamp: String

    public init(
        turnNumber: Int,
        question: String,
        candidateAnswer: String,
        feedback: String,
        timestamp: String
    ) {
        self.turnNumber = turnNumber
        self.question = question
        self.candidateAnswer = candidateAnswer
        self.feedback = feedback
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case turnNumber = "turn_number"
        case question
        case candidateAnswer = "candidate_answer"
        case feedback
        case timestamp
    }
}

public nonisolated struct FinishSessionResponse: Codable, Sendable {
    public let sessionId: String
    public let report: InterviewReport
    public let totalTurns: Int
    public let turns: [InterviewTurn]

    public init(sessionId: String, report: InterviewReport, totalTurns: Int, turns: [InterviewTurn]) {
        self.sessionId = sessionId
        self.report = report
        self.totalTurns = totalTurns
        self.turns = turns
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case report
        case totalTurns = "total_turns"
        case turns
    }
}
