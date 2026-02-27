//
//  PlaylistModelData.swift
//  PeerToPeerConnectionTest
//

import Foundation

class PlaylistModelData: Identifiable {
    let id: String
    var name: String
    var videoIds: [String]

    init(id: String = UUID().uuidString,
         name: String,
         videoIds: [String] = []) {
        self.id = id
        self.name = name
        self.videoIds = videoIds
    }
}

extension PlaylistModelData: Equatable, Hashable {
    static func == (lhs: PlaylistModelData, rhs: PlaylistModelData) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PlaylistModelData {
    func toCoreDataModel() -> PlaylistCoreDataModel {
        return PlaylistCoreDataModel(id: id,
                                     name: name,
                                     videoIds: videoIds)
    }
}
