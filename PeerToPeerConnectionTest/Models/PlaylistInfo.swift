//
//  PlaylistInfo.swift
//  PeerToPeerConnectionTest
//
//  Cross-device playlist representation for slave display.
//  Intentionally flat: names only, no IDs or bookmark data.
//

import Foundation

struct PlaylistInfo: Codable, Equatable {
    let playlistName: String
    let videoNames: [String]  // ordered, matches playback order
}
