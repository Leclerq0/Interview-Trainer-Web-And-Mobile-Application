import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz API uç nokta adresi."
        case .serverError(let code, let msg):
            return "Sunucu Hatası (\(code)): \(msg)"
        case .decodingError(let err):
            return "Yanıt işlenemedi (JSON Decode Hatası): \(err.localizedDescription)"
        case .networkError(let err):
            return "Ağ Hatası: \(err.localizedDescription)\n(Backend sunucusunun çalıştığından ve doğru IP adresinin girildiğinden emin olun)."
        }
    }
}

public actor APIService {
    public static let shared = APIService()

    public static let defaultURLString = Config.apiBaseURL

    public var baseURL: URL

    public init(baseURL: URL = URL(string: Config.apiBaseURL)!) {
        self.baseURL = baseURL
    }

    public func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    public func setBaseURL(string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        self.baseURL = url
        return true
    }

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public func startSession(request: StartSessionRequest) async throws -> StartSessionResponse {
        let url = baseURL.appendingPathComponent("start")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        return try await execute(urlRequest)
    }

    public func submitTextAnswer(sessionId: String, candidateAnswer: String) async throws -> SubmitAnswerResponse {
        let url = baseURL.appendingPathComponent("answer")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SubmitAnswerRequest(sessionId: sessionId, candidateAnswer: candidateAnswer)
        urlRequest.httpBody = try encoder.encode(payload)

        return try await execute(urlRequest)
    }

    public func submitAudioAnswer(sessionId: String, audioData: Data, filename: String = "answer.m4a") async throws -> SubmitAnswerAudioResponse {
        let url = baseURL.appendingPathComponent("answer-audio")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body
        return try await execute(urlRequest)
    }

    public func finishSession(sessionId: String) async throws -> FinishSessionResponse {
        let url = baseURL.appendingPathComponent("\(sessionId)/finish")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        return try await execute(urlRequest)
    }

    public func transcribeAudio(audioData: Data, filename: String = "speech.m4a") async throws -> TranscriptionResponse {
        let url = baseURL.appendingPathComponent("transcribe")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body
        return try await execute(urlRequest)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "InvalidResponse", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Bilinmeyen sunucu hatası"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
