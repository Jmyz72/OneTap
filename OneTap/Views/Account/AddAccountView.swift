//
//  AddAccountView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
internal import CoreData

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    // Default init for preview or when binding not strictly needed (though we enforce it now)
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AccountTemplate.allGroups) { group in
                    Section(header: Text(group.group.rawValue)) {
                        ForEach(group.templates) { template in
                            accountTemplateRow(for: template)
                        }
                    }
                }
                
                customAccountSection
            }
            .navigationTitle("Select Account Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func accountTemplateRow(for template: AccountTemplate) -> some View {
        NavigationLink(destination: AccountFormView(template: template, rootIsPresented: $isPresented)) {
            HStack(spacing: 12) {
                AccountIconView(
                    iconName: template.displayIcon,
                    color: template.type.color,
                    size: 20 // Adjusted for list view
                )
                
                VStack(alignment: .leading) {
                    Text(template.name)
                        .font(.body)
                    if !template.institution.isEmpty {
                        Text(template.institution)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var customAccountSection: some View {
        Section {
            NavigationLink(destination: AccountFormView(template: nil, rootIsPresented: $isPresented)) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray)
                        .clipShape(Circle())
                    
                    Text("Other / Custom Account")
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
        }
    }
}