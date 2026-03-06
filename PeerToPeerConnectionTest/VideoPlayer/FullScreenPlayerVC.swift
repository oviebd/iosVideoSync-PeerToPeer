//
//  FullScreenPlayerVC.swift
//  PeerToPeerConnectionTest
//

internal import AVFoundation
internal import SwiftUI
internal import UIKit

// MARK: - FullScreenPlayerVC

final class FullScreenPlayerVC: UIViewController {
    private let player: AVPlayer
    private let viewModel: VideoPlayerVM
    private let role: PlayerRole
    private var playerLayer: AVPlayerLayer?
    private var hostingVC: UIHostingController<FullScreenControlsView>?
    var onDismiss: (() -> Void)?

    init(player: AVPlayer, viewModel: VideoPlayerVM, role: PlayerRole) {
        self.player = player
        self.viewModel = viewModel
        self.role = role
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.overrideUserInterfaceStyle = .dark

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.layer.insertSublayer(layer, at: 0)
        playerLayer = layer

        let visibilityManager = ControlsVisibilityManager()
        let controlsView = FullScreenControlsView(
            viewModel: viewModel,
            role: role,
            visibilityManager: visibilityManager,
            onDismiss: { [weak self] in self?.onDismiss?() }
        )
        let hosting = UIHostingController(rootView: controlsView)
        hosting.view.backgroundColor = .clear
        hostingVC = hosting
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Force layout update after rotation completes for consistent full-screen display on all devices
        view.setNeedsLayout()
        view.layoutIfNeeded()
        playerLayer?.frame = view.bounds
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let updateLayout = { [weak self] in
            guard let self else { return }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.playerLayer?.frame = self.view.bounds
            self.hostingVC?.view.setNeedsLayout()
            self.hostingVC?.view.layoutIfNeeded()
        }
        coordinator.animate(alongsideTransition: { _ in updateLayout() }) { _ in
            updateLayout()
            // Extra layout pass for iPad to ensure full-screen fill after rotation completes
            if UIDevice.current.userInterfaceIdiom == .pad {
                DispatchQueue.main.async { updateLayout() }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Preserve playing state when entering full screen - don't change it
        if viewModel.isPlaying {
            player.play()
        } else {
            player.pause()
        }
        // Only lock orientation to landscape on iPhone; iPad keeps current rotation
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        AppDelegate.orientationLock = .landscape
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            view.window?.windowScene?.requestGeometryUpdate(
                .iOS(interfaceOrientations: .landscape)
            )
        } else {
            UIDevice.current.setValue(
                UIInterfaceOrientation.landscapeLeft.rawValue,
                forKey: "orientation"
            )
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Only restore portrait lock on iPhone; iPad keeps current rotation
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        AppDelegate.orientationLock = .portrait
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            view.window?.windowScene?.requestGeometryUpdate(
                .iOS(interfaceOrientations: .portrait)
            )
        } else {
            UIDevice.current.setValue(
                UIInterfaceOrientation.portrait.rawValue,
                forKey: "orientation"
            )
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .landscape
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }
    override var shouldAutorotate: Bool { true }
}
