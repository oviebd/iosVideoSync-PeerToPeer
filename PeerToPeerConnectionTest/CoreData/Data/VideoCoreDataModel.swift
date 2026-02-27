//
//  VideoCoreDataModel.swift
//  PeerToPeerConnectionTest
//

import Foundation

class VideoCoreDataModel {
    let id: String
    let name: String
    let bookmarkData: Data

    init(id: String,
         name: String,
         bookmarkData: Data) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
    }
}

extension VideoCoreDataModel {
    func toVideoModelData() -> VideoModelData {
        return VideoModelData(id: id,
                              name: name,
                              bookmarkData: bookmarkData)
    }
}
