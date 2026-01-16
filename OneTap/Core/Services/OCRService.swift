//
//  OCRService.swift
//  OneTap
//
//  Vision framework OCR service for extracting text from images
//

import Vision
import UIKit

@MainActor
class OCRService {

    struct OCRResult {
        let fullText: String
        let lines: [String]
        let confidence: Float // 0.0 to 1.0
    }

    func extractText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw ServiceError.operationFailed("Failed to process image")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ServiceError.operationFailed("OCR failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ServiceError.operationFailed("No text found in image"))
                    return
                }

                var lines: [String] = []
                var totalConfidence: Float = 0

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    lines.append(topCandidate.string)
                    totalConfidence += topCandidate.confidence
                }

                let averageConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)
                let fullText = lines.joined(separator: "\n")

                let result = OCRResult(
                    fullText: fullText,
                    lines: lines,
                    confidence: averageConfidence
                )

                continuation.resume(returning: result)
            }

            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "ms-MY"] // English & Malay
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ServiceError.operationFailed("OCR processing failed: \(error.localizedDescription)"))
            }
        }
    }
}
