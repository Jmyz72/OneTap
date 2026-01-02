//
//  TransactionDetailsInput.swift
//  OneTap
//
//  Input fields for transaction title and merchant (with autocomplete)
//

import SwiftUI

struct TransactionDetailsInput: View {
    @Binding var title: String
    @Binding var merchant: String
    @Binding var transactionDate: Date
    let merchantSuggestions: [String]
    let onMerchantChanged: () -> Void
    let onDateTap: () -> Void
    
    var focusedField: FocusState<Field?>.Binding

    public enum Field {
        case title, merchant
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
                    .submitLabel(.next)
            }

            // Merchant Field
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(width: 20)

                    TextField("Where? (optional)", text: $merchant)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.textPrimary)
                        .focused(focusedField, equals: .merchant)
                        .onChange(of: merchant) { _, _ in
                            onMerchantChanged()
                        }
                        .submitLabel(.done)

                    if !merchant.isEmpty {
                        Button(action: { merchant = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.secondaryBackground)
                .cornerRadius(10)

                // Merchant Suggestions
                if focusedField.wrappedValue == .merchant && !merchantSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(merchantSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                merchant = suggestion
                                focusedField.wrappedValue = nil
                            }) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textTertiary)

                                    Text(suggestion)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.background)
                            }

                            if suggestion != merchantSuggestions.last {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .background(AppTheme.background)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var title = ""
        @State private var merchant = ""
        @State private var date = Date()
        @FocusState private var focusedField: TransactionDetailsInput.Field?
        
        var body: some View {
            TransactionDetailsInput(
                title: $title,
                merchant: $merchant,
                transactionDate: $date,
                merchantSuggestions: ["Starbucks", "McDonald's", "7-Eleven"],
                onMerchantChanged: {},
                onDateTap: {},
                focusedField: $focusedField
            )
            .background(AppTheme.background)
        }
    }
    
    return PreviewWrapper()
}
