//
//  EditVideoNameSheet.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
//

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
            VStack(spacing: AppSpacing.lg) {
                TextField(AppText.Alert.videoName, text: $nameText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle(AppText.Alert.editName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.General.cancel) { onCancel() }
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.General.save) {
                        onSave(nameText)
                    }
                    .foregroundColor(AppColors.accent)
                    .fontWeight(.semibold)
                    .disabled(nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
