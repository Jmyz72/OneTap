//
//  SettingsViewModel.swift
//  OneTap
//
//  ViewModel for Settings/More tab logic
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject, ViewModelProtocol {
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func clearAllData() async {
        loadingState = .loading
        do {
            try await persistenceController.deleteAllData()
            loadingState = .loaded
        } catch {
            handleError(error)
        }
    }
}
