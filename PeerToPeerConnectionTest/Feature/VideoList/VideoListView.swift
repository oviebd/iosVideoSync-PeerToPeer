//
//  VideoListView.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 20/2/26.
//

internal import SwiftUI

struct VideoListView: View {
    @EnvironmentObject var videoStore: VideoStore
    @StateObject private var playlistVm = PlayListVm()
    
    @State private var showVideoPicker = false
    @State private var showDocumentPicker = false
    @State private var showPickerOptions = false
    @State private var showCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var videoToEdit: VideoItem?
    
    // Selection Mode States
    @State private var isSelectionMode = false
    @State private var selectedVideoIds: Set<String> = []
    @State private var showMoveToPlaylistOptions = false
    @State private var showDeleteConfirmation = false
    
    // Playlist Filtering
    @State private var selectedPlaylistId: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isSelectionMode {
                        selectionToolbar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        PlayListView(
                            playlists: playlistVm.playlists,
                            selectedPlaylistId: selectedPlaylistId,
                            onSelect: { playlist in
                                withAnimation {
                                    selectedPlaylistId = playlist?.id
                                }
                            },
                            onDelete: { playlist in
                                playlistVm.deletePlaylist(id: playlist.id)
                                if selectedPlaylistId == playlist.id {
                                    selectedPlaylistId = nil
                                }
                            },
                            onCreate: {
                                newPlaylistName = ""
                                showCreatePlaylistAlert = true
                            }
                        )
                    }
                    
                    let filteredVideos = getFilteredVideos()
                    
                    if filteredVideos.isEmpty && playlistVm.playlists.isEmpty && selectedPlaylistId == nil {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "film")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.textDim)
                            Text("No videos or playlists yet")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textDim)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                if !filteredVideos.isEmpty {
                                    HStack {
                                        Text(selectedPlaylistId == nil ? "All Videos" : (playlistVm.playlists.first(where: { $0.id == selectedPlaylistId })?.name ?? "Videos"))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppTheme.textDim)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, 8)
                                    
                                    ForEach(filteredVideos) { video in
                                        VideoListItemView(
                                            video: video,
                                            isSelectionMode: isSelectionMode,
                                            isSelected: selectedVideoIds.contains(video.id.uuidString),
                                            onEdit: {
                                                videoToEdit = video
                                            },
                                            onLongPress: {
                                                withAnimation {
                                                    isSelectionMode = true
                                                    selectedVideoIds.insert(video.id.uuidString)
                                                }
                                            },
                                            onToggleSelection: {
                                                toggleSelection(for: video.id.uuidString)
                                            }
                                        )
                                        .background(AppTheme.surface)
                                    }
                                } else {
                                    VStack(spacing: 16) {
                                        Spacer().frame(height: 100)
                                        Image(systemName: "video.slash")
                                            .font(.system(size: 40))
                                            .foregroundColor(AppTheme.textDim)
                                        Text("No videos in this playlist")
                                            .foregroundColor(AppTheme.textDim)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(isSelectionMode ? "\(selectedVideoIds.count) Selected" : "Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSelectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showPickerOptions = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
            .confirmationDialog("Select Option", isPresented: $showPickerOptions, titleVisibility: .visible) {
                Button("Photos Library") {
                    showVideoPicker = true
                }
                Button("Files") {
                    showDocumentPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Move to Playlist", isPresented: $showMoveToPlaylistOptions, titleVisibility: .visible) {
                ForEach(playlistVm.playlists) { playlist in
                    Button(playlist.name) {
                        playlistVm.addVideosToPlaylist(playlistId: playlist.id, videoIds: Array(selectedVideoIds))
                        exitSelectionMode()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Delete Videos", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedVideos()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete the selected videos?")
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(isPresented: $showVideoPicker) { name, bookmarkData in
                    videoStore.addVideo(name: name, bookmarkURL: bookmarkData)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(isPresented: $showDocumentPicker) { name, bookmarkData in
                    videoStore.addVideo(name: name, bookmarkURL: bookmarkData)
                }
            }
            .sheet(item: $videoToEdit) { video in
                EditVideoNameSheet(
                    initialName: video.name,
                    onSave: { newName in
                        videoStore.updateVideoName(id: video.id, newName: newName)
                        videoToEdit = nil
                    },
                    onCancel: {
                        videoToEdit = nil
                    }
                )
                .presentationDetents([.medium])
            }
            .alert("New Folder", isPresented: $showCreatePlaylistAlert) {
                TextField("Folder Name", text: $newPlaylistName)
                Button("Create") {
                    playlistVm.createPlaylist(name: newPlaylistName)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for this folder.")
            }
        }
    }
    
    // MARK: - Selection Toolbar
    
    private var selectionToolbar: some View {
        HStack {
            Button("Cancel") {
                exitSelectionMode()
            }
            .foregroundColor(AppTheme.accent)
            
            Spacer()
            
            HStack(spacing: 24) {
                Button(action: {
                    let currentVideos = getFilteredVideos()
                    if selectedVideoIds.count == currentVideos.count {
                        selectedVideoIds.removeAll()
                    } else {
                        selectedVideoIds = Set(currentVideos.map { $0.id.uuidString })
                    }
                }) {
                    Text(selectedVideoIds.count == getFilteredVideos().count ? "Deselect All" : "Select All")
                        .font(.system(size: 14))
                }
                
                Button(action: {
                    if !selectedVideoIds.isEmpty {
                        showMoveToPlaylistOptions = true
                    }
                }) {
                    Image(systemName: "folder.badge.plus")
                }
                .disabled(selectedVideoIds.isEmpty)
                
                Button(action: {
                    if !selectedVideoIds.isEmpty {
                        showDeleteConfirmation = true
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(selectedVideoIds.isEmpty ? AppTheme.textDim : AppTheme.danger)
                }
                .disabled(selectedVideoIds.isEmpty)
            }
            .foregroundColor(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    
    private func getFilteredVideos() -> [VideoItem] {
        if let playlistId = selectedPlaylistId,
           let playlist = playlistVm.playlists.first(where: { $0.id == playlistId }) {
            return videoStore.videos.filter { playlist.videoIds.contains($0.id.uuidString) }
        }
        return videoStore.videos
    }
    
    private func toggleSelection(for id: String) {
        if selectedVideoIds.contains(id) {
            selectedVideoIds.remove(id)
        } else {
            selectedVideoIds.insert(id)
        }
    }
    
    private func exitSelectionMode() {
        withAnimation {
            isSelectionMode = false
            selectedVideoIds.removeAll()
        }
    }
    
    private func deleteSelectedVideos() {
        let videoIdsToRemove = Array(selectedVideoIds)
        // Find offsets for videoStore.deleteVideo(at:)
        let offsets = IndexSet(
            videoStore.videos.enumerated()
                .filter { videoIdsToRemove.contains($0.element.id.uuidString) }
                .map { $0.offset }
        )
        videoStore.deleteVideo(at: offsets)
        exitSelectionMode()
    }
}

