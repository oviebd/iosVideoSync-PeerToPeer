//
//  PlayListVm.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
//

import Foundation
import Combine
internal import SwiftUI

class PlayListVm: ObservableObject {
    @Published var playlists: [PlaylistModelData] = []
    
    private var dataManager: VideoLocalDataManager?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        do {
            dataManager = try VideoLocalDataManager()
            fetchPlaylists()
        } catch {
            debugPrint("❌ Failed to initialize VideoLocalDataManager in PlayListVm: \(error)")
        }
    }
    
    func fetchPlaylists() {
        dataManager?.retrievePlaylists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to fetch playlists: \(error)")
                }
            }, receiveValue: { [weak self] coreDataModels in
                self?.playlists = coreDataModels.map { $0.toPlaylistModelData() }
            })
            .store(in: &cancellables)
    }
    
    func createPlaylist(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newPlaylist = PlaylistModelData(name: trimmedName)
        let coreDataModel = newPlaylist.toCoreDataModel()
        
        dataManager?.insertPlaylists(playlists: [coreDataModel])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to create playlist: \(error)")
                }
            }, receiveValue: { [weak self] success in
                if success {
                    self?.fetchPlaylists()
                }
            })
            .store(in: &cancellables)
    }
    
    func deletePlaylist(id: String) {
        dataManager?.deletePlaylist(playlistId: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to delete playlist: \(error)")
                }
            }, receiveValue: { [weak self] success in
                if success {
                    self?.fetchPlaylists()
                }
            })
            .store(in: &cancellables)
    }

    func deleteVideoFromPlaylist(playlistId: String, videoId: String) {
        guard let playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        
        var updatedVideoIds = playlist.videoIds
        updatedVideoIds.removeAll { $0 == videoId }
        
        let updatedPlaylist = PlaylistModelData(id: playlist.id, name: playlist.name, videoIds: updatedVideoIds)
        let coreDataModel = updatedPlaylist.toCoreDataModel()
        
        dataManager?.updatePlaylist(updatedData: coreDataModel)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    debugPrint("❌ Failed to update playlist: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                self?.fetchPlaylists()
            })
            .store(in: &cancellables)
    }
}
