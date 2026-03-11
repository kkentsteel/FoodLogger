import Foundation

// MARK: - Request/Response DTOs

struct ClaudeRequest: Encodable, Sendable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct ClaudeMessage: Codable, Sendable {
    let role: String    // "user" or "assistant"
    let content: String
}

struct ClaudeResponse: Decodable, Sendable {
    let id: String
    let content: [ClaudeContentBlock]
    let stopReason: String?
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case id, content
        case stopReason = "stop_reason"
        case usage
    }
}

struct ClaudeContentBlock: Decodable, Sendable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Decodable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct ClaudeErrorResponse: Decodable, Sendable {
    let error: ClaudeErrorDetail
}

struct ClaudeErrorDetail: Decodable, Sendable {
    let type: String
    let message: String
}

// MARK: - Service

actor ClaudeAPIService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    private static let maxRetries = 2
    private static let baseRetryDelay: TimeInterval = 1.0

    /// Send a message to Claude and get a response. Retries on 429/5xx.
    func sendMessage(
        apiKey: String,
        systemPrompt: String?,
        messages: [ClaudeMessage]
    ) async throws -> String {
        guard let url = URL(string: Constants.API.claudeEndpoint) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.API.claudeVersion, forHTTPHeaderField: "anthropic-version")

        let body = ClaudeRequest(
            model: Constants.API.claudeModel,
            maxTokens: Constants.API.claudeMaxTokens,
            system: systemPrompt,
            messages: messages
        )

        request.httpBody = try JSONEncoder().encode(body)

        var lastError: Error = ClaudeAPIError.invalidResponse

        for attempt in 0...Self.maxRetries {
            if attempt > 0 {
                let delay = Self.baseRetryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(for: .seconds(delay))
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                guard let text = decoded.content.first?.text else {
                    throw ClaudeAPIError.emptyResponse
                }
                return text

            case 401:
                throw ClaudeAPIError.invalidAPIKey

            case 429:
                lastError = ClaudeAPIError.rateLimited
                continue // retry

            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                    throw ClaudeAPIError.apiError(errorResponse.error.message)
                }
                throw ClaudeAPIError.httpError(httpResponse.statusCode)

            case 500...599:
                lastError = ClaudeAPIError.serverError
                continue // retry

            default:
                throw ClaudeAPIError.httpError(httpResponse.statusCode)
            }
        }

        throw lastError
    }
}

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case rateLimited
    case emptyResponse
    case httpError(Int)
    case serverError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .invalidAPIKey:
            return "Invalid API key. Check your key in Profile settings."
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .emptyResponse:
            return "Received empty response"
        case .httpError(let code):
            return "API error (HTTP \(code))"
        case .serverError:
            return "Claude API is temporarily unavailable. Try again later."
        case .apiError(let message):
            return message
        }
    }
}
