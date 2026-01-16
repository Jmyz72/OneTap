//
//  TransactionTypeBadge.swift
//  OneTap
//
//  Reusable component for displaying transaction type badges
//  with consistent colors and styling
//

import SwiftUI

struct TransactionTypeBadge: View {
    let type: TransactionType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10, weight: .bold))
            Text(type.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(type.color)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        TransactionTypeBadge(type: .expense)
        TransactionTypeBadge(type: .income)
        TransactionTypeBadge(type: .transfer)
        TransactionTypeBadge(type: .adjustment)
    }
    .padding()
    .background(AppTheme.backgroundSolid)
}
