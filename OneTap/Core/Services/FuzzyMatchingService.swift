//
//  FuzzyMatchingService.swift
//  OneTap
//
//  Fuzzy string matching for merchant names and items
//  Handles OCR errors, typos, and variations
//

import Foundation

@MainActor
class FuzzyMatchingService {

    // MARK: - Merchant Matching

    /// Finds the best match for a merchant name from a list of known merchants
    func findBestMerchantMatch(for ocrText: String, in knownMerchants: [String]) -> (match: String, confidence: Double)? {
        guard !knownMerchants.isEmpty else { return nil }

        var bestMatch: String? = nil
        var bestScore: Double = 0.0
        let threshold: Double = 0.6  // Minimum 60% similarity

        for merchant in knownMerchants {
            let score = calculateSimilarity(ocrText, merchant)

            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = merchant
            }
        }

        if let match = bestMatch {
            return (match: match, confidence: bestScore)
        }

        return nil
    }

    /// Checks if two merchant names are likely the same
    func areMerchantsEquivalent(_ name1: String, _ name2: String, threshold: Double = 0.75) -> Bool {
        let similarity = calculateSimilarity(name1, name2)
        return similarity >= threshold
    }

    // MARK: - Similarity Calculation

    /// Calculates similarity between two strings (0.0 to 1.0)
    /// Uses multiple algorithms for best results
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let s1 = string1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2 = string2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Quick checks
        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }

        // Combine multiple similarity metrics
        let levenshteinScore = 1.0 - (Double(levenshteinDistance(s1, s2)) / Double(max(s1.count, s2.count)))
        let jaroWinklerScore = jaroWinklerSimilarity(s1, s2)
        let nGramScore = nGramSimilarity(s1, s2, n: 2)  // Bigrams

        // Weighted average (JaroWinkler is best for names)
        let finalScore = (jaroWinklerScore * 0.5) + (levenshteinScore * 0.3) + (nGramScore * 0.2)

        return finalScore
    }

    // MARK: - Levenshtein Distance

    /// Calculates the Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Chars = Array(s1)
        let s2Chars = Array(s2)
        let s1Count = s1Chars.count
        let s2Count = s2Chars.count

        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)

        // Initialize first column and row
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        for j in 0...s2Count {
            matrix[0][j] = j
        }

        // Fill matrix
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Chars[i - 1] == s2Chars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // Deletion
                    matrix[i][j - 1] + 1,       // Insertion
                    matrix[i - 1][j - 1] + cost // Substitution
                )
            }
        }

        return matrix[s1Count][s2Count]
    }

    // MARK: - Jaro-Winkler Similarity

    /// Calculates Jaro-Winkler similarity (best for short strings like names)
    private func jaroWinklerSimilarity(_ s1: String, _ s2: String) -> Double {
        let jaroScore = jaroSimilarity(s1, s2)

        // Calculate common prefix length (up to 4 characters)
        let prefixLength = min(4, min(s1.count, s2.count))
        var commonPrefix = 0

        for i in 0..<prefixLength {
            let index1 = s1.index(s1.startIndex, offsetBy: i)
            let index2 = s2.index(s2.startIndex, offsetBy: i)

            if s1[index1] == s2[index2] {
                commonPrefix += 1
            } else {
                break
            }
        }

        // Jaro-Winkler adds bonus for common prefix
        let p = 0.1  // Scaling factor
        return jaroScore + (Double(commonPrefix) * p * (1.0 - jaroScore))
    }

    /// Calculates Jaro similarity
    private func jaroSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Chars = Array(s1)
        let s2Chars = Array(s2)
        let s1Count = s1Chars.count
        let s2Count = s2Chars.count

        if s1Count == 0 && s2Count == 0 { return 1.0 }
        if s1Count == 0 || s2Count == 0 { return 0.0 }

        let matchWindow = max(s1Count, s2Count) / 2 - 1

        var s1Matches = Array(repeating: false, count: s1Count)
        var s2Matches = Array(repeating: false, count: s2Count)

        var matches = 0
        var transpositions = 0

        // Find matches
        for i in 0..<s1Count {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, s2Count)

            for j in start..<end {
                if s2Matches[j] { continue }
                if s1Chars[i] != s2Chars[j] { continue }

                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0.0 }

        // Find transpositions
        var k = 0
        for i in 0..<s1Count {
            if !s1Matches[i] { continue }

            while !s2Matches[k] {
                k += 1
            }

            if s1Chars[i] != s2Chars[k] {
                transpositions += 1
            }

            k += 1
        }

        let jaroScore = (
            Double(matches) / Double(s1Count) +
            Double(matches) / Double(s2Count) +
            (Double(matches) - Double(transpositions) / 2.0) / Double(matches)
        ) / 3.0

        return jaroScore
    }

    // MARK: - N-Gram Similarity

    /// Calculates n-gram similarity (good for catching character swaps)
    private func nGramSimilarity(_ s1: String, _ s2: String, n: Int) -> Double {
        let ngrams1 = extractNGrams(from: s1, n: n)
        let ngrams2 = extractNGrams(from: s2, n: n)

        if ngrams1.isEmpty && ngrams2.isEmpty { return 1.0 }
        if ngrams1.isEmpty || ngrams2.isEmpty { return 0.0 }

        let intersection = Set(ngrams1).intersection(Set(ngrams2)).count
        let union = Set(ngrams1).union(Set(ngrams2)).count

        return Double(intersection) / Double(union)
    }

    /// Extracts n-grams from a string
    private func extractNGrams(from string: String, n: Int) -> [String] {
        let chars = Array(string)
        var ngrams: [String] = []

        guard chars.count >= n else { return [string] }

        for i in 0...(chars.count - n) {
            let ngram = String(chars[i..<(i + n)])
            ngrams.append(ngram)
        }

        return ngrams
    }

    // MARK: - Common Merchant Variations

    /// Normalizes merchant names by removing common variations
    func normalizeMerchantName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common suffixes
        let suffixes = ["sdn bhd", "sdn. bhd.", "sdn bhd.", "bhd", "pte ltd", "ltd", "inc", "corp", "co"]
        for suffix in suffixes {
            if normalized.hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Remove special characters (keep alphanumeric and spaces)
        normalized = normalized.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()

        // Collapse multiple spaces
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - OCR Error Patterns

    /// Common OCR character substitutions
    private let ocrErrorPatterns: [(wrong: String, correct: String)] = [
        // Number-letter confusion
        ("0", "O"), ("0", "o"),
        ("1", "I"), ("1", "l"),
        ("5", "S"),
        ("8", "B"),

        // Similar looking letters
        ("rn", "m"),
        ("vv", "w"),
        ("cl", "d"),

        // Malaysian specific
        ("IvI", "M"),  // "RM" often read as "RIvI"
    ]

    /// Applies common OCR error corrections
    func correctCommonOCRErrors(_ text: String) -> String {
        var corrected = text

        for (wrong, correct) in ocrErrorPatterns {
            corrected = corrected.replacingOccurrences(of: wrong, with: correct)
        }

        return corrected
    }
}
