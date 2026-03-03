//
//  VideoListView.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
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

    @State private var isSelectionMode = false
    @State private var selectedVideoIds: Set<String> = []
    @State private var showMoveToPlaylistOptions = false
    @State private var showDeleteConfirmation = false

    @State private var selectedPlaylistId: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isSelectionMode {
                        selectionToolbar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        PlayListView(
                            playlists: playlistVm.playlists,
                            selectedPlaylistId: selectedPlaylistId,
                            onSelect: { playlist in
                                withAnimation { selectedPlaylistId = playlist?.id }
                            },
                            onDelete: { playlist in
                                playlistVm.deletePlaylist(id: playlist.id)
                                if selectedPlaylistId == playlist.id { selectedPlaylistId = nil }
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
                        EmptyStateView(
                            icon: "film",
                            message: AppText.VideoList.noVideosOrPlaylists,
                            iconFont: .system(size: 48)
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                if !filteredVideos.isEmpty {
                                    HStack {
                                        Text(selectedPlaylistId == nil
                                            ? AppText.VideoList.allVideos
                                            : (playlistVm.playlists.first(where: { $0.id == selectedPlaylistId })?.name ?? AppText.VideoList.videos))
                                            .font(.app.bodySemibold)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, AppSpacing.lg)
                                    .padding(.top, AppSpacing.md)
                                    .padding(.bottom, AppSpacing.sm)

                                    ForEach(filteredVideos) { video in
                                        VideoListItemView(
                                            video: video,
                                            isSelectionMode: isSelectionMode,
                                            isSelected: selectedVideoIds.contains(video.id.uuidString),
                                            onEdit: { videoToEdit = video },
                                            onLongPress: {
                                                withAnimation {
                                                    isSelectionMode = true
                                                    selectedVideoIds.insert(video.id.uuidString)
                                                }
                                            },
                                            onToggleSelection: { toggleSelection(for: video.id.uuidString) }
                                        )
                                        .background(AppColors.surface)
                                    }
                                } else {
                                    EmptyStateView(
                                        icon: "video.slash",
                                        message: AppText.VideoList.noVideosInPlaylist,
                                        iconFont: .system(size: 40)
                                    )
                                    .padding(.top, 100)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(isSelectionMode ? String(format: AppText.VideoList.selectedCount, selectedVideoIds.count) : AppText.VideoList.videos)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSelectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showPickerOptions = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .confirmationDialog(AppText.Alert.selectOption, isPresented: $showPickerOptions, titleVisibility: .visible) {
                Button(AppText.Alert.photosLibrary) { showVideoPicker = true }
                Button(AppText.Alert.files) { showDocumentPicker = true }
                Button(AppText.General.cancel, role: .cancel) { }
            }
            .confirmationDialog(AppText.Alert.moveToPlaylist, isPresented: $showMoveToPlaylistOptions, titleVisibility: .visible) {
                ForEach(playlistVm.playlists) { playlist in
                    Button(playlist.name) {
                        playlistVm.addVideosToPlaylist(playlistId: playlist.id, videoIds: Array(selectedVideoIds))
                        exitSelectionMode()
                    }
                }
                Button(AppText.General.cancel, role: .cancel) { }
            }
            .alert(AppText.Alert.deleteVideos, isPresented: $showDeleteConfirmation) {
                Button(AppText.General.delete, role: .destructive) { deleteSelectedVideos() }
                Button(AppText.General.cancel, role: .cancel) { }
            } message: {
                Text(AppText.Alert.deleteVideosMessage)
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
                    onCancel: { videoToEdit = nil }
                )
                .presentationDetents([.medium])
            }
            .alert(AppText.Alert.newFolder, isPresented: $showCreatePlaylistAlert) {
                TextField(AppText.Alert.folderName, text: $newPlaylistName)
                Button(AppText.General.create) { playlistVm.createPlaylist(name: newPlaylistName) }
                Button(AppText.General.cancel, role: .cancel) { }
            } message: {
                Text(AppText.Alert.newFolderMessage)
            }
        }
    }

    // MARK: Selection Toolbar

    private var selectionToolbar: some View {
        HStack {
            Button(AppText.General.cancel) { exitSelectionMode() }
                .foregroundColor(AppColors.accent)

            Spacer()

            HStack(spacing: AppSpacing.xxl) {
                Button {
                    let current = getFilteredVideos()
                    if selectedVideoIds.count == current.count {
                        selectedVideoIds.removeAll()
                    } else {
                        selectedVideoIds = Set(current.map { $0.id.uuidString })
                    }
                } label: {
                    Text(selectedVideoIds.count == getFilteredVideos().count ? AppText.VideoList.deselectAll : AppText.VideoList.selectAll)
                        .font(.app.body)
                }

                Button {
                    if !selectedVideoIds.isEmpty { showMoveToPlaylistOptions = true }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .disabled(selectedVideoIds.isEmpty)

                Button {
                    if !selectedVideoIds.isEmpty { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(selectedVideoIds.isEmpty ? AppColors.textSecondary : AppColors.danger)
                }
                .disabled(selectedVideoIds.isEmpty)
            }
            .foregroundColor(AppColors.accent)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: Helpers

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
        let ids = Array(selectedVideoIds)
        let offsets = IndexSet(
            videoStore.videos.enumerated()
                .filter { ids.contains($0.element.id.uuidString) }
                .map { $0.offset }
        )
        videoStore.deleteVideo(at: offsets)
        exitSelectionMode()
    }
}
