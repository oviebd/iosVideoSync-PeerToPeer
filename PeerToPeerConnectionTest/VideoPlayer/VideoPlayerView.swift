//
//  VideoPlayerView.swift
//  PeerToPeerConnectionTest
//

import Combine
internal import SwiftUI
internal import UIKit

// MARK: - PlayerRole

enum PlayerRole {
    case master
    case slave
    case standalone
}

// MARK: - VideoPlayerView

struct VideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    var onSelectVideo: (() -> Void)? = nil

    @StateObject private var visibilityManager = ControlsVisibilityManager()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VideoSurfaceView(player: viewModel.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if visibilityManager.isVisible {
                PlayerControlsOverlay(
                    viewModel: viewModel,
                    role: role,
                    onSelectVideo: onSelectVideo,
                    onEnterFullScreen: enterFullScreen
                )
                .transition(.opacity)
                .contentShape(Rectangle())
                .onTapGesture {
                    visibilityManager.toggle()
                }
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        visibilityManager.toggle()
                    }
            }
        }
        .onAppear {
            visibilityManager.scheduleHide()
        }
        .onChange(of: viewModel.isSeeking) { _, isSeeking in
            if role == .master, isSeeking { visibilityManager.keepVisible() }
        }
        .onChange(of: viewModel.isRemoteSeeking) { _, isRemoteSeeking in
            if role == .slave, isRemoteSeeking { visibilityManager.keepVisible() }
        }
        .onDisappear {
            visibilityManager.cancel()
        }
    }

    private func enterFullScreen() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }

        AppDelegate.orientationLock = .landscape

        let fsVC = FullScreenPlayerVC(
            player: viewModel.player,
            viewModel: viewModel,
            role: role
        )
        fsVC.onDismiss = { fsVC.dismiss(animated: true) }

        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(fsVC, animated: true)
    }
}
