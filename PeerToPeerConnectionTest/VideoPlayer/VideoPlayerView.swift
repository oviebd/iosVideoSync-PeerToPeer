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
        .fullScreenCover(isPresented: fullScreenBinding) {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                FullScreenPlayerRepresentable(
                    player: viewModel.player,
                    viewModel: viewModel,
                    role: role,
                    onDismiss: { fullScreenDismiss() }
                )
                .ignoresSafeArea()
            }
            .presentationBackground(Color.black)
        }
    }

    private var fullScreenBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isFullScreen },
            set: { newValue in
                viewModel.isFullScreen = newValue
                if !newValue, role == .master {
                    viewModel.service?.sendSetFullScreenCommand(isFullScreen: false)
                }
            }
        )
    }

    private func enterFullScreen() {
        viewModel.isFullScreen = true
        if role == .master {
            viewModel.service?.sendSetFullScreenCommand(isFullScreen: true)
        }
    }

    private func fullScreenDismiss() {
        viewModel.isFullScreen = false
        if role == .master {
            viewModel.service?.sendSetFullScreenCommand(isFullScreen: false)
        }
    }
}
