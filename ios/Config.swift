import Foundation

public struct Config {
    public static let serverHost: String = "192.168.1.13"
    public static let serverPort: Int = 8000

    #if targetEnvironment(simulator)
    public static let apiBaseURL: String = "http://127.0.0.1:\(serverPort)/api/v1/interview"
    #else
    public static let apiBaseURL: String = "http://\(serverHost):\(serverPort)/api/v1/interview"
    #endif
}
