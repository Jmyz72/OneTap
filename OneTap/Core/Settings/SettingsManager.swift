//
//  SettingsManager.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("selectedCurrencyCode") var currencyCode: String = "MYR" {
        willSet {
            objectWillChange.send()
        }
    }
    
    // Common currencies list - MYR moved to front
    let availableCurrencies = [
        "MYR", "USD", "EUR", "GBP", "JPY", "CNY", 
        "CAD", "AUD", "CHF", "HKD", "SGD", 
        "INR", "KRW", "THB", "IDR"
    ]
    
    func getSymbol(for code: String) -> String {
        let locale = NSLocale(localeIdentifier: code)
        return locale.displayName(forKey: .currencySymbol, value: code) ?? code
    }
}