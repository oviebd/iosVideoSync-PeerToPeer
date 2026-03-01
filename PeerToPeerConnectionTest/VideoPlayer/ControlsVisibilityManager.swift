//
//  ControlsVisibilityManager.swift
//  PeerToPeerConnectionTest
//

import Combine
internal import SwiftUI

// MARK: - ControlsVisibilityManager

final class ControlsVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = true
    private var workItem: DispatchWorkItem?

    func toggle() {
        isVisible.toggle()
        if isVisible { scheduleHide() }
        else { workItem?.cancel() }
    }

    func scheduleHide(after delay: Double = 3.0) {
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.isVisible = false
                }
            }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func keepVisible() {
        workItem?.cancel()
        isVisible = true
    }

    func cancel() {
        workItem?.cancel()
    }
}
