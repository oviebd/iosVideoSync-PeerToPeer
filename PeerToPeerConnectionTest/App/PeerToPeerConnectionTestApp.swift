//
//  PeerToPeerConnectionTestApp.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 18/2/26.
//

internal import SwiftUI

@main
struct PeerToPeerConnectionTestApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.service)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.service.resumeAdvertisingIfNeeded()
            }
        }
    }
}
