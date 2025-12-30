//
//  CurrencySelectionView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct CurrencySelectionView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(settings.availableCurrencies, id: \.self) { code in
                    CurrencyRow(
                        code: code,
                        isSelected: settings.currencyCode == code,
                        action: {
                            settings.currencyCode = code
                            dismiss()
                        }
                    )
                }
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }
}

struct CurrencyRow: View {
    let code: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(currencyName(for: code))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Text(code)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? AppTheme.accent.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? AppTheme.accent.opacity(0.3) : Color.white.opacity(0.05),
                        lineWidth: 1
                    )
            )
        }
    }
    
    private func currencyName(for code: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forCurrencyCode: code) ?? code
    }
}
