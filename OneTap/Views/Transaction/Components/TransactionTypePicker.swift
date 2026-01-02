//
//  TransactionTypePicker.swift
//  OneTap
//

import SwiftUI

struct TransactionTypePicker: View {
    @Binding var selectedType: TransactionType
    
    var body: some View {
        Picker("Type", selection: $selectedType) {
            ForEach(TransactionType.allCases.filter { $0 != .adjustment }) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
