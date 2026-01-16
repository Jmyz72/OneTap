//
//  ImportTransactionIntent.swift
//  OneTap
//
//  App Intent for importing transactions from screenshots via Shortcuts
//

import AppIntents
import UIKit

enum ImportTransactionError: Error, LocalizedError {
    case invalidImage
    case failedToOpenApp

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Failed to load screenshot image"
        case .failedToOpenApp:
            return "Failed to open OneTap app"
        }
    }
}

@available(iOS 16.0, *)
struct ImportTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Transaction from Screenshot"
    static var description: IntentDescription = IntentDescription("Analyze a screenshot to extract and save transaction details")

    @Parameter(title: "Screenshot Image")
    var image: IntentFile

    func perform() async throws -> some IntentResult {
        // 1. Load image data
        let imageData = image.data

        // Verify image data is valid
        guard UIImage(data: imageData) != nil else {
            throw ImportTransactionError.invalidImage
        }

        // 2. Trigger deep link to app with image data
        // App will handle OCR and show confirmation screen
        let imageBase64 = imageData.base64EncodedString()
        let urlString = "onetap://import-transaction?image=\(imageBase64)"

        guard let url = URL(string: urlString),
              await UIApplication.shared.open(url) else {
            throw ImportTransactionError.failedToOpenApp
        }

        return .result()
    }
}
