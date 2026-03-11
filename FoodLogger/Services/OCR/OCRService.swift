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
            let lock = NSLock()
            var hasResumed = false

            func resumeOnce(_ result: Result<[RecognizedTextBlock], Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumeOnce(.failure(OCRError.recognitionFailed(error)))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    resumeOnce(.success([]))
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

                resumeOnce(.success(blocks))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "nb"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(.failure(OCRError.recognitionFailed(error)))
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
