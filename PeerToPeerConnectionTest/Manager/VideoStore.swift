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
    @Published var videos: [VideoItem] = []
    
    private var dataManager: VideoLocalDataManager?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        do {
            dataManager = try VideoLocalDataManager()
            loadVideos()
        } catch {
            debugPrint("❌ Failed to initialize VideoLocalDataManager: \(error)")
        }
    }
    
    func addVideo(name: String, bookmarkURL: Data) {
        let newId = UUID().uuidString
        let coreDataModel = VideoCoreDataModel(id: newId, name: name, bookmarkData: bookmarkURL)
        
        dataManager?.insertVideos(videoDatas: [coreDataModel])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to insert video: \(error)")
                }
            }, receiveValue: { [weak self] success in
                if success {
                    self?.loadVideos()
                }
            })
            .store(in: &cancellables)
    }
    
    func deleteVideo(at offsets: IndexSet) {
        let videosToDelete = offsets.map { videos[$0] }
        
        for video in videosToDelete {
            dataManager?.deleteVideo(videoId: video.id.uuidString)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        debugPrint("❌ Failed to delete video: \(error)")
                    }
                }, receiveValue: { [weak self] success in
                    if success {
                        self?.loadVideos()
                    }
                })
                .store(in: &cancellables)
        }
    }
    
    func updateVideoName(id: UUID, newName: String) {
        guard let video = videos.first(where: { $0.id == id }) else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedModel = VideoCoreDataModel(id: id.uuidString, name: trimmedName, bookmarkData: video.bookmarkURL)
        
        dataManager?.updateVideo(updatedData: updatedModel)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to update video: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                self?.loadVideos()
            })
            .store(in: &cancellables)
    }
    
    private func loadVideos() {
        dataManager?.retrieveVideos()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to load videos: \(error)")
                }
            }, receiveValue: { [weak self] coreDataModels in
                self?.videos = coreDataModels.map { model in
                    VideoItem(
                        id: UUID(uuidString: model.id) ?? UUID(),
                        name: model.name,
                        bookmarkURL: model.bookmarkData
                    )
                }
            })
            .store(in: &cancellables)
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
