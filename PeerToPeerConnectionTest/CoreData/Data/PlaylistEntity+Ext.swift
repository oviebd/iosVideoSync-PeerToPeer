//
//  PlaylistEntity+Ext.swift
//  PeerToPeerConnectionTest
//

import Foundation
import CoreData

extension PlaylistEntity {
    func convertFromCoreDataModel(coreData: PlaylistCoreDataModel) {
        self.id = coreData.id
        self.name = coreData.name
        self.videoIds = coreData.videoIdsString
    }
}
