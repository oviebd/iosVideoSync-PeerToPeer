//
//  VideoEntity+Ext.swift
//  PeerToPeerConnectionTest
//

import Foundation
import CoreData

extension VideoEntity {
    func convertFromCoreDataModel(coreData: VideoCoreDataModel) {
        self.id = coreData.id
        self.name = coreData.name
        self.bookmarkData = coreData.bookmarkData
    }
}
