//
//  AddAccountView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

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
                            NavigationLink(destination: AccountFormView(rootIsPresented: $isPresented, template: template)) {
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
                    }
                }
                
                // Option to create a custom account manually
                Section {
                    NavigationLink(destination: AccountFormView(rootIsPresented: $isPresented, template: nil)) {
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
}