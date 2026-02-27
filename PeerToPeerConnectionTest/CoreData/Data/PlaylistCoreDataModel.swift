//
//  PlaylistCoreDataModel.swift
//  PeerToPeerConnectionTest
//

import Foundation

class PlaylistCoreDataModel {
    let id: String
    let name: String
    let videoIds: [String]

    init(id: String,
         name: String,
         videoIds: [String]) {
        self.id = id
        self.name = name
        self.videoIds = videoIds
    }
}

extension PlaylistCoreDataModel {
    func toPlaylistModelData() -> PlaylistModelData {
        return PlaylistModelData(id: id,
                                 name: name,
                                 videoIds: videoIds)
    }

    // Helper to convert videoIds array to comma-separated string for Core Data
    var videoIdsString: String {
        return videoIds.joined(separator: ",")
    }

    // Helper to initialize from comma-separated string
    static func parseVideoIds(_ string: String?) -> [String] {
        guard let string = string, !string.isEmpty else { return [] }
        return string.components(separatedBy: ",")
    }
}
