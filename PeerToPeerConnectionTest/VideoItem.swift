//
//  VideoItem.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 20/2/26.
//

import Foundation

struct VideoItem: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let bookmarkURL: Data
    
    init(id: UUID = UUID(), name: String, bookmarkURL: Data) {
        self.id = id
        self.name = name
        self.bookmarkURL = bookmarkURL
    }
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}
