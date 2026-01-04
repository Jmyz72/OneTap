//
//  AccountEmptyState.swift
//  OneTap
//
//  Created by Jimmy Hew on 04/01/2026.
//

import SwiftUI

struct AccountEmptyState: View {
    @Binding var showingAddAccount: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "building.columns")
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.textTertiary)
            }
            
            VStack(spacing: 12) {
                Text("No Accounts Yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("Add your first account to start tracking your finances")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingAddAccount = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Account")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .cornerRadius(14)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
