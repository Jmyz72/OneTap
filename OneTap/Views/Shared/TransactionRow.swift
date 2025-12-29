//
//  TransactionRow.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            if let categoryEnum = transaction.categoryEnum {
                Image(systemName: categoryEnum.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(categoryColor)
                    .clipShape(Circle())
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? "Unknown")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(transaction.category ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let merchant = transaction.merchant, !merchant.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(merchant)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.body)
                .fontWeight(.bold)
                .foregroundStyle(transaction.amount >= 0 ? .red : .green)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        guard let categoryEnum = transaction.categoryEnum else {
            return .gray
        }
        
        switch categoryEnum {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .pink
        case .bills: return .red
        case .health: return .green
        case .salary: return .mint
        case .investment: return .indigo
        case .other: return .gray
        }
    }
}
