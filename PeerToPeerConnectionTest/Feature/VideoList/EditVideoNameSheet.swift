//
//  EditVideoNameSheet.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 27/2/26.
//

import Foundation
internal import SwiftUI

struct EditVideoNameSheet: View {
    @State private var nameText: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    init(initialName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        _nameText = State(initialValue: initialName)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Video name", text: $nameText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Spacer()
            }
            .background(AppTheme.bg)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(AppTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(nameText)
                    }
                    .foregroundColor(AppTheme.accent)
                    .fontWeight(.semibold)
                    .disabled(nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
