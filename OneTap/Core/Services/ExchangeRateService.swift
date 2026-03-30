//
//  ExchangeRateService.swift
//  OneTap
//
//  Service for fetching and caching currency exchange rates
//  Uses fawazahmed0/exchange-api (free, no API key required)
//

import Foundation
import Combine

// MARK: - Models

struct ExchangeRateResponse: Codable {
    let date: String
    let rates: [String: Double]

    enum CodingKeys: String, CodingKey {
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)

        // The API returns currency codes as dynamic keys
        let singleContainer = try decoder.singleValueContainer()
        let fullResponse = try singleContainer.decode([String: AnyCodable].self)

        var extractedRates: [String: Double] = [:]
        for (key, value) in fullResponse {
            if key != "date", let rateDict = value.value as? [String: Any] {
                for (currencyCode, rate) in rateDict {
                    if let rateDouble = rate as? Double {
                        extractedRates[currencyCode.uppercased()] = rateDouble
                    }
                }
            }
        }
        rates = extractedRates
    }
}

// Helper for decoding dynamic JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dict = try? container.decode([String: AnyCodable].self) {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = val.value
            }
            value = result
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// Cached exchange rates
struct CachedExchangeRates: Codable {
    let baseCurrency: String
    let rates: [String: Double]
    let fetchedAt: Date
    let rateDate: String

    var isStale: Bool {
        // Consider rates stale after 24 hours
        let staleThreshold: TimeInterval = 24 * 60 * 60
        return Date().timeIntervalSince(fetchedAt) > staleThreshold
    }
}

// MARK: - Service Protocol

@MainActor
protocol ExchangeRateServiceProtocol {
    func fetchRates(baseCurrency: String) async throws -> [String: Double]
    func convert(amount: Double, from: String, to: String) async throws -> Double
    func getRate(from: String, to: String) async throws -> Double
    var lastUpdated: Date? { get }
    var cachedRates: [String: Double]? { get }
}

// MARK: - Service Implementation

@MainActor
class ExchangeRateService: ObservableObject, ExchangeRateServiceProtocol {

    // MARK: - Published Properties

    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var cachedRates: [String: Double]?

    // MARK: - Private Properties

    private let cacheKey = "cachedExchangeRates"
    private let baseURL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies"
    private let fallbackURL = "https://latest.currency-api.pages.dev/v1/currencies"

    private var currentBaseCurrency: String = "USD"

    // MARK: - Initialization

    init() {
        loadCachedRates()
    }

    // MARK: - Public API

    /// Fetch exchange rates for a base currency
    /// - Parameter baseCurrency: The base currency code (e.g., "USD", "MYR")
    /// - Returns: Dictionary of currency codes to exchange rates
    func fetchRates(baseCurrency: String) async throws -> [String: Double] {
        isLoading = true
        defer { isLoading = false }

        let normalizedBase = baseCurrency.lowercased()

        // Try primary URL first, then fallback
        let urls = [
            "\(baseURL)/\(normalizedBase).json",
            "\(fallbackURL)/\(normalizedBase).json"
        ]

        var lastError: Error?

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }

                // Parse the response
                let rates = try parseRatesResponse(data: data, baseCurrency: normalizedBase)

                // Cache the rates
                let cached = CachedExchangeRates(
                    baseCurrency: baseCurrency.uppercased(),
                    rates: rates,
                    fetchedAt: Date(),
                    rateDate: ISO8601DateFormatter().string(from: Date())
                )
                saveCachedRates(cached)

                currentBaseCurrency = baseCurrency.uppercased()
                cachedRates = rates
                lastUpdated = Date()
                self.lastError = nil

                return rates

            } catch {
                lastError = error
                continue
            }
        }

        self.lastError = lastError
        throw lastError ?? ServiceError.networkError("Failed to fetch exchange rates")
    }

    /// Convert an amount from one currency to another
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - from: Source currency code
    ///   - to: Target currency code
    /// - Returns: The converted amount
    func convert(amount: Double, from: String, to: String) async throws -> Double {
        let rate = try await getRate(from: from, to: to)
        return amount * rate
    }

    /// Get the exchange rate between two currencies
    /// - Parameters:
    ///   - from: Source currency code
    ///   - to: Target currency code
    /// - Returns: The exchange rate
    func getRate(from: String, to: String) async throws -> Double {
        let fromUpper = from.uppercased()
        let toUpper = to.uppercased()

        // Same currency = 1.0
        if fromUpper == toUpper {
            return 1.0
        }

        // Check if we have cached rates and they're not stale
        if let cached = loadCachedRatesFromStorage(),
           !cached.isStale,
           cached.baseCurrency == fromUpper,
           let rate = cached.rates[toUpper] {
            return rate
        }

        // Fetch fresh rates
        let rates = try await fetchRates(baseCurrency: fromUpper)

        guard let rate = rates[toUpper] else {
            throw ServiceError.operationFailed("Exchange rate not available for \(fromUpper) to \(toUpper)")
        }

        return rate
    }

    /// Convert amount to base currency (for net worth calculation)
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - fromCurrency: Source currency code
    ///   - baseCurrency: Target base currency code
    /// - Returns: The converted amount, or original amount if conversion fails
    func convertToBase(amount: Double, fromCurrency: String, baseCurrency: String) async -> Double {
        // Same currency, no conversion needed
        if fromCurrency.uppercased() == baseCurrency.uppercased() {
            return amount
        }

        do {
            return try await convert(amount: amount, from: fromCurrency, to: baseCurrency)
        } catch {
            // If conversion fails, return original amount
            // This is a fallback to prevent blocking the UI
            print("Currency conversion failed: \(error.localizedDescription)")
            return amount
        }
    }

    // MARK: - Private Helpers

    private func parseRatesResponse(data: Data, baseCurrency: String) throws -> [String: Double] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.operationFailed("Invalid JSON response")
        }

        // The API returns: { "date": "2024-01-01", "usd": { "myr": 4.47, "eur": 0.92, ... } }
        guard let ratesDict = json[baseCurrency] as? [String: Any] else {
            throw ServiceError.operationFailed("No rates found for \(baseCurrency)")
        }

        var rates: [String: Double] = [:]
        for (key, value) in ratesDict {
            if let rate = value as? Double {
                rates[key.uppercased()] = rate
            } else if let rate = value as? Int {
                rates[key.uppercased()] = Double(rate)
            }
        }

        // Add self-rate
        rates[baseCurrency.uppercased()] = 1.0

        return rates
    }

    private func loadCachedRates() {
        if let cached = loadCachedRatesFromStorage() {
            cachedRates = cached.rates
            lastUpdated = cached.fetchedAt
            currentBaseCurrency = cached.baseCurrency
        }
    }

    private func loadCachedRatesFromStorage() -> CachedExchangeRates? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedExchangeRates.self, from: data)
    }

    private func saveCachedRates(_ cached: CachedExchangeRates) {
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
