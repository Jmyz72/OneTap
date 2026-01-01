//
//  RepositoryError.swift
//  OneTap
//
//  Repository layer error definitions
//

import Foundation

enum RepositoryError: LocalizedError {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case entityNotFound
    case invalidData(String)
    case contextUnavailable

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch data: \(message)"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .entityNotFound:
            return "Entity not found"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .contextUnavailable:
            return "Core Data context unavailable"
        }
    }
}
