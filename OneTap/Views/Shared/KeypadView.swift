//
//  KeypadView.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import SwiftUI

struct CustomKeypad: View {
    @Binding var value: String
    var onDone: () -> Void
    var onAddItem: (() -> Void)? = nil // Optional Add Item Action
    
    var body: some View {
        HStack(spacing: 12) {
            // Numbers (3x4)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    numberKey("1")
                    numberKey("2")
                    numberKey("3")
                }
                HStack(spacing: 12) {
                    numberKey("4")
                    numberKey("5")
                    numberKey("6")
                }
                HStack(spacing: 12) {
                    numberKey("7")
                    numberKey("8")
                    numberKey("9")
                }
                HStack(spacing: 12) {
                    numberKey(".")
                    numberKey("0")
                    deleteKey()
                }
            }
            
            // Actions Column
            VStack(spacing: 12) {
                if let onAdd = onAddItem {
                    // Split mode: Add Item + Done
                    Button(action: onAdd) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                            Text("Add")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(16)
                    }
                    
                    Button(action: onDone) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                    }
                } else {
                    // Standard mode: Tall Done
                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                    }
                }
            }
            .frame(width: 80)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(24)
    }
    
    private func numberKey(_ num: String) -> some View {
        Button {
            if num == "." && value.contains(".") { return }
            if value == "0" && num != "." { value = num }
            else { value.append(num) }
        } label: {
            Text(num)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.secondaryBackground)
                .cornerRadius(12)
        }
        .frame(height: 60)
    }
    
    private func deleteKey() -> some View {
        Button {
            if !value.isEmpty { value.removeLast() }
            if value.isEmpty { value = "0" }
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.secondaryBackground)
                .cornerRadius(12)
        }
        .frame(height: 60)
    }
}
