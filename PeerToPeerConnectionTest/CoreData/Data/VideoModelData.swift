//
//  VideoModelData.swift
//  PeerToPeerConnectionTest
//

import Foundation

class VideoModelData: Identifiable {
    let id: String
    var name: String
    let bookmarkData: Data

    init(id: String = UUID().uuidString,
         name: String,
         bookmarkData: Data) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
    }
}

extension VideoModelData: Equatable, Hashable {
    static func == (lhs: VideoModelData, rhs: VideoModelData) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension VideoModelData {
    func toCoreDataModel() -> VideoCoreDataModel {
        return VideoCoreDataModel(id: id,
                                  name: name,
                                  bookmarkData: bookmarkData)
    }
}
