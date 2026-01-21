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
        let detectedLanguages: [String] // Languages detected in the image
        let qrCodeData: [QRCodeData]?  // PHASE 3: Detected QR codes
    }

    struct QRCodeData {
        let payload: String
        let type: QRCodeType

        enum QRCodeType {
            case duitNow       // Malaysian instant payment
            case url           // Regular URL
            case text          // Plain text
            case unknown
        }
    }

    private let imagePreprocessingService: ImagePreprocessingService

    init(imagePreprocessingService: ImagePreprocessingService) {
        self.imagePreprocessingService = imagePreprocessingService
    }

    /// Extracts text from image with smart preprocessing based on image source type
    /// - Screenshots: No preprocessing (already perfect quality)
    /// - Camera photos: Conservative preprocessing (gentle enhancements)
    /// - Unknown: Dual OCR approach, selecting the better result
    func extractText(from image: UIImage) async throws -> OCRResult {
        let sourceType = imagePreprocessingService.detectImageSourceType(image)

        switch sourceType {
        case .screenshot:
            // Screenshots are already perfect digital images - no preprocessing needed
            return try await performOCR(on: image)

        case .cameraPhoto:
            // Camera photos benefit from conservative preprocessing
            let processed = try await imagePreprocessingService.preprocessConservative(image)
            return try await performOCR(on: processed)

        case .unknown:
            // Unknown source - try both approaches and pick the better result
            return try await extractTextWithFallback(from: image)
        }
    }

    /// Dual OCR approach: runs OCR with and without preprocessing, selects better result
    func extractTextWithFallback(from image: UIImage) async throws -> OCRResult {
        // Run OCR on original image (best for screenshots)
        let originalResult = try await performOCR(on: image)

        // Run OCR on conservatively preprocessed image (best for camera photos)
        let processedImage = try await imagePreprocessingService.preprocessConservative(image)
        let processedResult = try await performOCR(on: processedImage)

        // Select the better result based on quality heuristics
        return selectBetterResult(originalResult, processedResult)
    }

    /// Extracts text without preprocessing (for testing/comparison)
    func extractTextWithoutPreprocessing(from image: UIImage) async throws -> OCRResult {
        return try await performOCR(on: image)
    }

    /// Extracts text with full aggressive preprocessing (for very poor quality images)
    func extractTextWithFullPreprocessing(from image: UIImage) async throws -> OCRResult {
        let processed = try await imagePreprocessingService.preprocessFull(image)
        return try await performOCR(on: processed)
    }

    private func performOCR(on image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw ServiceError.operationFailed("Failed to process image")
        }

        // PHASE 3: Detect QR codes in parallel with text OCR
        let qrCodeData = try? await detectQRCodes(in: cgImage)

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
                var detectedLanguages: Set<String> = []

                for observation in observations {
                    // ENHANCEMENT: Consider top 2 candidates for better accuracy
                    guard let topCandidate = observation.topCandidates(2).first else { continue }
                    lines.append(topCandidate.string)
                    totalConfidence += topCandidate.confidence
                }

                let averageConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)
                let fullText = lines.joined(separator: "\n")

                // Detect languages present in the text
                if #available(iOS 16.0, *) {
                    // Use revision2 for better language detection
                    detectedLanguages = self.detectLanguages(in: fullText)
                }

                let result = OCRResult(
                    fullText: fullText,
                    lines: lines,
                    confidence: averageConfidence,
                    detectedLanguages: Array(detectedLanguages),
                    qrCodeData: qrCodeData  // PHASE 3: Include QR code data
                )

                continuation.resume(returning: result)
            }

            // ENHANCED: Configure for accurate text recognition with multi-language support
            request.recognitionLevel = .accurate

            // Expanded language support for Malaysian receipts
            // English, Malay, Chinese (Simplified & Traditional)
            request.recognitionLanguages = [
                "en-US",    // English
                "ms-MY",    // Malay
                "zh-Hans",  // Chinese Simplified
                "zh-Hant",  // Chinese Traditional
            ]

            request.usesLanguageCorrection = true

            // ENHANCEMENT: Use automatic language detection
            request.automaticallyDetectsLanguage = true

            // ENHANCEMENT: Minimize false positives
            request.minimumTextHeight = 0.01  // Ignore very small text (noise)

            // Use revision 3 if available (better accuracy on iOS 16+)
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ServiceError.operationFailed("OCR processing failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Language Detection

    /// Detects languages present in the text using NaturalLanguage framework
    private func detectLanguages(in text: String) -> Set<String> {
        var languages: Set<String> = []

        // Simple heuristic: check for common language patterns
        if text.range(of: "[a-zA-Z]", options: .regularExpression) != nil {
            languages.insert("en")
        }

        // Check for Chinese characters
        if text.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil {
            languages.insert("zh")
        }

        // Check for common Malay words
        let malayWords = ["ringgit", "sen", "terima", "kasih", "bayaran", "jumlah"]
        let lowercased = text.lowercased()
        for word in malayWords {
            if lowercased.contains(word) {
                languages.insert("ms")
                break
            }
        }

        return languages
    }

    // MARK: - QR Code Detection (Phase 3)

    /// Detects and decodes QR codes in the image
    private func detectQRCodes(in cgImage: CGImage) async throws -> [QRCodeData] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ServiceError.operationFailed("QR detection failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var qrCodes: [QRCodeData] = []

                for observation in observations {
                    guard observation.symbology == .qr,
                          let payload = observation.payloadStringValue else {
                        continue
                    }

                    // Determine QR code type
                    let type = self.identifyQRCodeType(payload)

                    qrCodes.append(QRCodeData(payload: payload, type: type))
                }

                continuation.resume(returning: qrCodes)
            }

            // Configure to detect QR codes
            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ServiceError.operationFailed("QR detection processing failed: \(error.localizedDescription)"))
            }
        }
    }

    /// Identifies the type of QR code based on payload
    private func identifyQRCodeType(_ payload: String) -> QRCodeData.QRCodeType {
        let lowercased = payload.lowercased()

        // DuitNow QR codes (Malaysian instant payment)
        // Format typically starts with specific identifiers
        if lowercased.contains("duitnow") ||
           lowercased.hasPrefix("00020") ||  // EMV QR Code format
           lowercased.contains("my.duitnow") {
            return .duitNow
        }

        // URL
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return .url
        }

        // Check if it looks like structured payment data
        if payload.count > 50 && payload.contains(where: { $0.isNumber }) {
            return .unknown  // Likely payment QR but unknown format
        }

        return .text
    }

    /// Extracts payment information from DuitNow QR code
    func extractDuitNowPaymentInfo(from qrPayload: String) -> (amount: Double?, merchant: String?, reference: String?)? {
        // DuitNow QR codes follow EMVCo QR Code Specification
        // Format: TLV (Tag-Length-Value)

        var amount: Double? = nil
        var merchant: String? = nil
        let reference: String? = nil

        // Simple parser for common tags
        // Tag 54: Transaction Amount
        // Tag 59: Merchant Name
        // Tag 62: Additional Data (may contain reference)

        let amountPattern = "54\\d{2}([\\d.]+)"
        let merchantPattern = "59\\d{2}(.+?)(?=\\d{2}\\d|$)"

        if let regex = try? NSRegularExpression(pattern: amountPattern),
           let match = regex.firstMatch(in: qrPayload, range: NSRange(qrPayload.startIndex..., in: qrPayload)),
           let range = Range(match.range(at: 1), in: qrPayload) {
            amount = Double(String(qrPayload[range]))
        }

        if let regex = try? NSRegularExpression(pattern: merchantPattern),
           let match = regex.firstMatch(in: qrPayload, range: NSRange(qrPayload.startIndex..., in: qrPayload)),
           let range = Range(match.range(at: 1), in: qrPayload) {
            merchant = String(qrPayload[range])
        }

        if amount != nil || merchant != nil {
            return (amount: amount, merchant: merchant, reference: reference)
        }

        return nil
    }

    // MARK: - Quality Scoring for Result Selection

    /// Selects the better OCR result between two candidates based on quality heuristics
    private func selectBetterResult(_ result1: OCRResult, _ result2: OCRResult) -> OCRResult {
        let score1 = calculateContentQualityScore(result1)
        let score2 = calculateContentQualityScore(result2)

        // If both scores are very low, prefer higher confidence
        if score1 < 5 && score2 < 5 {
            return result1.confidence >= result2.confidence ? result1 : result2
        }

        // Return the result with higher quality score
        return score1 >= score2 ? result1 : result2
    }

    /// Calculates a quality score for OCR results based on content heuristics
    /// Higher score = better quality, more likely to be correctly extracted text
    private func calculateContentQualityScore(_ result: OCRResult) -> Int {
        var score = 0
        let text = result.fullText

        // Check for currency patterns (Malaysian Ringgit)
        // RM, MYR followed by numbers
        let rmPattern = "(?i)(RM|MYR)\\s*[\\d,]+\\.?\\d*"
        if text.range(of: rmPattern, options: .regularExpression) != nil {
            score += 20
        }

        // Check for decimal amounts (common in receipts)
        let decimalPattern = "\\d+\\.\\d{2}"
        let decimalMatches = text.matches(of: try! Regex(decimalPattern))
        score += min(decimalMatches.count * 5, 25) // Cap at 25 points

        // Check for date patterns (dd/mm/yyyy, dd-mm-yyyy, etc.)
        let datePatterns = [
            "\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}",
            "\\d{1,2}\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{2,4}"
        ]
        for pattern in datePatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                score += 15
                break
            }
        }

        // Check for time patterns (HH:MM, HH:MM:SS)
        let timePattern = "\\d{1,2}:\\d{2}(:\\d{2})?"
        if text.range(of: timePattern, options: .regularExpression) != nil {
            score += 10
        }

        // Check for common receipt keywords
        let receiptKeywords = [
            "total", "subtotal", "tax", "gst", "sst", "change", "cash", "card",
            "receipt", "invoice", "qty", "quantity", "price", "amount",
            "terima kasih", "thank you", "payment"
        ]
        let lowercasedText = text.lowercased()
        for keyword in receiptKeywords {
            if lowercasedText.contains(keyword) {
                score += 5
            }
        }

        // Penalize garbage characters (excessive special characters, control characters)
        let garbagePattern = "[\\x00-\\x1F\\x7F-\\x9F]"
        let garbageCount = text.matches(of: try! Regex(garbagePattern)).count
        score -= garbageCount * 3

        // Penalize excessive consonant clusters (indication of garbled text)
        let consonantClusterPattern = "[bcdfghjklmnpqrstvwxyz]{5,}"
        let clusterMatches = text.lowercased().matches(of: try! Regex(consonantClusterPattern))
        score -= clusterMatches.count * 10

        // Penalize very short results (probably failed OCR)
        if text.count < 20 {
            score -= 20
        }

        // Bonus for higher confidence
        score += Int(result.confidence * 20)

        // Bonus for reasonable number of lines (receipts have multiple lines)
        if result.lines.count >= 3 && result.lines.count <= 100 {
            score += 10
        }

        return max(0, score)
    }
}
