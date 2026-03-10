import Testing
import Foundation
@testable import FoodLogger

@Suite("ClaudeAPIService Tests")
struct ClaudeAPIServiceTests {

    // MARK: - Request Encoding

    @Test("ClaudeRequest encodes correctly with snake_case keys")
    func requestEncoding() throws {
        let request = ClaudeRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024,
            system: "You are a helpful assistant.",
            messages: [
                ClaudeMessage(role: "user", content: "Hello")
            ]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["model"] as? String == "claude-sonnet-4-20250514")
        #expect(json["max_tokens"] as? Int == 1024)
        #expect(json["system"] as? String == "You are a helpful assistant.")

        let messages = json["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        #expect(messages?.first?["role"] as? String == "user")
        #expect(messages?.first?["content"] as? String == "Hello")
    }

    @Test("ClaudeRequest encodes with nil system prompt")
    func requestEncodingNilSystem() throws {
        let request = ClaudeRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 512,
            system: nil,
            messages: [
                ClaudeMessage(role: "user", content: "Hi")
            ]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // system should not be present when nil
        #expect(json["system"] == nil)
        #expect(json["max_tokens"] as? Int == 512)
    }

    // MARK: - Response Decoding

    @Test("ClaudeResponse decodes successfully")
    func responseDecoding() throws {
        let json = """
        {
            "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "Hello! How can I help you today?"
                }
            ],
            "stop_reason": "end_turn",
            "usage": {
                "input_tokens": 25,
                "output_tokens": 15
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: json)

        #expect(response.id == "msg_01XFDUDYJgAACzvnptvVoYEL")
        #expect(response.content.count == 1)
        #expect(response.content.first?.type == "text")
        #expect(response.content.first?.text == "Hello! How can I help you today?")
        #expect(response.stopReason == "end_turn")
        #expect(response.usage?.inputTokens == 25)
        #expect(response.usage?.outputTokens == 15)
    }

    @Test("ClaudeResponse decodes with multiple content blocks")
    func responseMultipleBlocks() throws {
        let json = """
        {
            "id": "msg_123",
            "content": [
                {"type": "text", "text": "First block"},
                {"type": "text", "text": "Second block"}
            ],
            "stop_reason": "end_turn",
            "usage": {
                "input_tokens": 10,
                "output_tokens": 20
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: json)

        #expect(response.content.count == 2)
        #expect(response.content[0].text == "First block")
        #expect(response.content[1].text == "Second block")
    }

    // MARK: - Error Decoding

    @Test("ClaudeErrorResponse decodes correctly")
    func errorResponseDecoding() throws {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "invalid_request_error",
                "message": "max_tokens: integer above 0 expected"
            }
        }
        """.data(using: .utf8)!

        let errorResponse = try JSONDecoder().decode(ClaudeErrorResponse.self, from: json)

        #expect(errorResponse.error.type == "invalid_request_error")
        #expect(errorResponse.error.message == "max_tokens: integer above 0 expected")
    }

    // MARK: - Error Descriptions

    @Test("ClaudeAPIError provides descriptive messages")
    func errorDescriptions() {
        let errors: [(ClaudeAPIError, String)] = [
            (.invalidURL, "Invalid API URL"),
            (.invalidResponse, "Invalid response from API"),
            (.invalidAPIKey, "Invalid API key. Check your key in Profile settings."),
            (.rateLimited, "Rate limited. Please wait a moment and try again."),
            (.emptyResponse, "Received empty response"),
            (.httpError(403), "API error (HTTP 403)"),
            (.serverError, "Claude API is temporarily unavailable. Try again later."),
            (.apiError("Custom error"), "Custom error")
        ]

        for (error, expectedDescription) in errors {
            #expect(error.localizedDescription == expectedDescription)
        }
    }

    // MARK: - ClaudeMessage Coding

    @Test("ClaudeMessage round-trips through Codable")
    func messageCodable() throws {
        let message = ClaudeMessage(role: "user", content: "What should I eat?")

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ClaudeMessage.self, from: data)

        #expect(decoded.role == "user")
        #expect(decoded.content == "What should I eat?")
    }
}
