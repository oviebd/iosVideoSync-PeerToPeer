//
//  VideoStore.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 20/2/26.
//

import Foundation
internal import SwiftUI
import Combine

class VideoStore: ObservableObject {
    @Published var videos: [VideoItem] = [] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "saved_videos"
    
    init() {
        loadFromUserDefaults()
    }
    
    func addVideo(name: String, bookmarkURL: Data) {
        let newVideo = VideoItem(name: name, bookmarkURL: bookmarkURL)
        videos.append(newVideo)
    }
    
    func deleteVideo(at offsets: IndexSet) {
        videos.remove(atOffsets: offsets)
    }
    
    func updateVideoName(id: UUID, newName: String) {
        guard let index = videos.firstIndex(where: { $0.id == id }) else { return }
        let updated = VideoItem(id: videos[index].id, name: newName.trimmingCharacters(in: .whitespacesAndNewlines), bookmarkURL: videos[index].bookmarkURL)
        videos[index] = updated
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([VideoItem].self, from: data) {
            videos = decoded
        }
    }
    
    func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData,
                                 options: .withoutUI,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            return nil
        }
        
        if isStale {
            return nil
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        
        return url
    }
}
