//
//  NativeVideoPlayer.swift
//  PeerToPeerConnectionTest
//

internal import AVFoundation
internal import SwiftUI
internal import UIKit

// MARK: - VideoSurfaceView

struct VideoSurfaceView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer?.player = player
    }
}

// MARK: - PlayerLayerView

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
}
