//
//  SubCategoryFormView.swift
//  OneTap
//
//  Created by Jimmy Hew on 31/12/2025.
//

import SwiftUI
internal import CoreData

struct SubCategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding to the data we are editing
    @Binding var name: String
    @Binding var icon: String
    
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    
    // State for local editing if needed, but binding is simpler for passing back to parent form
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Subcategory Name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(IconLibrary.icons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .foregroundColor(icon == iconName ? AppTheme.accent : .gray)
                                .background(icon == iconName ? AppTheme.accent.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = iconName
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if let deleteAction = onDelete {
                    Section {
                        Button(role: .destructive, action: deleteAction) {
                            Text("Delete Subcategory")
                        }
                    }
                }
            }
            .navigationTitle(name.isEmpty ? "New Subcategory" : "Edit Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
