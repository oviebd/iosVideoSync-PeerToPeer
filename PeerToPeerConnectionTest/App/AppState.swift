//
//  AppState.swift
//  PeerToPeerConnectionTest
//
//  Holds MultipeerService and BackgroundKeepAliveService. The keep-alive service
//  must be created with the same MultipeerService instance so it can observe
//  room state and lifecycle.
//

import Combine
import Foundation

final class AppState: ObservableObject {
    let service = MultipeerService()
    let backgroundKeepAlive: BackgroundKeepAliveService

    init() {
        self.backgroundKeepAlive = BackgroundKeepAliveService(multipeerService: service)
    }
}
