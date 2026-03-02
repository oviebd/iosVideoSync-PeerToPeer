//
//  FullScreenPlayerRepresentable.swift
//  PeerToPeerConnectionTest
//
//  SwiftUI wrapper for FullScreenPlayerVC, used with .fullScreenCover for programmatic fullscreen sync.
//

internal import AVFoundation
internal import SwiftUI
internal import UIKit

struct FullScreenPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> FullScreenPlayerVC {
        let vc = FullScreenPlayerVC(player: player, viewModel: viewModel, role: role)
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ uiViewController: FullScreenPlayerVC, context: Context) {
        uiViewController.onDismiss = onDismiss
    }
}
