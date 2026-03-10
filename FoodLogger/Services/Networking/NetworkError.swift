import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
    case networkUnavailable
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error (HTTP \(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .networkUnavailable:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
