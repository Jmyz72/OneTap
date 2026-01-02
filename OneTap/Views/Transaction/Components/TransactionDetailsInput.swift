//
//  TransactionDetailsInput.swift
//  OneTap
//
//  Input fields for transaction title and merchant (with autocomplete)
//

import SwiftUI

struct TransactionDetailsInput: View {
    @Binding var title: String
    @Binding var transactionDate: Date
    let onDateTap: () -> Void
    
    var focusedField: FocusState<Field?>.Binding

    public enum Field {
        case title
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title & Time Row
            HStack(spacing: 8) {
                // Time Picker Button
                Button(action: onDateTap) {
                    Text(Formatters.time.string(from: transactionDate))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(8)
                }
                
                // Title Field
                TextField("Title", text: $title)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(8)
                    .focused(focusedField, equals: .title)
                    .submitLabel(.done)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var title = ""
        @State private var date = Date()
        @FocusState private var focusedField: TransactionDetailsInput.Field?
        
        var body: some View {
            TransactionDetailsInput(
                title: $title,
                transactionDate: $date,
                onDateTap: {},
                focusedField: $focusedField
            )
            .background(AppTheme.background)
        }
    }
    
    return PreviewWrapper()
}
