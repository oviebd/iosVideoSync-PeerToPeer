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
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !playlistVm.playlists.isEmpty {
                        PlayListView(playlists: playlistVm.playlists, onSelect: { playlist in
                            // Handle playlist selection if needed
                            debugPrint("Selected playlist: \(playlist.name)")
                        }, onDelete: { playlist in
                            playlistVm.deletePlaylist(id: playlist.id)
                        })
                    }
                    
                    if videoStore.videos.isEmpty && playlistVm.playlists.isEmpty {
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
                        List {
                            if !videoStore.videos.isEmpty {
                                Section(header: Text("Videos").foregroundColor(AppTheme.textDim)) {
                                    ForEach(videoStore.videos) { video in
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(AppTheme.accent)
                                                .font(.system(size: 20))
                                            Text(video.name)
                                                .foregroundColor(AppTheme.text)
                                                .font(.system(size: 15))
                                        }
                                        .listRowBackground(AppTheme.surface)
                                        .contextMenu {
                                            Button {
                                                videoToEdit = video
                                            } label: {
                                                Label("Edit Name", systemImage: "pencil")
                                            }
                                        }
                                    }
                                    .onDelete(perform: deleteVideos)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPickerOptions = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accent)
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
                Button("Create Folder") {
                    newPlaylistName = ""
                    showCreatePlaylistAlert = true
                }
                Button("Cancel", role: .cancel) { }
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
    
    private func deleteVideos(at offsets: IndexSet) {
        videoStore.deleteVideo(at: offsets)
    }
}

// MARK: - Edit Video Name Sheet

