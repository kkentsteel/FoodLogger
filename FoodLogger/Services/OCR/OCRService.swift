import Vision
import UIKit
import Foundation

/// Performs text recognition on images using the Vision framework.
actor OCRService {

    /// Recognize text in an image. Returns all recognized text observations.
    func recognizeText(in image: UIImage) async throws -> [RecognizedTextBlock] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "nb"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }
}

// MARK: - Models

struct RecognizedTextBlock: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        }
    }
}
