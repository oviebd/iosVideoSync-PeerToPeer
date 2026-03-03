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
    
    func addVideo(name: String, bookmarkURL: Data, onAdded: ((String) -> Void)? = nil) {
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
                    onAdded?(newId)
                }
            })
            .store(in: &cancellables)
    }
    
    func deleteVideo(at offsets: IndexSet) {
        let videosToDelete = offsets.map { videos[$0] }
        deleteVideos(videosToDelete, removeFromAppDocuments: true)
    }

    /// Deletes videos from DB and optionally removes files from app Documents (for Photos-imported videos).
    func deleteVideos(_ videosToDelete: [VideoItem], removeFromAppDocuments: Bool) {
        for video in videosToDelete {
            if removeFromAppDocuments {
                deleteFileFromAppDocumentsIfNeeded(bookmarkData: video.bookmarkURL)
            }
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

    /// Deletes the file from app Documents if the bookmark points to a file inside app Documents (Photos-imported videos).
    private func deleteFileFromAppDocumentsIfNeeded(bookmarkData: Data) {
        guard let url = resolveBookmark(bookmarkData) else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docPath = documentsURL.resolvingSymlinksInPath().path
        let filePath = url.resolvingSymlinksInPath().path

        guard filePath.hasPrefix(docPath) else { return }

        try? FileManager.default.removeItem(at: url)
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
